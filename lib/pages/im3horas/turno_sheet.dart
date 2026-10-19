import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../../utils/horas_reglas.dart';

/// Hoja que sale desde abajo para crear o editar un turno.
///
/// [validar] se ejecuta en vivo al cambiar las horas (reglas locales).
/// [onGuardar] llama a la API; devuelve null si fue bien o el mensaje de error
/// (así la hoja no se cierra si el servidor rechaza el turno).
class TurnoSheet extends StatefulWidget {
  final String titulo;
  final String textoBoton;
  final int inicio;
  final int fin;
  final String? Function(int inicio, int fin) validar;
  final Future<String?> Function(int inicio, int fin) onGuardar;

  const TurnoSheet({
    super.key,
    required this.titulo,
    required this.textoBoton,
    required this.inicio,
    required this.fin,
    required this.validar,
    required this.onGuardar,
  });

  /// Abre la hoja. Devuelve true si se guardó.
  static Future<bool> abrir(BuildContext context, TurnoSheet sheet) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => sheet,
    );
    return ok == true;
  }

  @override
  State<TurnoSheet> createState() => _TurnoSheetState();
}

class _TurnoSheetState extends State<TurnoSheet> {
  late int _inicio = widget.inicio;
  late int _fin = widget.fin;
  bool _guardando = false;
  String? _errorServidor;

  String? get _error => widget.validar(_inicio, _fin);

  Future<void> _elegir({required bool esInicio}) async {
    final actual = esInicio ? _inicio : _fin;
    final hora = await showTimePicker(
      context: context,
      helpText: esInicio ? 'Hora de entrada' : 'Hora de salida',
      initialTime: TimeOfDay(hour: actual ~/ 60, minute: actual % 60),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (hora == null) return;
    setState(() {
      _errorServidor = null;
      final m = hora.hour * 60 + hora.minute;
      if (esInicio) {
        _inicio = m;
      } else {
        _fin = m;
      }
    });
  }

  Future<void> _guardar() async {
    if (_error != null) return;
    setState(() {
      _guardando = true;
      _errorServidor = null;
    });
    final error = await widget.onGuardar(_inicio, _fin);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _guardando = false;
        _errorServidor = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error ?? _errorServidor;
    final duracion = _fin - _inicio;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.titulo,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _HoraBoton(
                  etiqueta: 'Entrada',
                  valor: minutosAHora(_inicio),
                  onTap: _guardando ? null : () => _elegir(esInicio: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HoraBoton(
                  etiqueta: 'Salida',
                  valor: minutosAHora(_fin),
                  onTap: _guardando ? null : () => _elegir(esInicio: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            duracion > 0 ? 'Duración: ${minutosAHora(duracion)} h' : ' ',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[700]),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: (_error != null || _guardando) ? null : _guardar,
              child: _guardando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(widget.textoBoton, style: const TextStyle(fontSize: 17)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HoraBoton extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final VoidCallback? onTap;

  const _HoraBoton({required this.etiqueta, required this.valor, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(etiqueta, style: TextStyle(color: Colors.grey[700])),
            const SizedBox(height: 4),
            Text(
              valor,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
