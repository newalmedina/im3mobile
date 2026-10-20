import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../../utils/horas_reglas.dart';

/// Hoja para editar los tramos de una plantilla (normal o verano).
///
/// Devuelve:
///   - la lista de tramos nueva si se pulsa "Guardar",
///   - [PlantillaEditorSheet.restablecer] si se pulsa "Restablecer",
///   - null si se cierra sin guardar.
class PlantillaEditorSheet extends StatefulWidget {
  final String titulo;
  final List<List<int>> tramos;

  const PlantillaEditorSheet({
    super.key,
    required this.titulo,
    required this.tramos,
  });

  /// Valor especial: volver a la plantilla por defecto
  static const List<List<int>> restablecer = [];

  static Future<List<List<int>>?> abrir(
    BuildContext context, {
    required String titulo,
    required List<List<int>> tramos,
  }) {
    return showModalBottomSheet<List<List<int>>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => PlantillaEditorSheet(titulo: titulo, tramos: tramos),
    );
  }

  @override
  State<PlantillaEditorSheet> createState() => _PlantillaEditorSheetState();
}

class _PlantillaEditorSheetState extends State<PlantillaEditorSheet> {
  late final List<List<int>> _tramos = [
    for (final t in widget.tramos) [t[0], t[1]],
  ];

  int get _total => _tramos.fold(0, (s, t) => s + t[1] - t[0]);

  /// Mismas reglas básicas que un turno: 07:00–19:00, fin > inicio, sin solapes
  String? get _error {
    if (_tramos.isEmpty) return 'Añade al menos un tramo.';
    final orden = [..._tramos]..sort((a, b) => a[0].compareTo(b[0]));
    for (var i = 0; i < orden.length; i++) {
      final t = orden[i];
      if (t[0] < HorasReglas.horaMinima || t[1] > HorasReglas.horaMaxima) {
        return 'Los tramos tienen que estar entre '
            '${minutosAHora(HorasReglas.horaMinima)} y '
            '${minutosAHora(HorasReglas.horaMaxima)}.';
      }
      if (t[1] <= t[0]) {
        return 'En el tramo ${minutosAHora(t[0])}, la salida tiene que ser '
            'posterior a la entrada.';
      }
      if (i > 0 && t[0] < orden[i - 1][1]) {
        return 'Los tramos ${minutosAHora(orden[i - 1][0])}–'
            '${minutosAHora(orden[i - 1][1])} y ${minutosAHora(t[0])}–'
            '${minutosAHora(t[1])} se solapan.';
      }
    }
    return null;
  }

  Future<void> _elegir(int i, {required bool esInicio}) async {
    final actual = _tramos[i][esInicio ? 0 : 1];
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
    setState(() => _tramos[i][esInicio ? 0 : 1] = hora.hour * 60 + hora.minute);
  }

  /// Nuevo tramo: una hora después del último (o a las 08:00)
  void _anadir() {
    final ultimoFin = _tramos.isEmpty
        ? 8 * 60
        : _tramos.map((t) => t[1]).reduce((a, b) => a > b ? a : b);
    final inicio = ultimoFin.clamp(HorasReglas.horaMinima, HorasReglas.horaMaxima);
    final fin = (inicio + 60).clamp(inicio, HorasReglas.horaMaxima);
    setState(() => _tramos.add([inicio, fin]));
  }

  void _guardar() {
    if (_error != null) return;
    final orden = [..._tramos]..sort((a, b) => a[0].compareTo(b[0]));
    Navigator.pop(context, orden);
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;

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
          const SizedBox(height: 4),
          Text(
            'Se guarda en este móvil y se usará cada vez que generes la plantilla.',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 16),

          // Tramos
          for (var i = 0; i < _tramos.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: _HoraBoton(
                      etiqueta: 'Entrada',
                      valor: minutosAHora(_tramos[i][0]),
                      onTap: () => _elegir(i, esInicio: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _HoraBoton(
                      etiqueta: 'Salida',
                      valor: minutosAHora(_tramos[i][1]),
                      onTap: () => _elegir(i, esInicio: false),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Quitar tramo',
                    onPressed: () => setState(() => _tramos.removeAt(i)),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),

          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _anadir,
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              icon: const Icon(Icons.add),
              label: const Text('Añadir tramo'),
            ),
          ),
          const Divider(),
          Row(
            children: [
              const Text('Total'),
              const Spacer(),
              Text(
                '${minutosAHora(_total < 0 ? 0 : _total)} h',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
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
                crossAxisAlignment: CrossAxisAlignment.start,
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

          Row(
            children: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, PlantillaEditorSheet.restablecer),
                style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
                child: const Text('Restablecer'),
              ),
              const Spacer(),
              SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed: error == null ? _guardar : null,
                  child: const Text('Guardar', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HoraBoton extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final VoidCallback onTap;

  const _HoraBoton({
    required this.etiqueta,
    required this.valor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        children: [
          Text(etiqueta, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 2),
          Text(
            valor,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
