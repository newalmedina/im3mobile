import 'package:flutter/material.dart';

import 'package:im3_mobile_app/services/vacaciones_service.dart';
import 'package:im3_mobile_app/theme/theme.dart';

import 'vacaciones_colores.dart';

/// Hoja para solicitar vacaciones o retirar una solicitud
/// (la a-modal de la web). Devuelve true si se ha enviado algo.
class SolicitudSheet extends StatefulWidget {
  const SolicitudSheet({
    super.key,
    required this.datos,
    required this.ini,
    required this.fin,
    required this.bloqueado,
    required this.tipo,
    this.dia,
    this.editarFechas = true,
  });

  final VacacionesDatos datos;
  final DateTime ini;
  final DateTime fin;

  /// true si se ha pulsado un día que ya está en una solicitud:
  /// las fechas no se pueden cambiar (tramo_bloqueado)
  final bool bloqueado;

  /// tipo_vacaciones de partida ('2' nueva, o el del tramo pulsado)
  final String tipo;

  /// Día pulsado en el calendario (para mostrar horas y festivo)
  final DateTime? dia;

  /// false -> las fechas vienen elegidas del calendario y no se cambian aquí
  final bool editarFechas;

  static Future<bool> abrir(
    BuildContext context, {
    required VacacionesDatos datos,
    required DateTime ini,
    required DateTime fin,
    bool bloqueado = false,
    String tipo = TipoVacaciones.propuesta,
    DateTime? dia,
    bool editarFechas = true,
  }) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => SolicitudSheet(
        datos: datos,
        ini: ini,
        fin: fin,
        bloqueado: bloqueado,
        tipo: tipo,
        dia: dia,
        editarFechas: editarFechas,
      ),
    );
    return r == true;
  }

  @override
  State<SolicitudSheet> createState() => _SolicitudSheetState();
}

class _SolicitudSheetState extends State<SolicitudSheet> {
  static const _diasSemana = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
  ];

  late DateTime _ini = widget.ini;
  late DateTime _fin = widget.fin;
  late String _tipo = widget.tipo;
  bool _enviando = false;
  String? _error;

  bool get _fechasEditables => !widget.bloqueado && widget.editarFechas;

  VacacionesDatos get _d => widget.datos;

  bool get _aprobada => _tipo == TipoVacaciones.aprobada && widget.bloqueado;

  /// La web pide elegir entre "borrar" y "solicitar"
  bool get _tipoValido =>
      _tipo == TipoVacaciones.propuesta || _tipo == TipoVacaciones.borrar;

  // Fechas que se pueden pedir (fechasBloqueadas de la web):
  // desde el 1 de enero de este año hasta el 31 de mayo del siguiente
  static DateTime get _primera => DateTime(VacacionesDatos.anoActual, 1, 1);
  static DateTime get _ultima => DateTime(VacacionesDatos.anoActual + 1, 5, 31);

  DateTime _ajustar(DateTime d) =>
      d.isBefore(_primera) ? _primera : (d.isAfter(_ultima) ? _ultima : d);

  Future<void> _elegirFechas() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: _primera,
      lastDate: _ultima,
      initialDateRange: DateTimeRange(
        start: _ajustar(_ini),
        end: _ajustar(_fin.isBefore(_ini) ? _ini : _fin),
      ),
      helpText: 'Fechas de vacaciones',
      saveText: 'Aceptar',
    );
    if (r == null || !mounted) return;
    setState(() {
      _ini = r.start;
      _fin = r.end;
      _error = null;
    });
  }

  Future<void> _enviar() async {
    final fechas = VacacionesDatos.diasLaborables(_ini, _fin);
    final error = _d.validar(fechas, _tipo);
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _enviando = true;
      _error = null;
    });

    final fallo = _tipo == TipoVacaciones.borrar
        ? await VacacionesService.borrarFechas(_d.idsDe(fechas))
        : await VacacionesService.crearFechas(
            _d.cuerposSolicitud(
              fechas: fechas,
              ini: _ini,
              fin: _fin,
              tipo: _tipo,
            ),
          );

    if (!mounted) return;
    if (fallo != null) {
      setState(() {
        _enviando = false;
        _error = 'No se han podido guardar $fallo.';
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final fechas = VacacionesDatos.diasLaborables(_ini, _fin);
    final diasValidos = fechas.where(_d.sinFestivo).length;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.bloqueado ? 'Tu solicitud' : 'Solicitar vacaciones',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          if (widget.dia != null) ...[
            const SizedBox(height: 6),
            _infoDia(widget.dia!),
          ],
          const SizedBox(height: 16),

          if (_aprobada)
            _aviso(
              Icons.check_circle_outline,
              'Estas vacaciones ya están aprobadas y no se pueden modificar.',
              VacColores.aprobada,
            )
          else if (widget.bloqueado) ...[
            // Qué hacer: retirar la solicitud o volver a solicitar
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.bloqueado)
                  ChoiceChip(
                    label: const Text('Retirar solicitud'),
                    selected: _tipo == TipoVacaciones.borrar,
                    onSelected: (_) => setState(() {
                      _tipo = TipoVacaciones.borrar;
                      _error = null;
                    }),
                  ),
                ChoiceChip(
                  label: const Text('Solicitar días'),
                  selected: _tipo == TipoVacaciones.propuesta,
                  onSelected: (_) => setState(() {
                    _tipo = TipoVacaciones.propuesta;
                    _error = null;
                  }),
                ),
              ],
            ),
            if (widget.bloqueado &&
                _tipo == TipoVacaciones.denegada) ...[
              const SizedBox(height: 8),
              _aviso(
                Icons.info_outline,
                'Esta solicitud fue denegada. Puedes retirarla o volver a '
                'solicitar los mismos días.',
                VacColores.denegada,
              ),
            ],
            const SizedBox(height: 16),
          ],

          // Fechas
          Text('Fechas', style: TextStyle(color: Colors.grey[700])),
          const SizedBox(height: 6),
          InkWell(
            onTap: (!_fechasEditables || _enviando) ? null : _elegirFechas,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: _fechasEditables ? Colors.white : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.date_range, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _ini == _fin
                          ? VacacionesDatos.corta(_ini)
                          : '${VacacionesDatos.corta(_ini)}  –  '
                              '${VacacionesDatos.corta(_fin)}',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                  if (_fechasEditables)
                    Icon(Icons.edit_outlined,
                        size: 18, color: Colors.grey[600]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$diasValidos ${diasValidos == 1 ? 'día laborable' : 'días laborables'}'
            ' (sin fines de semana ni festivos)',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            _aviso(Icons.error_outline, _error!, Colors.red),
          ],

          const SizedBox(height: 20),
          if (_aprobada)
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cerrar'),
            )
          else
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _tipo == TipoVacaciones.borrar
                    ? Colors.red
                    : AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: (_enviando || !_tipoValido) ? null : _enviar,
              child: _enviando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _tipo == TipoVacaciones.borrar
                          ? 'Retirar solicitud'
                          : 'Solicitar',
                    ),
            ),
        ],
      ),
    );
  }

  /// "Lunes 19/10/2026 · Horas: 8.15 · Festivo nacional"
  Widget _infoDia(DateTime dia) {
    final k = VacacionesDatos.clave(dia);
    final partes = <String>[
      '${_diasSemana[dia.weekday - 1]} ${VacacionesDatos.corta(dia)}',
    ];
    final horas = _d.horasDia(k);
    if (horas.isNotEmpty) partes.add('Horas: $horas');
    final festivo = VacColores.nombreFestivo(
      '${_d.oficina[k]?['tipo_festivo'] ?? ''}',
    );
    if (festivo != null) partes.add(festivo);
    final e = _d.usuario[k];
    if (e != null) {
      final estado =
          VacColores.nombreVacaciones('${e['tipo_vacaciones'] ?? ''}');
      if (estado != null) partes.add(estado);
    }
    return Text(
      partes.join('  ·  '),
      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
    );
  }

  Widget _aviso(IconData icono, String texto, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(texto)),
          ],
        ),
      );
}
