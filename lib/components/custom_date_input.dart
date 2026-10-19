import 'package:flutter/material.dart';
import '../theme/theme.dart';

class CustomDateInput extends StatefulWidget {
  final TextEditingController controller;
  final String? label;
  final DateTime? initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool hasError;
  final bool enabled;
  final Function(DateTime)? onDateSelected;

  const CustomDateInput({
    super.key,
    required this.controller,
    this.label,
    this.initialDate,
    this.firstDate,
    this.lastDate,
    this.hasError = false,
    this.enabled = true,
    this.onDateSelected,
  });

  @override
  State<CustomDateInput> createState() => _CustomDateInputState();
}

class _CustomDateInputState extends State<CustomDateInput> {
  Future<void> _pickDate() async {
    if (!widget.enabled) return;

    final picked = await showDatePicker(
      context: context,
      locale: const Locale('es', 'ES'),
      initialDate: widget.initialDate ?? DateTime.now(),
      firstDate: widget.firstDate ?? DateTime(2000),
      lastDate: widget.lastDate ?? DateTime(2030),
      helpText: 'Seleccionar fecha',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      fieldHintText: 'dd/mm/aaaa',
      fieldLabelText: 'Fecha',
    );

    if (picked != null) {
      widget.controller.text = DateFormat('dd-MM-yyyy', 'es_ES').format(picked);

      widget.onDateSelected?.call(picked);

      setState(() {});
    }
  }

  void _clearDate() {
    widget.controller.clear();

    if (widget.onDateSelected != null) {
      widget.onDateSelected!(DateTime(0));
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.controller.text.isNotEmpty;

    return TextField(
      controller: widget.controller,
      readOnly: true,
      enabled: widget.enabled,
      onTap: _pickDate,
      decoration: InputDecoration(
        labelText: widget.label ?? '',
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
        prefixIcon: IconButton(
          tooltip: 'Seleccionar fecha',
          icon: const Icon(Icons.calendar_today, color: AppColors.primary),
          onPressed: _pickDate,
        ),
        suffixIcon: hasValue
            ? IconButton(
                tooltip: 'Limpiar fecha',
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: _clearDate,
              )
            : null,
      ),
    );
  }
}
