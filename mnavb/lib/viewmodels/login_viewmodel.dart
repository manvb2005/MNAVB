
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';


class LoginViewModel extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  bool isLoading = false;
  String? errorMessage;

  Future<bool> login({required String email, required String password}) async {
    errorMessage = null;
    if (email.isEmpty || password.isEmpty) {
      errorMessage = 'Todos los campos son obligatorios';
      notifyListeners();
      return false;
    }
    isLoading = true;
    notifyListeners();
    try {
      await _firebaseService.loginWithEmail(email: email, password: password);
      isLoading = false;
      notifyListeners();
      return true;
    } on Exception catch (e) {
      errorMessage = _parseError(e);
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  String _parseError(Exception e) {
    final msg = e.toString();
    if (msg.contains('user-not-found')) return 'Usuario no registrado';
    if (msg.contains('wrong-password')) return 'Contraseña incorrecta';
    if (msg.contains('invalid-email')) return 'Email inválido';
    return 'Error de autenticación';
  }
}
