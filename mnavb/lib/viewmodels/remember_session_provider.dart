import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_monitoring_service.dart';

class RememberSessionProvider extends ChangeNotifier {
  static const _defaultExternalApiBaseUrl = 'https://mnavb.free.beeceptor.com';
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
    AppMonitoringService.instance.logInfo(
      'UID guardado para background: $uid',
      tag: 'SESSION',
    );
  }

  Future<void> saveBackendTypeForUser(String uid, String backendType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backend_type_$uid', backendType);
    await prefs.setString('saved_backend_type', backendType);

    if (backendType == 'external_api') {
      final current = prefs.getString('external_api_base_url')?.trim() ?? '';
      if (current.isEmpty) {
        await prefs.setString(
          'external_api_base_url',
          _defaultExternalApiBaseUrl,
        );
      }
    }

    AppMonitoringService.instance.logInfo(
      'Backend guardado para $uid: $backendType',
      tag: 'SESSION',
    );
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _remember = prefs.getBool('remember') ?? false;
    _email = prefs.getString('email') ?? '';
    _password = prefs.getString('password') ?? '';
    notifyListeners();
  }
}
