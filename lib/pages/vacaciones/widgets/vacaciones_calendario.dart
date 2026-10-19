import 'package:flutter/material.dart';

import 'package:im3_mobile_app/services/vacaciones_service.dart';
import 'package:im3_mobile_app/theme/theme.dart';

import 'vacaciones_colores.dart';

/// Calendario mensual (a-calendar de la web) con los festivos de la
/// oficina, las vacaciones del usuario y las bajas marcados en cada día.
/// Va desde enero de este año hasta diciembre del año siguiente.
class VacacionesCalendario extends StatelessWidget {
  const VacacionesCalendario({
    super.key,
    required this.datos,
    required this.mes,
    required this.onMes,
    required this.onDia,
    this.seleccionIni,
    this.seleccionFin,
  });

  final VacacionesDatos datos;

  /// Primer día del mes que se ve
  final DateTime mes;
  final ValueChanged<DateTime> onMes;
  final ValueChanged<DateTime> onDia;

  /// Rango que se está seleccionando (inicio y, si ya se ha pulsado, fin)
  final DateTime? seleccionIni;
  final DateTime? seleccionFin;

  static const _meses = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];
  static const _diasSemana = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  static DateTime get _min => DateTime(VacacionesDatos.anoActual, 1);
  static DateTime get _max => DateTime(VacacionesDatos.anoActual + 1, 12);

  @override
  Widget build(BuildContext context) {
    final puedeAtras = mes.isAfter(_min);
    final puedeAdelante = mes.isBefore(_max);

    final hueco = DateTime(mes.year, mes.month, 1).weekday - 1; // lunes = 0
    final diasMes = DateTime(mes.year, mes.month + 1, 0).day;
    final hoy = DateTime.now();

    return Column(
      children: [
        // Cabecera: < Octubre 2026 >
        Row(
          children: [
            IconButton(
              onPressed: puedeAtras
                  ? () => onMes(DateTime(mes.year, mes.month - 1))
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              // Pulsar el título abre el selector de mes y año
              child: Builder(
                builder: (context) => InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _elegirMes(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_meses[mes.month - 1]} ${mes.year}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_drop_down,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: puedeAdelante
                  ? () => onMes(DateTime(mes.year, mes.month + 1))
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final d in _diasSemana)
              Expanded(
                child: Text(
                  d,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.85,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            for (var i = 0; i < hueco; i++) const SizedBox.shrink(),
            for (var d = 1; d <= diasMes; d++)
              _celda(DateTime(mes.year, mes.month, d), hoy),
          ],
        ),
      ],
    );
  }

  /// Hoja para saltar directamente a un mes y año
  Future<void> _elegirMes(BuildContext context) async {
    final anos = [VacacionesDatos.anoActual, VacacionesDatos.anoActual + 1];
    final hoy = DateTime.now();
    var ano = mes.year;

    final elegido = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Años
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  for (final a in anos)
                    ChoiceChip(
                      label: Text('$a'),
                      selected: ano == a,
                      onSelected: (_) => setSheet(() => ano = a),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Meses
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  for (var m = 1; m <= 12; m++)
                    _botonMes(
                      ctx,
                      texto: _meses[m - 1].substring(0, 3),
                      activo: ano == mes.year && m == mes.month,
                      esHoy: ano == hoy.year && m == hoy.month,
                      onTap: () => Navigator.of(ctx).pop(DateTime(ano, m)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () =>
                    Navigator.of(ctx).pop(DateTime(hoy.year, hoy.month)),
                icon: const Icon(Icons.today),
                label: const Text('Ir al mes actual'),
              ),
            ],
          ),
        ),
      ),
    );
    if (elegido != null) onMes(elegido);
  }

  Widget _botonMes(
    BuildContext context, {
    required String texto,
    required bool activo,
    required bool esHoy,
    required VoidCallback onTap,
  }) {
    return Material(
      color: activo ? AppColors.primary : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: esHoy && !activo
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary, width: 1.5),
                )
              : null,
          child: Text(
            texto,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: activo ? Colors.white : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }

  Widget _celda(DateTime dia, DateTime hoy) {
    final k = VacacionesDatos.clave(dia);
    final finde = !VacacionesDatos.laborable(dia);
    final esHoy =
        dia.year == hoy.year && dia.month == hoy.month && dia.day == hoy.day;

    // Festivo de la oficina
    final festivo = '${datos.oficina[k]?['tipo_festivo'] ?? ''}';
    final colorFestivo = VacColores.festivo(festivo);

    // Vacaciones del usuario (la web solo las pinta si no es festivo)
    Color? colorVac;
    final e = datos.usuario[k];
    if (e != null && datos.sinFestivoEstricto(k)) {
      colorVac = VacColores.vacaciones('${e['tipo_vacaciones'] ?? ''}');
    }

    final baja = datos.bajasDias.containsKey(k);

    // Selección de rango
    final ini = seleccionIni;
    final fin = seleccionFin ?? seleccionIni;
    final extremo = ini != null && (dia == ini || dia == fin);
    final dentro =
        ini != null && fin != null && !dia.isBefore(ini) && !dia.isAfter(fin);

    // Fondo: lo más importante del día
    final fondo = colorVac ?? (baja ? VacColores.baja : colorFestivo);

    final puntos = <Color>[
      if (colorFestivo != null) colorFestivo,
      if (colorVac != null) colorVac,
      if (baja) VacColores.baja,
    ];

    final Color colorCelda;
    if (extremo) {
      colorCelda = AppColors.primary;
    } else if (dentro) {
      colorCelda = AppColors.primary.withValues(alpha: 0.18);
    } else {
      colorCelda =
          fondo?.withValues(alpha: 0.15) ??
          (finde ? Colors.grey.shade100 : Colors.transparent);
    }

    return Material(
      color: colorCelda,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onDia(dia),
        child: Container(
          decoration: esHoy
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary, width: 1.5),
                )
              : null,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${dia.day}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: esHoy ? FontWeight.bold : FontWeight.w500,
                  color: extremo
                      ? Colors.white
                      : (finde ? Colors.grey[500] : AppColors.text),
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final c in puntos)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
