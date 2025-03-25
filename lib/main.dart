import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/background_service.dart'; // 先ほど作成したバックグラウンドサービスファイルへのパス
import 'screens/setup_screen.dart';
import 'screens/home_screen.dart';
import 'utils/optimization_helper.dart';

void main() async {
  // Flutter初期化を確実に行う
  WidgetsFlutterBinding.ensureInitialized();
  
  // バックグラウンドタスクを初期化
  try {
    initializeBackgroundTasks();
    debugPrint('バックグラウンドタスクの初期化に成功しました');
  } catch (e) {
    debugPrint('バックグラウンドタスクの初期化でエラー: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '空き容量モニター',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: FutureBuilder<bool>(
        future: _isSetupCompleted(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          
          final setupCompleted = snapshot.data ?? false;
          return setupCompleted 
              ? const BatteryOptimizationWrapper(child: HomeScreen())
              : const SetupScreen();
        },
      ),
    );
  }
  
  // セットアップが完了しているかどうかを確認
  Future<bool> _isSetupCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('setup_completed') ?? false;
    } catch (e) {
      debugPrint('設定値の取得中にエラー: $e');
      return false;
    }
  }
}

// バッテリー最適化設定を案内するラッパーウィジェット
class BatteryOptimizationWrapper extends StatefulWidget {
  final Widget child;
  
  const BatteryOptimizationWrapper({super.key, required this.child});
  
  @override
  _BatteryOptimizationWrapperState createState() => _BatteryOptimizationWrapperState();
}

class _BatteryOptimizationWrapperState extends State<BatteryOptimizationWrapper> {
  bool _checkingOptimization = true;
  
  @override
  void initState() {
    super.initState();
    _checkOptimizationSettings();
  }
  
  Future<void> _checkOptimizationSettings() async {
    try {
      // 初回実行フラグを確認
      final prefs = await SharedPreferences.getInstance();
      final isFirstRun = prefs.getBool('first_run') ?? true;
      
      // 最適化設定のダイアログを表示するかどうか
      if (isFirstRun) {
        // 1秒待機して、UIが完全に描画された後にダイアログを表示
        if (mounted) {
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              OptimizationHelper.showOptimizationDialog(context).then((_) async {
                // 初回実行フラグをオフに
                await prefs.setBool('first_run', false);
                
                if (mounted) {
                  setState(() {
                    _checkingOptimization = false;
                  });
                }
              });
            }
          });
        }
      } else {
        setState(() {
          _checkingOptimization = false;
        });
      }
    } catch (e) {
      debugPrint('最適化設定チェック中にエラー: $e');
      setState(() {
        _checkingOptimization = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_checkingOptimization) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return widget.child;
  }
}