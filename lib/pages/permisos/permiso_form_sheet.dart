import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/permisos_service.dart';
import '../../theme/theme.dart';
import '../../utils/horas_reglas.dart';
import 'permisos_catalogo.dart';

/// Hoja que sale desde abajo para solicitar un permiso nuevo.
/// Mismos campos que el modal de permisos.vue (sin archivo adjunto).
class PermisoFormSheet extends StatefulWidget {
  const PermisoFormSheet({super.key});

  /// Abre la hoja. Devuelve true si se creó el permiso.
  static Future<bool> abrir(BuildContext context) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => const PermisoFormSheet(),
    );
    return ok == true;
  }

  @override
  State<PermisoFormSheet> createState() => _PermisoFormSheetState();
}

class _PermisoFormSheetState extends State<PermisoFormSheet> {
  final DateTime _hoy = soloFecha(DateTime.now());
  final _comentarios = TextEditingController();

  String _tipo = TipoPermiso.permiso;
  bool _unDia = true;
  String _categoria = '';
  DateTime? _fechaIni;
  DateTime? _fechaFin;
  int? _horaIni;
  int? _horaFin;

  bool _intentado = false; // los errores se ven al pulsar "Solicitar"
  bool _guardando = false;
  String? _errorServidor;

  bool get _esRecuperable => _tipo == TipoPermiso.recuperable;

  String? get _error {
    if (!_esRecuperable && _categoria.isEmpty) {
      return 'Elige el tipo de permiso.';
    }
    if (_fechaIni == null) {
      return _unDia ? 'Elige el día.' : 'Elige la fecha de inicio.';
    }
    if (_unDia) {
      if (_horaIni == null || _horaFin == null) {
        return 'Elige la hora de inicio y la de fin.';
      }
      if (_horaFin! <= _horaIni!) {
        return 'La hora final tiene que ser posterior a la de inicio.';
      }
    } else {
      if (_fechaFin == null) return 'Elige la fecha final.';
      if (!_fechaFin!.isAfter(_fechaIni!)) {
        return 'La fecha final tiene que ser posterior a la de inicio.';
      }
    }
    return null;
  }

  // =========================================================
  // SELECTORES
  // =========================================================
  Future<void> _elegirFecha({required bool esInicio}) async {
    final actual = esInicio ? _fechaIni : _fechaFin;
    final elegida = await showDatePicker(
      context: context,
      initialDate: actual ?? (esInicio ? null : _fechaIni) ?? _hoy,
      firstDate: DateTime(_hoy.year - 1),
      lastDate: DateTime(_hoy.year + 2, 12, 31),
      helpText: esInicio ? 'Fecha de inicio' : 'Fecha final',
    );
    if (elegida == null) return;
    setState(() {
      _errorServidor = null;
      if (esInicio) {
        _fechaIni = elegida;
      } else {
        _fechaFin = elegida;
      }
    });
  }

  Future<void> _elegirHora({required bool esInicio}) async {
    final actual = (esInicio ? _horaIni : _horaFin) ??
        (esInicio ? 9 * 60 : (_horaIni ?? 9 * 60) + 60);
    final hora = await showTimePicker(
      context: context,
      helpText: esInicio ? 'Hora de inicio' : 'Hora final',
      initialTime: TimeOfDay(hour: (actual ~/ 60) % 24, minute: actual % 60),
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
        _horaIni = m;
      } else {
        _horaFin = m;
      }
    });
  }

  // =========================================================
  // GUARDAR
  // =========================================================
  Future<void> _solicitar() async {
    setState(() => _intentado = true);
    if (_error != null) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _guardando = true;
      _errorServidor = null;
    });
    try {
      await PermisosService.crear(
        tipoPermiso: _tipo,
        unDia: _unDia,
        fechaIni: _fechaIni!,
        fechaFin: _fechaFin,
        horaIni: _horaIni,
        horaFin: _horaFin,
        categoria: _esRecuperable ? '' : _categoria,
        comentarios: _comentarios.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } on PermisosException catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _errorServidor = e.mensaje;
      });
    }
  }

  @override
  void dispose() {
    _comentarios.dispose();
    super.dispose();
  }

  // =========================================================
  // UI
  // =========================================================
  @override
  Widget build(BuildContext context) {
    final error = (_intentado ? _error : null) ?? _errorServidor;
    final formatoFecha = DateFormat("EEE d MMM yyyy", 'es_ES');

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Solicitar permiso',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),

            // Permiso / recuperable
            _Segmentos<String>(
              valor: _tipo,
              opciones: const {
                TipoPermiso.permiso: 'Permiso',
                TipoPermiso.recuperable: 'Recuperable',
              },
              onChanged: _guardando
                  ? null
                  : (v) => setState(() {
                        _tipo = v;
                        _errorServidor = null;
                      }),
            ),
            const SizedBox(height: 8),
            Text(
              _esRecuperable
                  ? 'Las horas se devuelven otro día.'
                  : 'Lactancia, visita médica, traslado y otros motivos.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            // Categoría (solo permiso normal)
            if (!_esRecuperable) ...[
              DropdownButtonFormField<String>(
                initialValue: _categoria.isEmpty ? null : _categoria,
                isExpanded: true,
                decoration: _decoracion('Tipo de permiso'),
                items: [
                  for (final c in categoriasPermiso.entries)
                    DropdownMenuItem(value: c.key, child: Text(c.value)),
                ],
                onChanged: _guardando
                    ? null
                    : (v) => setState(() {
                          _categoria = v ?? '';
                          _errorServidor = null;
                        }),
              ),
              const SizedBox(height: 16),
            ],

            // Un día / varios días
            _Segmentos<bool>(
              valor: _unDia,
              opciones: const {true: 'Un día', false: 'Varios días'},
              onChanged: _guardando
                  ? null
                  : (v) => setState(() {
                        _unDia = v;
                        _errorServidor = null;
                      }),
            ),
            const SizedBox(height: 16),

            // Fechas
            Row(
              children: [
                Expanded(
                  child: _Selector(
                    etiqueta: _unDia ? 'Día' : 'Desde',
                    valor: _fechaIni == null
                        ? null
                        : formatoFecha.format(_fechaIni!),
                    icono: Icons.event_outlined,
                    onTap: _guardando
                        ? null
                        : () => _elegirFecha(esInicio: true),
                  ),
                ),
                if (!_unDia) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Selector(
                      etiqueta: 'Hasta',
                      valor: _fechaFin == null
                          ? null
                          : formatoFecha.format(_fechaFin!),
                      icono: Icons.event_outlined,
                      onTap: _guardando
                          ? null
                          : () => _elegirFecha(esInicio: false),
                    ),
                  ),
                ],
              ],
            ),

            // Horas (solo un día)
            if (_unDia) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Selector(
                      etiqueta: 'Hora de inicio',
                      valor: _horaIni == null ? null : minutosAHora(_horaIni!),
                      icono: Icons.schedule,
                      onTap: _guardando
                          ? null
                          : () => _elegirHora(esInicio: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Selector(
                      etiqueta: 'Hora final',
                      valor: _horaFin == null ? null : minutosAHora(_horaFin!),
                      icono: Icons.schedule,
                      onTap: _guardando
                          ? null
                          : () => _elegirHora(esInicio: false),
                    ),
                  ),
                ],
              ),
              if (_horaIni != null &&
                  _horaFin != null &&
                  _horaFin! > _horaIni!)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Duración: ${minutosAHora(_horaFin! - _horaIni!)} h',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
            ],
            const SizedBox(height: 16),

            // Comentarios
            TextField(
              controller: _comentarios,
              enabled: !_guardando,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: _decoracion(
                _esRecuperable ? 'Recuperación' : 'Descripción',
              ).copyWith(
                hintText: _esRecuperable
                    ? 'Cuándo y cómo recuperarás las horas'
                    : 'Opcional',
                alignLabelWithHint: true,
              ),
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
                onPressed: _guardando ? null : _solicitar,
                child: _guardando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Solicitar permiso',
                        style: TextStyle(fontSize: 17),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoracion(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      );
}

/// Botones segmentados con los colores de la app
class _Segmentos<T> extends StatelessWidget {
  final T valor;
  final Map<T, String> opciones;
  final ValueChanged<T>? onChanged;

  const _Segmentos({
    required this.valor,
    required this.opciones,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        foregroundColor: AppColors.primary,
        selectedForegroundColor: Colors.white,
        selectedBackgroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
      ),
      segments: [
        for (final o in opciones.entries)
          ButtonSegment<T>(value: o.key, label: Text(o.value)),
      ],
      selected: {valor},
      onSelectionChanged:
          onChanged == null ? null : (s) => onChanged!(s.first),
    );
  }
}

/// Campo que abre un selector de fecha u hora
class _Selector extends StatelessWidget {
  final String etiqueta;
  final String? valor;
  final IconData icono;
  final VoidCallback? onTap;

  const _Selector({
    required this.etiqueta,
    required this.valor,
    required this.icono,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final vacio = valor == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: vacio ? Colors.grey.shade400 : AppColors.primary,
            width: vacio ? 1 : 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icono, size: 20, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    etiqueta,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    valor ?? 'Elegir',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: vacio ? FontWeight.normal : FontWeight.bold,
                      color: vacio ? Colors.grey[500] : AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
