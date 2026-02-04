
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/user_model.dart';


class RegisterViewModel extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  bool isLoading = false;
  String? errorMessage;
  String? successMessage;

  Future<bool> register({
    required String name,
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
    String? phone,
  }) async {
    errorMessage = null;
    successMessage = null;
    // Validación campos obligatorios
    if (name.isEmpty || username.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      errorMessage = 'Todos los campos son obligatorios';
      notifyListeners();
      return false;
    }
    // Validación email solo @gmail.com
    String emailFinal = email;
    if (!email.endsWith('@gmail.com')) {
      emailFinal = "$email@gmail.com";
    }
    final emailReg = RegExp(r'^[a-zA-Z0-9_.+-]+@gmail\.com$');
    if (!emailReg.hasMatch(emailFinal)) {
      errorMessage = 'El correo debe ser válido y terminar en @gmail.com';
      notifyListeners();
      return false;
    }
    // Validación teléfono
    if (phone != null && phone.isNotEmpty) {
      final phoneReg = RegExp(r'^\d{9}$');
      if (!phoneReg.hasMatch(phone)) {
        errorMessage = 'El número de teléfono debe tener exactamente 9 dígitos numéricos';
        notifyListeners();
        return false;
      }
    }
    // Validación contraseñas
    if (password != confirmPassword) {
      errorMessage = 'Las contraseñas no coinciden';
      notifyListeners();
      return false;
    }
    if (password.length < 6) {
      errorMessage = 'La contraseña debe tener al menos 6 caracteres';
      notifyListeners();
      return false;
    }
    isLoading = true;
    notifyListeners();
    try {
      final cred = await _firebaseService.registerWithEmail(email: emailFinal, password: password);
      final user = UserModel(
        id: cred.user!.uid,
        name: name,
        username: username,
        email: emailFinal,
        phone: phone,
      );
      await _firebaseService.createUserDocument(user);
      isLoading = false;
      successMessage = 'Registro exitoso';
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
    if (msg.contains('email-already-in-use')) return 'El email ya está registrado';
    if (msg.contains('invalid-email')) return 'Email inválido';
    return 'Error al registrar usuario';
  }
}
