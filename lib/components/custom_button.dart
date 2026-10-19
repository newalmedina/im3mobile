import 'package:flutter/material.dart';
import '../theme/theme.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? color; // Color opcional
  final IconData? icon; // Icono opcional
  final bool isCircular; // ✅ Nuevo parámetro

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color, // Si no se pasa, usa AppColors.primary
    this.icon, // Si no se pasa, botón sin icono
    this.isCircular = false, // Por defecto falso
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = isCircular
        ? BorderRadius.circular(50)
        : BorderRadius.circular(8);

    // Botón con icono
    if (icon != null) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: borderRadius),
          ),
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white, size: 22),
          label: Center(
            child: Text(
              text,
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        ),
      );
    }

    // Botón normal
    return SizedBox(
      width: isCircular ? 50 : double.infinity, // Si es circular, ancho = alto
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
        onPressed: onPressed,
        child: Center(
          child: Text(
            text,
            style: const TextStyle(fontSize: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
