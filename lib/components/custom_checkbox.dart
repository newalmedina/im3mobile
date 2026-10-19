// lib/components/custom_checkbox.dart
import 'package:flutter/material.dart';
import '../theme/theme.dart';

class CustomCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final double size;
  final Color borderColor;
  final Color activeColor;

  const CustomCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 24.0,
    this.borderColor = AppColors.primary,
    this.activeColor = AppColors.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Checkbox(
        value: value,
        onChanged: onChanged,
        checkColor: Colors.white,
        fillColor: WidgetStateProperty.resolveWith<Color>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.selected)) {
            return activeColor; // fondo cuando está marcado
          }
          return Colors.transparent; // fondo cuando no está marcado
        }),
        side: BorderSide(
          color: borderColor, // borde cuando no está marcado
          width: 2,
        ),
      ),
    );
  }
}
