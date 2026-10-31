import 'package:flutter/material.dart';

import '../../services/plantillas_service.dart';
import '../../theme/theme.dart';
import '../../utils/horas_reglas.dart';
import 'plantilla_editor_sheet.dart';

/// Diálogo "Generar plantilla": deja elegir entre la plantilla normal
/// y la de verano, desmarcar algún turno y valida en vivo antes de insertar.
/// Con el lápiz se edita la plantilla y se guarda en el móvil.
///
/// Normal y verano son excluyentes: un día tiene los turnos de una o de
/// otra, nunca mezclados. Por eso generar la plantilla SUSTITUYE los turnos
/// que ya tenga el día (los que coinciden exactamente se dejan como están).
///
/// Devuelve un [PlantillaResultado] o null si se cancela.
class PlantillaResultado {
  /// Tramos elegidos ([inicio, fin] en minutos)
  final List<List<int>> seleccion;

  /// true = el día tenía turnos y se sustituyen por la selección
  final bool reemplazar;

  const PlantillaResultado(this.seleccion, this.reemplazar);
}

class PlantillaDialog extends StatefulWidget {
  final DateTime dia;

  /// Plantillas del usuario (o las de por defecto)
  final Plantillas plantillas;

  /// Turnos que ya tiene el día (se sustituirán)
  final List<List<int>> turnosDelDia;

  /// Valida la selección. Con [reemplazar] = true no se tienen en cuenta
  /// los turnos que ya hay en el día.
  final String? Function(List<List<int>> seleccion, bool reemplazar) validar;

  const PlantillaDialog({
    super.key,
    required this.dia,
    required this.plantillas,
    required this.validar,
    this.turnosDelDia = const [],
  });

  @override
  State<PlantillaDialog> createState() => _PlantillaDialogState();
}

class _PlantillaDialogState extends State<PlantillaDialog> {
  late Plantillas _plantillas = widget.plantillas;

  /// Se abre en la plantilla a la que pertenecen los turnos del día
  late bool _verano = _esDeVerano();
  late List<List<int>> _turnos = _plantillas.de(_verano);
  late List<bool> _marcados = _marcadoInicial(_turnos);

  List<List<int>> get _seleccion => [
    for (var i = 0; i < _turnos.length; i++)
      if (_marcados[i]) _turnos[i],
  ];

  /// Los turnos que ya hay en el día se sustituyen siempre
  bool get _reemplazar => widget.turnosDelDia.isNotEmpty;

  static bool _igual(List<int> a, List<int> b) => a[0] == b[0] && a[1] == b[1];

  /// ¿Los turnos del día son de la plantilla de verano?
  bool _esDeVerano() {
    bool coincide(List<List<int>> tramos) => widget.turnosDelDia.any(
      (t) => tramos.any((p) => _igual(p, t)),
    );
    return coincide(_plantillas.de(true)) && !coincide(_plantillas.de(false));
  }

  /// Turnos actuales del día que desaparecerán con la selección
  List<List<int>> get _seQuitan => [
    for (final t in widget.turnosDelDia)
      if (!_seleccion.any((s) => _igual(s, t))) t,
  ];

  static bool _seSolapan(List<int> a, List<int> b) =>
      a[0] < b[1] && b[0] < a[1];

  /// Cada vez que se abre (o se cambia de plantilla) se comprueba qué tramos
  /// caben: se van marcando en orden y solo si la selección sigue siendo
  /// válida (sin solapes entre sí, sin festivos/permisos, sin pasar el
  /// límite). Los turnos actuales del día no cuentan porque se sustituyen.
  List<bool> _marcadoInicial(List<List<int>> turnos) {
    final marcados = List.filled(turnos.length, false);
    final elegidos = <List<int>>[];
    for (var i = 0; i < turnos.length; i++) {
      final prueba = [...elegidos, turnos[i]];
      if (widget.validar(prueba, _reemplazar) == null) {
        marcados[i] = true;
        elegidos.add(turnos[i]);
      }
    }
    return marcados;
  }

  /// Al marcar un tramo se desmarcan los que se solapan con él
  /// (son alternativos: o uno u otro)
  void _marcar(int i, bool valor) {
    setState(() {
      _marcados[i] = valor;
      if (!valor) return;
      for (var j = 0; j < _turnos.length; j++) {
        if (j != i && _marcados[j] && _seSolapan(_turnos[i], _turnos[j])) {
          _marcados[j] = false;
        }
      }
    });
  }

  void _cambiarPlantilla(bool verano) {
    setState(() {
      _verano = verano;
      _turnos = _plantillas.de(verano);
      _marcados = _marcadoInicial(_turnos);
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
    final error = widget.validar(seleccion, _reemplazar);
    final total = seleccion.fold<int>(0, (s, t) => s + t[1] - t[0]);

    return AlertDialog(
      title: const Text('Generar plantilla'),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
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
                onChanged: (v) => _marcar(i, v ?? false),
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
            if (_seQuitan.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.swap_horiz, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Se sustituirá${_seQuitan.length == 1 ? '' : 'n'} '
                        '${_seQuitan.map((t) => '${minutosAHora(t[0])}–${minutosAHora(t[1])}').join(', ')} '
                        'por el horario ${_verano ? 'de verano' : 'normal'}.',
                        style: TextStyle(color: Colors.grey[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          onPressed: error == null && seleccion.isNotEmpty
              ? () => Navigator.pop(
                  context,
                  PlantillaResultado(seleccion, _reemplazar),
                )
              : null,
          child: Text(_seQuitan.isNotEmpty ? 'Sustituir' : 'Insertar'),
        ),
      ],
    );
  }
}
