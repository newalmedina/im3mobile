// lib/widgets/snackbar_helper.dart
import 'package:flutter/material.dart';

/// Helper para mostrar Snackbars de forma uniforme en toda la app
class SnackbarHelper {
  /// Muestra un Snackbar
  /// [message]: mensaje a mostrar (obligatorio)
  /// [backgroundColor]: color de fondo (default: morado/rojo)
  /// [duration]: duración del snackbar (default: 3 segundos)
  static void show(
    BuildContext context, {
    required String message,
    Color backgroundColor = const Color.fromARGB(255, 178, 3, 253),
    Duration duration = const Duration(seconds: 2),
  }) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: duration,
        ),
      );
    }
  }
}
