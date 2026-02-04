import 'package:flutter/material.dart';

class AppNavigator {
  static void goToRegister(BuildContext context) {
    Navigator.pushNamed(context, '/register');
  }

  static void goToLogin(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  static void goToHome(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }
}
