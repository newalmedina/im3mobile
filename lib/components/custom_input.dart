import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/theme.dart';

class CustomInput extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool isPassword;
  final TextInputType keyboardType;
  final bool canVisible;
  final bool hasError;
  final IconData? prefixIcon;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final Function(String)? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;

  const CustomInput({
    super.key,
    required this.controller,
    required this.label,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.canVisible = true,
    this.hasError = false,
    this.prefixIcon,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.inputFormatters,
    this.enabled = true,
  });

  @override
  State<CustomInput> createState() => _CustomInputState();
}

class _CustomInputState extends State<CustomInput> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  void _clearText() {
    widget.controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;

    return TextField(
      controller: widget.controller,
      obscureText: widget.isPassword ? _obscureText : false,
      keyboardType: widget.keyboardType,
      focusNode: widget.focusNode,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      inputFormatters: widget.inputFormatters,
      enabled: widget.enabled,
      onChanged: (_) => setState(() {}),

      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: const TextStyle(color: AppColors.primary),

        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: widget.hasError ? Colors.red : AppColors.primary,
            width: 2,
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: widget.hasError ? Colors.red : AppColors.primary,
            width: 2,
          ),
        ),

        prefixIcon: widget.isPassword
            ? const Icon(Icons.lock)
            : (widget.prefixIcon != null
                  ? Icon(widget.prefixIcon, color: AppColors.primary)
                  : null),

        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🗑 LIMPIAR (SIN FOCO)
            if (hasText)
              Focus(
                skipTraversal: true,
                child: GestureDetector(
                  onTap: _clearText,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.delete_outline, color: AppColors.primary),
                  ),
                ),
              ),

            // 👁 VISIBILIDAD PASSWORD
            if (widget.isPassword && widget.canVisible)
              Focus(
                skipTraversal: true,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      _obscureText ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
