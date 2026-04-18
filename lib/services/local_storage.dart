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

// Top-level wrappers so callers using a library alias (e.g. import '.../local_storage.dart' as LocalStorage; LocalStorage.getString(...))
// continue to work. Also add small debug prints.
String? getString(String key) {
  final v = LocalStorage.getString(key);
  print('[LocalStorage] getString key=$key -> ${v == null ? 'null' : 'value(len=${v.length})'}');

  //print all the customers data locally and stored in supabase

  return v;
}

Future<bool> setString(String key, String value) async {
  print('[LocalStorage] setString key=$key value-len=${value.length}');
  return LocalStorage.setString(key, value);
}


Future<bool> remove(String key) async {
  print('[LocalStorage] remove key=$key');
  return LocalStorage.remove(key);
}
