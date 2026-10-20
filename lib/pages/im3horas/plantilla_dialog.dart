import 'package:flutter/material.dart';

import '../../services/plantillas_service.dart';
import '../../theme/theme.dart';
import '../../utils/horas_reglas.dart';
import 'plantilla_editor_sheet.dart';

/// Diálogo "Generar plantilla": deja elegir entre la plantilla normal
/// y la de verano, desmarcar algún turno y valida en vivo antes de insertar.
/// Con el lápiz se edita la plantilla y se guarda en el móvil.
///
/// Devuelve la lista de turnos elegidos ([inicio, fin] en minutos)
/// o null si se cancela.
class PlantillaDialog extends StatefulWidget {
  final DateTime dia;

  /// Plantillas del usuario (o las de por defecto)
  final Plantillas plantillas;
  final String? Function(List<List<int>> seleccion) validar;

  const PlantillaDialog({
    super.key,
    required this.dia,
    required this.plantillas,
    required this.validar,
  });

  @override
  State<PlantillaDialog> createState() => _PlantillaDialogState();
}

class _PlantillaDialogState extends State<PlantillaDialog> {
  late Plantillas _plantillas = widget.plantillas;
  bool _verano = false;
  late List<List<int>> _turnos = _plantillas.de(_verano);
  late List<bool> _marcados = List.filled(_turnos.length, true);

  List<List<int>> get _seleccion => [
    for (var i = 0; i < _turnos.length; i++)
      if (_marcados[i]) _turnos[i],
  ];

  void _cambiarPlantilla(bool verano) {
    setState(() {
      _verano = verano;
      _turnos = _plantillas.de(verano);
      _marcados = List.filled(_turnos.length, true);
    });
  }

  String get _descripcion =>
      _verano ? 'Tu horario de verano' : 'Tu horario normal';

  /// Lápiz: editar la plantilla que se está viendo y guardarla
  Future<void> _editar() async {
    final tramos = await PlantillaEditorSheet.abrir(
      context,
      titulo: _verano ? 'Plantilla de verano' : 'Plantilla normal',
      tramos: _plantillas.de(_verano),
    );
    if (tramos == null || !mounted) return;

    try {
      final nuevas = tramos.isEmpty
          ? await PlantillasService.restablecer(_plantillas, _verano)
          : _plantillas.con(_verano, tramos);
      if (tramos.isNotEmpty) await PlantillasService.guardar(nuevas);
      if (!mounted) return;
      setState(() => _plantillas = nuevas);
      _cambiarPlantilla(_verano);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la plantilla.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final seleccion = _seleccion;
    final error = widget.validar(seleccion);
    final total = seleccion.fold<int>(0, (s, t) => s + t[1] - t[0]);

    return AlertDialog(
      title: const Text('Generar plantilla'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Normal / Verano
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  selectedForegroundColor: Colors.white,
                  selectedBackgroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                ),
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Normal'),
                    icon: Icon(Icons.work_outline),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Verano'),
                    icon: Icon(Icons.wb_sunny_outlined),
                  ),
                ],
                selected: {_verano},
                onSelectionChanged: (s) => _cambiarPlantilla(s.first),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _descripcion,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
                TextButton.icon(
                  onPressed: _editar,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                ),
              ],
            ),
            for (var i = 0; i < _turnos.length; i++)
              CheckboxListTile(
                value: _marcados[i],
                onChanged: (v) => setState(() => _marcados[i] = v ?? false),
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  '${minutosAHora(_turnos[i][0])} – ${minutosAHora(_turnos[i][1])}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  '${minutosAHora(_turnos[i][1] - _turnos[i][0])} h',
                ),
              ),
            const Divider(),
            Row(
              children: [
                const Text('Total a insertar'),
                const Spacer(),
                Text(
                  '${minutosAHora(total)} h',
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: error == null
              ? () => Navigator.pop(context, seleccion)
              : null,
          child: const Text('Insertar'),
        ),
      ],
    );
  }
}
