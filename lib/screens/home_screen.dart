import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/preferences.dart';
import '../utils/optimization_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int? deviceNumber;
  String? lastSync;
  int? lastFreeSpace;
  bool isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    
    // 定期的に画面を更新（30秒ごと）
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadData();
      }
    });
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // データを読み込む
  Future<void> _loadData() async {
    final number = await PreferencesUtil.getDeviceNumber();
    final sync = await PreferencesUtil.getLastSync();
    final space = await PreferencesUtil.getLastFreeSpace();
    
    if (mounted) {
      setState(() {
        deviceNumber = number;
        lastSync = sync;
        lastFreeSpace = space;
        isLoading = false;
      });
    }
  }
  
  // GB単位に変換
  String _formatSize(int? bytes) {
    if (bytes == null) return '不明';
    final gb = bytes / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(2)} GB';
  }
  
  // 日時をフォーマット
  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return '同期情報なし';
    
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inSeconds < 60) {
        return '${difference.inSeconds}秒前';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}分前';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}時間前';
      } else {
        return '${difference.inDays}日前';
      }
    } catch (e) {
      return dateTimeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('空き容量モニター'),
        actions: [
          IconButton(
            icon: Icon(Icons.battery_alert),
            onPressed: () => OptimizationHelper.showOptimizationDialog(context),
            tooltip: 'バッテリー設定',
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(),
            tooltip: '設定',
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'デバイス情報',
                              style: Theme.of(context).textTheme.titleLarge,  // 修正: headline6 から titleLarge へ
                            ),
                            SizedBox(height: 8),
                            Text('デバイス番号: 【$deviceNumber】'),
                            SizedBox(height: 4),
                            Text('ステータス: モニタリング中'),
                            SizedBox(height: 4),
                            Text('最終同期: ${_formatDateTime(lastSync)}'),
                            SizedBox(height: 4),
                            Text('空き容量: ${_formatSize(lastFreeSpace)}'),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '動作ステータス',
                              style: Theme.of(context).textTheme.titleLarge,  // 修正: headline6 から titleLarge へ
                            ),
                            SizedBox(height: 8),
                            ListTile(
                              leading: Icon(Icons.access_time, color: Colors.blue),
                              title: Text('送信頻度'),
                              subtitle: Text('10分ごと'),
                              dense: true,
                            ),
                            ListTile(
                              leading: Icon(
                                lastSync != null 
                                  ? Icons.check_circle 
                                  : Icons.error, 
                                color: lastSync != null 
                                  ? Colors.green 
                                  : Colors.red
                              ),
                              title: Text('同期状態'),
                              subtitle: Text(
                                lastSync != null 
                                  ? '正常に動作しています' 
                                  : '同期記録がありません'
                              ),
                              dense: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ヘルプ',
                              style: Theme.of(context).textTheme.titleLarge,  // 修正: headline6 から titleLarge へ
                            ),
                            SizedBox(height: 8),
                            ListTile(
                              leading: Icon(Icons.battery_alert, color: Colors.orange),
                              title: Text('バッテリー最適化設定'),
                              subtitle: Text('端末のバッテリー設定を変更して、バックグラウンド動作を最適化します'),
                              onTap: () => OptimizationHelper.showOptimizationDialog(context),
                              dense: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'このアプリはバックグラウンドで動作しています。',
                      style: Theme.of(context).textTheme.bodyMedium,  // 修正: bodyText2 から bodyMedium へ
                    ),
                    Text(
                      'デバイスの空き容量情報を10分ごとに送信しています。',
                      style: Theme.of(context).textTheme.bodyMedium,  // 修正: bodyText2 から bodyMedium へ
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadData,
        tooltip: '手動更新',
        child: Icon(Icons.refresh),
      ),
    );
  }

  // 設定ダイアログを表示
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('設定'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('現在のデバイス番号: 【$deviceNumber】'),
            SizedBox(height: 16),
            Text('デバイス番号を変更するには、アプリを再インストールしてください。'),
            SizedBox(height: 16),
            Text('最終同期: ${_formatDateTime(lastSync)}'),
            SizedBox(height: 4),
            Text('空き容量: ${_formatSize(lastFreeSpace)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('閉じる'),
          ),
        ],
      ),
    );
  }
}