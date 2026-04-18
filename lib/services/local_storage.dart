import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static late SharedPreferences _prefs;
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String? getString(String key) => _prefs.getString(key);

  static Future<bool> setString(String key, String value) async {
    return _prefs.setString(key, value);
  }

  static Future<bool> remove(String key) async {
    return _prefs.remove(key);
  }
}

