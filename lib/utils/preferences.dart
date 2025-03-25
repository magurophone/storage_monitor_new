import 'package:shared_preferences/shared_preferences.dart';

class PreferencesUtil {
  static const String DEVICE_NUMBER_KEY = 'device_number';
  static const String SETUP_COMPLETED_KEY = 'setup_completed';
  static const String FIRST_RUN_KEY = 'first_run';
  static const String LAST_SYNC_KEY = 'last_sync';
  static const String LAST_FREE_SPACE_KEY = 'last_free_space';

  // デバイス番号を保存
  static Future<bool> saveDeviceNumber(int deviceNumber) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setInt(DEVICE_NUMBER_KEY, deviceNumber);
  }

  // デバイス番号を取得
  static Future<int?> getDeviceNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(DEVICE_NUMBER_KEY);
  }

  // セットアップ完了フラグを保存
  static Future<bool> setSetupCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setBool(SETUP_COMPLETED_KEY, completed);
  }

  // セットアップ完了フラグを取得
  static Future<bool> isSetupCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(SETUP_COMPLETED_KEY) ?? false;
  }
  
  // 初回実行フラグを取得
  static Future<bool> isFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    // 値が存在しない場合はtrueを返す (= 初回実行とみなす)
    return prefs.getBool(FIRST_RUN_KEY) ?? true;
  }
  
  // 初回実行フラグを設定
  static Future<bool> setFirstRun(bool isFirstRun) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setBool(FIRST_RUN_KEY, isFirstRun);
  }
  
  // 最終同期日時を取得
  static Future<String?> getLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(LAST_SYNC_KEY);
  }
  
  // 最終空き容量を取得
  static Future<int?> getLastFreeSpace() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(LAST_FREE_SPACE_KEY);
  }
}