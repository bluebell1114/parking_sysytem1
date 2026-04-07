import 'package:shared_preferences/shared_preferences.dart';

/// Backend JWT + хэрэглэгчийн товч мэдээлэл (`mobile_bas2` API).
class AuthPrefs {
  static const _token = 'api_jwt';
  static const _userId = 'api_user_id';
  static const _email = 'api_user_email';
  static const _name = 'api_user_name';
  static const _isAdmin = 'api_is_admin';

  static Future<void> saveSession({
    required String token,
    required String userId,
    required String email,
    required String name,
    required bool isAdmin,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_token, token);
    await p.setString(_userId, userId);
    await p.setString(_email, email);
    await p.setString(_name, name);
    await p.setBool(_isAdmin, isAdmin);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_token);
    await p.remove(_userId);
    await p.remove(_email);
    await p.remove(_name);
    await p.remove(_isAdmin);
  }

  static Future<String?> getToken() async =>
      (await SharedPreferences.getInstance()).getString(_token);

  static Future<String?> getUserId() async =>
      (await SharedPreferences.getInstance()).getString(_userId);

  static Future<String?> getEmail() async =>
      (await SharedPreferences.getInstance()).getString(_email);
}
