import 'package:flutter/material.dart';

class AccountsSnackBar {
  static void showSuccess(BuildContext context, String message) {
    _show(context, message, Colors.green.shade600);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, Colors.red.shade700);
  }

  static void _show(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }
}