import 'dart:async';
import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

// サーバーAPIのURL
const String API_URL = 'https://example.com/api/receive_data.php';

// フォアグラウンドサービス用のタスクハンドラ
class StorageMonitorTaskHandler extends TaskHandler {
  SendPort? _sendPort;
  Timer? _timer;
  final int _intervalMinutes = 15; // デフォルト間隔: 15分

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    _sendPort = sendPort;

    // 定期的な監視を開始
    _timer = Timer.periodic(
      Duration(minutes: _intervalMinutes),
      (_) => _checkAndSendStorageInfo(),
    );

    // 開始時に一度実行
    await _checkAndSendStorageInfo();
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    // 定期的にこのメソッドが呼び出される
    await _checkAndSendStorageInfo();
  }
  
  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    // クリーンアップ
    _timer?.cancel();
  }

  // 通知ボタンのアクション処理 (onButtonPressed メソッドが親クラスにない場合は削除)
  void onButtonPressed(String id) {
    // 通知ボタンのアクション処理
    if (id == 'refreshButton') {
      _checkAndSendStorageInfo();
    }
  }

  // 通知がタップされたときの処理 (onNotificationPressed メソッドが親クラスにない場合は削除)
  void onNotificationPressed() {
    // 通知がタップされたときの処理
    FlutterForegroundTask.launchApp();
  }
  
  // アプリからのデータ受信処理 (onData メソッドが親クラスにない場合は削除)
  Future<void> onData(dynamic data) async {
    // アプリからのデータ受信処理
    if (data is Map && data.containsKey('action')) {
      final action = data['action'];
      
      if (action == 'refresh') {
        // 手動更新リクエストを受け取った場合、即座にチェックを実行
        await _checkAndSendStorageInfo();
      }
    }
  }

  // 空き容量の取得
  Future<int> _getFreeSpace() async {
    try {
      // 外部ストレージディレクトリの取得を試みる
      Directory? directory;
      
      try {
        directory = await getExternalStorageDirectory();
      } catch (e) {
        print('外部ストレージアクセスエラー: $e');
      }
      
      // 外部ストレージが取得できない場合はアプリケーションディレクトリを使用
      directory ??= await getApplicationDocumentsDirectory();

      // ファイルシステムの統計情報を取得
      final statFs = directory.statSync();
      
      // 利用可能なサイズを返す
      return statFs.size;
    } catch (e) {
      print('ストレージ情報の取得に失敗: $e');
      
      // エラー時はフォールバック値を返す
      return 32 * 1024 * 1024 * 1024;  // 32GBのフォールバック
    }
  }

  // ストレージ情報のチェックとサーバーへの送信
  Future<void> _checkAndSendStorageInfo() async {
    try {
      // SharedPreferencesのインスタンスを取得
      final prefs = await SharedPreferences.getInstance();
      
      // デバイス番号を取得
      final deviceNumber = prefs.getInt('device_number');
      if (deviceNumber == null) {
        print('デバイス番号が設定されていません');
        _sendPort?.send('デバイス番号が設定されていません');
        return;
      }
      
      // 空き容量を取得
      final freeSpace = await _getFreeSpace();
      
      // サーバーにデータを送信
      final success = await _sendStorageData(
        deviceNumber: deviceNumber,
        freeSpace: freeSpace,
      );
      
      if (success) {
        // 成功した場合、最終更新情報を保存
        final now = DateTime.now().toIso8601String();
        await prefs.setString('last_sync', now);
        await prefs.setInt('last_free_space', freeSpace);
        
        // 通知を更新
        final freeSpaceGB = (freeSpace / (1024 * 1024 * 1024)).toStringAsFixed(2);
        await updateNotification(
          title: 'ストレージモニター実行中',
          text: 'デバイス #$deviceNumber: $freeSpaceGB GB空き',
        );
        
        _sendPort?.send('データ送信完了: $freeSpaceGB GB空き容量');
      } else {
        _sendPort?.send('データ送信に失敗しました');
      }
    } catch (e) {
      print('ストレージ監視でエラー: $e');
      _sendPort?.send('エラー: $e');
    }
  }

  // 通知を更新する
  Future<void> updateNotification({
    required String title,
    required String text,
  }) async {
    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  // ストレージデータをサーバーに送信
  Future<bool> _sendStorageData({
    required int deviceNumber,
    required int freeSpace,
  }) async {
    try {
      // デバイス情報を取得
      final deviceInfo = DeviceInfoPlugin();
      String deviceModel = "不明";
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceModel = "${androidInfo.manufacturer} ${androidInfo.model}";
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceModel = iosInfo.model;
      }
      
      // JSONデータの作成
      final data = {
        'device_number': deviceNumber,
        'free_space': freeSpace,
        'device_model': deviceModel,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      // リトライロジック
      const maxRetry = 2;
      const retryInterval = Duration(seconds: 5);
      
      for (int i = 0; i <= maxRetry; i++) {
        try {
          final response = await http.post(
            Uri.parse(API_URL),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          );
          
          if (response.statusCode == 200) {
            final responseData = jsonDecode(response.body);
            return responseData['status'] == 'success';
          }
        } catch (e) {
          print('API呼び出しエラー (試行 ${i+1}/${maxRetry+1}): $e');
          
          // 最後の試行でなければ待機して再試行
          if (i < maxRetry) {
            await Future.delayed(retryInterval);
          }
        }
      }
      
      return false;
    } catch (e) {
      print('データ送信処理でエラー: $e');
      return false;
    }
  }
}

// フォアグラウンドタスクの初期化
Future<bool> initForegroundTask() async {
  // 通知テキスト用にデバイス番号を取得
  final prefs = await SharedPreferences.getInstance();
  final deviceNumber = prefs.getInt('device_number') ?? 0;

  // フォアグラウンドタスク設定の初期化 (void型のためawaitなし)
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'storage_monitor_channel',
      channelName: 'ストレージモニターサービス',
      channelDescription: 'デバイスストレージを監視しています',
      channelImportance: NotificationChannelImportance.DEFAULT,
      priority: NotificationPriority.DEFAULT,
      iconData: const NotificationIconData(
        resType: ResourceType.mipmap,
        resPrefix: ResourcePrefix.ic,
        name: 'launcher',
      ),
      buttons: [
        const NotificationButton(
          id: 'refreshButton',
          text: '今すぐ更新',
        ),
      ],
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: const ForegroundTaskOptions(
      interval: 15 * 60 * 1000, // 15分
      isOnceEvent: false,
      autoRunOnBoot: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );

  // タスクハンドラーの登録
  final result = await FlutterForegroundTask.startService(
    notificationTitle: 'ストレージモニター実行中',
    notificationText: 'デバイス #$deviceNumber を監視中',
    callback: startCallback,
  );

  return result;
}

// タスクコールバック用のトップレベル関数
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(StorageMonitorTaskHandler());
}

// サービスを停止
Future<bool> stopForegroundTask() async {
  return await FlutterForegroundTask.stopService();
}