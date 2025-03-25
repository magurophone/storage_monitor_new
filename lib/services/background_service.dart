import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// バックグラウンドタスクの定数
const String STORAGE_MONITOR_TASK = 'storageMonitorTask';
const String API_URL = 'https://example.com/api/receive_data.php'; // 実際のURLに変更

// アプリの初期化時に呼び出す関数
void initializeBackgroundTasks() {
  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false, // 本番環境ではfalse
  );
  
  // 定期的なタスクを登録（15分ごと）
  Workmanager().registerPeriodicTask(
    'storageMonitor',
    STORAGE_MONITOR_TASK,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected, // インターネット接続時のみ実行
    ),
    existingWorkPolicy: ExistingWorkPolicy.replace, // 既存のタスクを置き換え
    backoffPolicy: BackoffPolicy.linear, // 失敗時は線形的に再試行間隔を増加
  );
  
  debugPrint('バックグラウンドタスクが初期化されました');
}

// このコールバックはトップレベルの関数として定義する必要があります
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      debugPrint('バックグラウンドタスク実行: $task');
      
      // タスクの種類に応じた処理
      if (task == STORAGE_MONITOR_TASK) {
        final success = await _checkAndSendStorageInfo();
        return success;
      }
      
      return true;
    } catch (e) {
      debugPrint('バックグラウンドタスクでエラー発生: $e');
      return false; // タスクを失敗として扱う（再試行される）
    }
  });
}

// ストレージ情報の取得と送信
Future<bool> _checkAndSendStorageInfo() async {
  try {
    // SharedPreferencesのインスタンスを取得
    final prefs = await SharedPreferences.getInstance();
    
    // デバイス番号を取得
    final deviceNumber = prefs.getInt('device_number');
    if (deviceNumber == null) {
      debugPrint('デバイス番号が設定されていません');
      return false;
    }
    
    // 空き容量を取得
    final freeSpace = await _getFreeSpace();
    
    // APIにデータを送信
    final success = await _sendStorageData(
      deviceNumber: deviceNumber,
      freeSpace: freeSpace,
    );
    
    if (success) {
      // 成功した場合、最終更新情報を保存
      final now = DateTime.now().toIso8601String();
      await prefs.setString('last_sync', now);
      await prefs.setInt('last_free_space', freeSpace);
      debugPrint('データ送信成功: デバイス番号=$deviceNumber, 空き容量=${freeSpace}バイト, 時刻=$now');
    }
    
    return success;
  } catch (e) {
    debugPrint('ストレージ情報の確認と送信でエラー: $e');
    return false;
  }
}

// 空き容量のみを取得する関数
Future<int> _getFreeSpace() async {
  try {
    // 外部ストレージディレクトリの取得を試みる
    Directory? directory;
    
    try {
      directory = await getExternalStorageDirectory();
    } catch (e) {
      debugPrint('外部ストレージへのアクセスエラー: $e');
    }
    
    // 外部ストレージが取得できない場合はアプリケーションディレクトリを使用
    directory ??= await getApplicationDocumentsDirectory();

    // ファイルシステムの統計情報を取得
    final statFs = directory.statSync();
    
    // 利用可能なサイズを取得
    return statFs.size;
  } catch (e) {
    debugPrint('空き容量の取得に失敗: $e');
    
    // エラー時はデフォルト値を返す
    return 32 * 1024 * 1024 * 1024;  // 32GB（エラー時のフォールバック値）
  }
}

// サーバーにデータを送信する関数
Future<bool> _sendStorageData({
  required int deviceNumber,
  required int freeSpace,
}) async {
  try {
    // デバイス情報を取得
    final deviceInfo = DeviceInfoPlugin();
    String deviceModel = "Unknown";
    
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceModel = "${androidInfo.manufacturer} ${androidInfo.model}";
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceModel = iosInfo.model;  // 直接代入でOK
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
        debugPrint('API呼び出しエラー (試行 ${i+1}/${maxRetry+1}): $e');
        
        // 最後の試行でなければ待機して再試行
        if (i < maxRetry) {
          await Future.delayed(retryInterval);
        }
      }
    }
    
    return false;
  } catch (e) {
    debugPrint('データ送信処理でエラー: $e');
    return false;
  }
}