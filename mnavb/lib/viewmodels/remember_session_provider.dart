import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RememberSessionProvider extends ChangeNotifier {
  bool _remember = false;
  String _email = '';
  String _password = '';

  bool get remember => _remember;
  String get email => _email;
  String get password => _password;

  RememberSessionProvider() {
    loadSession();
  }

  Future<void> loadSession() => _loadSession();

  void setRemember(bool value) async {
    _remember = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('remember', value);
    if (!value) {
      prefs.remove('email');
      prefs.remove('password');
      _email = '';
      _password = '';
      notifyListeners();
    }
  }

  Future<void> saveCredentials(String email, String password) async {
    if (_remember) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('email', email);
      await prefs.setString('password', password);
      _email = email;
      _password = password;
      notifyListeners();
    }
  }

  /// Guarda el UID del usuario para procesamiento en background
  Future<void> saveUserId(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_uid', uid);
    print('✅ UID guardado para background: $uid');
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _remember = prefs.getBool('remember') ?? false;
    _email = prefs.getString('email') ?? '';
    _password = prefs.getString('password') ?? '';
    notifyListeners();
  }
}
