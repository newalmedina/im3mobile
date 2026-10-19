import 'package:flutter/material.dart';

import 'package:im3_mobile_app/layouts/main_layout.dart';
import 'package:im3_mobile_app/services/vacaciones_service.dart';
import 'package:im3_mobile_app/theme/theme.dart';

import 'widgets/solicitud_sheet.dart';
import 'widgets/vacaciones_calendario.dart';
import 'widgets/vacaciones_colores.dart';

/// Vacaciones (punto de menú). Equivale a pages/calendario.vue de la web.
/// Dividida en 3 pestañas:
///   1. Calendario (por defecto): se elige inicio y fin pulsando días
///      y desde ahí se solicitan las vacaciones
///   2. Vacaciones: solo consulta (resumen de días y solicitudes por año)
///   3. Bajas: listado de bajas (sin filtro, como la web)
class VacacionesPage extends StatefulWidget {
  const VacacionesPage({super.key});

  @override
  State<VacacionesPage> createState() => _VacacionesPageState();
}

class _VacacionesPageState extends State<VacacionesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  VacacionesDatos? _datos;
  bool _cargando = true;
  bool _refrescando = false;
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);
  int? _anoTabla;

  // Rango elegido en el calendario
  DateTime? _selIni;
  DateTime? _selFin;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final d = await VacacionesService.cargar();
    if (!mounted) return;
    setState(() {
      _datos = d;
      _cargando = false;
      final anos = d?.anosTramos ?? const <int>[];
      if (_anoTabla == null || !anos.contains(_anoTabla)) {
        _anoTabla = anos.isNotEmpty ? anos.first : null;
      }
    });
  }

  /// Botón de refrescar
  Future<void> _refrescar() async {
    if (_refrescando) return;
    setState(() => _refrescando = true);
    await _cargar();
    if (!mounted) return;
    setState(() => _refrescando = false);
    _aviso('Datos actualizados');
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _abrirSolicitud({
    required DateTime ini,
    required DateTime fin,
    bool bloqueado = false,
    String tipo = TipoVacaciones.propuesta,
    DateTime? dia,
  }) async {
    final d = _datos;
    if (d == null) return;
    final enviado = await SolicitudSheet.abrir(
      context,
      datos: d,
      ini: ini,
      fin: fin,
      bloqueado: bloqueado,
      tipo: tipo,
      dia: dia,
    );
    if (!enviado || !mounted) return;
    _aviso('Fechas actualizadas');
    await _cargar();
  }

  // Fechas que se pueden pedir (fechasBloqueadas de la web)
  static DateTime get _primera => DateTime(VacacionesDatos.anoActual, 1, 1);
  static DateTime get _ultima => DateTime(VacacionesDatos.anoActual + 1, 5, 31);

  /// Pulsar un día del calendario:
  ///   - sin selección y con solicitud -> abre esa solicitud
  ///   - si no -> 1er toque = inicio, 2º toque = fin
  void _onDia(DateTime dia) {
    final d = _datos;
    if (d == null) return;
    final k = VacacionesDatos.clave(dia);

    if (d.bajasDias.containsKey(k)) {
      _aviso('No se pueden seleccionar días de baja.');
      return;
    }
    if (!VacacionesDatos.laborable(dia)) {
      _aviso('No se pueden seleccionar fines de semana.');
      return;
    }

    final e = d.usuario[k];
    if (_selIni == null && e != null) {
      _abrirSolicitud(
        ini: VacacionesDatos.fecha(e['tramo_fecha_ini']) ?? dia,
        fin: VacacionesDatos.fecha(e['tramo_fecha_fin']) ?? dia,
        bloqueado: true,
        tipo: '${e['tipo_vacaciones'] ?? TipoVacaciones.propuesta}',
        dia: dia,
      );
      return;
    }

    if (dia.isBefore(_primera) || dia.isAfter(_ultima)) {
      _aviso(
        'Solo se pueden solicitar fechas hasta el '
        '${VacacionesDatos.corta(_ultima)}.',
      );
      return;
    }

    setState(() {
      if (_selIni == null || _selFin != null) {
        // Empieza una selección nueva
        _selIni = dia;
        _selFin = null;
      } else if (dia.isBefore(_selIni!)) {
        _selFin = _selIni;
        _selIni = dia;
      } else {
        _selFin = dia;
      }
    });
  }

  void _limpiarSeleccion() => setState(() {
    _selIni = null;
    _selFin = null;
  });

  /// Botón "Solicitar" del rango elegido
  Future<void> _solicitarSeleccion() async {
    final ini = _selIni;
    if (ini == null) return;
    final fin = _selFin ?? ini;
    final d = _datos;
    if (d == null) return;

    final enviado = await SolicitudSheet.abrir(
      context,
      datos: d,
      ini: ini,
      fin: fin,
      editarFechas: false,
    );
    if (!enviado || !mounted) return;
    _limpiarSeleccion();
    _aviso('Vacaciones solicitadas');
    await _cargar();
  }

  // ---------------------------------------------------------------- vista
  @override
  Widget build(BuildContext context) {
    return MainLayout(
      currentRoute: 'vacaciones',
      child: Container(
        color: Colors.grey.shade100,
        child: Column(
          children: [
            Material(
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TabBar(
                      controller: _tabs,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: Colors.grey[600],
                      indicatorColor: AppColors.primary,
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.calendar_month_outlined),
                          text: 'Calendario',
                        ),
                        Tab(
                          icon: Icon(Icons.beach_access_outlined),
                          text: 'Vacaciones',
                        ),
                        Tab(icon: Icon(Icons.healing_outlined), text: 'Bajas'),
                      ],
                    ),
                  ),
                  // Refrescar
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _refrescando
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        : IconButton(
                            tooltip: 'Refrescar',
                            onPressed: _cargando ? null : _refrescar,
                            icon: const Icon(
                              Icons.refresh,
                              color: AppColors.primary,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _pestana(_tabCalendario),
                  _pestana(_tabVacaciones),
                  _pestana(_tabBajas),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Envoltorio común: loader, error de usuario y tirar para refrescar
  Widget _pestana(List<Widget> Function(VacacionesDatos d) contenido) {
    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    final d = _datos;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _cargar,
      child: d == null
          ? _mensaje(
              'No se ha podido identificar tu usuario. '
              'Cierra sesión y vuelve a entrar.',
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: contenido(d),
            ),
    );
  }

  bool _conCalendario(VacacionesDatos d) => d.tieneCalendario && d.publicado;

  Widget _sinCalendario() => _tarjeta(
    child: Text(
      'No tienes un calendario publicado para este año.',
      style: TextStyle(color: Colors.grey[700]),
    ),
  );

  // 2. Vacaciones: solo consulta (resumen + solicitudes por año)
  List<Widget> _tabVacaciones(VacacionesDatos d) => [
    _resumen(d),
    const SizedBox(height: 16),
    _solicitudes(d),
  ];

  // 1. Calendario (con selección de rango)
  List<Widget> _tabCalendario(VacacionesDatos d) => [
    // Resumen de días (el mismo que en la pestaña Vacaciones)
    _resumen(d),
    const SizedBox(height: 16),
    if (!_conCalendario(d))
      _sinCalendario()
    else
      _tarjeta(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (d.descripcion.isNotEmpty) ...[
              Text(
                d.descripcion,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              _selIni == null
                  ? 'Pulsa el día de inicio y luego el de fin para '
                        'solicitar vacaciones. Pulsa un día ya solicitado '
                        'para ver o retirar esa solicitud.'
                  : _selFin == null
                  ? 'Ahora pulsa el día de fin (o solicita solo este día).'
                  : 'Pulsa otro día para empezar una selección nueva.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            VacacionesCalendario(
              datos: d,
              mes: _mes,
              onMes: (m) => setState(() => _mes = m),
              onDia: _onDia,
              seleccionIni: _selIni,
              seleccionFin: _selFin,
            ),
            if (_selIni != null) ...[
              const SizedBox(height: 12),
              _panelSeleccion(d),
            ],
            const SizedBox(height: 12),
            _leyendaColores(),
          ],
        ),
      ),
  ];

  /// Inicio, fin, días y botones Cancelar / Solicitar
  Widget _panelSeleccion(VacacionesDatos d) {
    final ini = _selIni!;
    final fin = _selFin ?? ini;
    final dias = VacacionesDatos.diasLaborables(
      ini,
      fin,
    ).where(d.sinFestivo).length;

    Widget fecha(String titulo, DateTime? f) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 2),
          Text(
            f == null ? '—' : VacacionesDatos.corta(f),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              fecha('Inicio', _selIni),
              fecha('Fin', _selFin ?? _selIni),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Días',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$dias',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _limpiarSeleccion,
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _solicitarSeleccion,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('Solicitar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 3. Bajas
  List<Widget> _tabBajas(VacacionesDatos d) => [_bajas(d)];

  // ------------------------------------------------- resumen de días
  Widget _resumen(VacacionesDatos d) {
    final n = VacacionesDatos.numero;
    final List<Widget> filas;

    if (d.esChile || d.esBrasil) {
      filas = [
        _dato('Vacaciones acumuladas', n(d.acumuladas), Colors.grey),
        _dato('Vacaciones disfrutadas', n(d.disfrutadas), Colors.grey),
        _dato(
          'Días disponibles',
          n(d.esBrasil ? d.disponiblesBrasil : d.disponiblesChile),
          Colors.grey,
          destacado: true,
        ),
        _dato('Días solicitados', '${d.propuestasChile}', VacColores.propuesta),
      ];
    } else {
      filas = [
        _dato('Días de vacaciones', n(d.diasVacaciones), Colors.grey),
        _dato('Días pendientes', n(d.diasPendientes), Colors.grey),
        _dato(
          'Total vacaciones',
          n(d.totalVacaciones),
          Colors.grey,
          destacado: true,
        ),
        const Divider(height: 20),
        _dato('Días solicitados', '${d.propuestas}', VacColores.propuesta),
        _dato('Días aprobados', '${d.aprobadas}', VacColores.aprobada),
        if (d.pagadas != 0)
          _dato('Días pagados', '${d.pagadas}', VacColores.pagada),
        _dato(
          'Días disponibles',
          n(d.disponibles),
          Colors.grey,
          destacado: true,
        ),
      ];
    }

    return _tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Mis vacaciones',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 10),
          ...filas,
        ],
      ),
    );
  }

  Widget _dato(
    String texto,
    String valor,
    Color color, {
    bool destacado = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 14,
                fontWeight: destacado ? FontWeight.w600 : FontWeight.normal,
                color: AppColors.text,
              ),
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: destacado ? 16 : 14,
              fontWeight: FontWeight.bold,
              color: destacado ? AppColors.primary : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _leyendaColores() {
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: const [
        VacPunto(color: VacColores.propuesta, texto: 'Propuestas'),
        VacPunto(color: VacColores.aprobada, texto: 'Aprobadas'),
        VacPunto(color: VacColores.denegada, texto: 'Denegadas'),
        VacPunto(color: VacColores.baja, texto: 'Baja'),
        VacPunto(color: VacColores.festivoLocal, texto: 'Festivo local'),
        VacPunto(
          color: VacColores.festivoAutonomico,
          texto: 'Festivo autonómico',
        ),
        VacPunto(color: VacColores.festivoNacional, texto: 'Festivo nacional'),
        VacPunto(
          color: VacColores.festivoConvenio,
          texto: 'Festivo de convenio',
        ),
      ],
    );
  }

  // ------------------------------------------------ tabla de solicitudes
  Widget _solicitudes(VacacionesDatos d) {
    final anos = d.anosTramos;
    final ano = _anoTabla;
    final lista = ano == null
        ? const <Map<String, dynamic>>[]
        : d.tramosDelAno(ano);

    return _tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Solicitudes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text,
                  ),
                ),
              ),
              if (anos.isNotEmpty)
                DropdownButton<int>(
                  value: ano,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final a in anos)
                      DropdownMenuItem(value: a, child: Text('$a')),
                  ],
                  onChanged: (a) => setState(() => _anoTabla = a),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (lista.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No hay solicitudes.',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          else
            for (var i = 0; i < lista.length; i++)
              _filaTramo(d, lista[i], ultimo: i == lista.length - 1),
        ],
      ),
    );
  }

  Widget _filaTramo(
    VacacionesDatos d,
    Map<String, dynamic> t, {
    required bool ultimo,
  }) {
    final tipo = '${t['tipo_vacaciones'] ?? ''}';
    final color = VacColores.vacaciones(tipo) ?? Colors.grey;
    final estado = VacColores.nombreVacaciones(tipo) ?? '';
    final dias = d.diasTramo(t['tramo_fecha_ini'], t['tramo_fecha_fin']);
    final anoSolicitud = '${t['ano_solicitud'] ?? ''}';

    return InkWell(
      onTap: () {
        final ini = VacacionesDatos.fecha(t['tramo_fecha_ini']);
        if (ini == null) return;
        setState(() => _mes = DateTime(ini.year, ini.month));
        _tabs.animateTo(0);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: ultimo
              ? null
              : Border(bottom: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    VacacionesDatos.rango(
                      t['tramo_fecha_ini'],
                      t['tramo_fecha_fin'],
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Año solicitud: $anoSolicitud  ·  '
                    '$dias ${dias == 1 ? 'día' : 'días'}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                estado.replaceFirst('Vacaciones ', ''),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            // Solo las propuestas se pueden eliminar
            if (tipo == TipoVacaciones.propuesta)
              IconButton(
                tooltip: 'Eliminar solicitud',
                visualDensity: VisualDensity.compact,
                onPressed: () => _eliminarTramo(d, t),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }

  /// Eliminar una solicitud propuesta (borra todos sus días)
  Future<void> _eliminarTramo(VacacionesDatos d, Map<String, dynamic> t) async {
    final ini = VacacionesDatos.fecha(t['tramo_fecha_ini']);
    final fin = VacacionesDatos.fecha(t['tramo_fecha_fin']) ?? ini;
    if (ini == null || fin == null) return;

    // Solo los días de este tramo que siguen como propuestos
    final fechas = VacacionesDatos.diasLaborables(ini, fin)
        .where(
          (f) =>
              '${d.usuario[f]?['tipo_vacaciones'] ?? ''}' ==
              TipoVacaciones.propuesta,
        )
        .toList();
    final ids = d.idsDe(fechas);
    if (ids.isEmpty) {
      _aviso('No se han encontrado días para eliminar.');
      return;
    }

    final rango = VacacionesDatos.rango(
      t['tramo_fecha_ini'],
      t['tramo_fecha_fin'],
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar solicitud'),
        content: Text('¿Quieres eliminar la solicitud de vacaciones $rango?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final fallo = await VacacionesService.borrarFechas(ids);
    if (!mounted) return;
    if (fallo != null) {
      _aviso('No se han podido eliminar $fallo.');
    } else {
      _aviso('Solicitud eliminada');
    }
    await _cargar();
  }

  // --------------------------------------------------------------- bajas
  Widget _bajas(VacacionesDatos d) {
    final lista = d.bajasTramos;
    return _tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Bajas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          if (lista.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No tienes bajas.',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          else
            for (final b in lista)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.healing_outlined,
                      color: VacColores.baja,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        VacacionesDatos.rango(b['fecha_ini'], b['fecha_fin']),
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    Text(
                      _estadoBaja('${b['estado'] ?? ''}'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  static String _estadoBaja(String e) => switch (e) {
    'activa' => 'Activa',
    'finalizada' => 'Finalizada',
    _ => e,
  };

  // --------------------------------------------------------------- ayudas
  Widget _tarjeta({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );

  Widget _mensaje(String texto) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      SizedBox(
        height: 300,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              texto,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ),
      ),
    ],
  );
}
