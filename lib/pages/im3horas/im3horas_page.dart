import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../layouts/main_layout.dart';
import '../../services/horas_service.dart';
import '../../services/plantillas_service.dart';
import '../../theme/theme.dart';
import '../../utils/horas_reglas.dart';
import '../../widgets/snackbar_helper.dart';
import 'plantilla_dialog.dart';
import 'turno_sheet.dart';

/// Colores y nombres de cada tipo de día (leyenda de calendario.html).
/// Ajusta los colores a los de css/custom.css si quieres que sean idénticos.
class TipoDia {
  final String clave;
  final String nombre;
  final Color color;
  const TipoDia(this.clave, this.nombre, this.color);

  /// En el mismo orden de prioridad que pintarDia() en calendario.js
  static const List<TipoDia> todos = [
    TipoDia('laboral', 'Día con datos', AppColors.secondary),
    TipoDia('BAJ', 'Baja', AppColors.danger),
    TipoDia('FES', 'Festivo', AppColors.info),
    TipoDia('PER', 'Permiso', Color(0xFFF59E0B)),
    TipoDia('VAC', 'Vacaciones', Color(0xFF14B8A6)),
  ];

  static TipoDia? de(Set<String>? tipos) {
    if (tipos == null) return null;
    for (final t in todos) {
      if (tipos.contains(t.clave)) return t;
    }
    return null;
  }

  static Color colorEvento(String tipo) =>
      todos.where((t) => t.clave == tipo).firstOrNull?.color ?? Colors.grey;
}

class Im3HorasPage extends StatefulWidget {
  const Im3HorasPage({super.key});

  @override
  State<Im3HorasPage> createState() => _Im3HorasPageState();
}

class _Im3HorasPageState extends State<Im3HorasPage> {
  final DateTime _hoy = soloFecha(DateTime.now());
  late DateTime _mesVisible = _hoy;
  late DateTime _seleccionado = _hoy;

  Map<String, Set<String>> _tiposMes = {};
  List<Map<String, dynamic>> _turnos = [];
  List<Map<String, dynamic>> _eventos = [];
  bool _cargandoDia = true;
  String? _errorDia;

  /// Para descartar respuestas viejas si se cambia de día rápido
  int _peticionDia = 0;

  @override
  void initState() {
    super.initState();
    _cargarMes(_mesVisible);
    _cargarDia(_seleccionado);
  }

  // =========================================================
  // DATOS
  // =========================================================
  Future<void> _cargarMes(DateTime mes) async {
    try {
      final tipos = await HorasService.getMes(mes);
      if (!mounted || mesYear(mes) != mesYear(_mesVisible)) return;
      setState(() => _tiposMes = tipos);
    } catch (e) {
      _aviso(e is HorasException ? e.mensaje : 'Error al cargar el mes.');
    }
  }

  Future<void> _cargarDia(DateTime dia) async {
    final peticion = ++_peticionDia;
    setState(() {
      _cargandoDia = true;
      _errorDia = null;
    });
    try {
      final r = await Future.wait([
        HorasService.getTurnos(dia),
        HorasService.getEventos(dia),
      ]);
      if (!mounted || peticion != _peticionDia) return;
      setState(() {
        _turnos = r[0];
        _eventos = r[1];
        _cargandoDia = false;
      });
    } catch (e) {
      // Cualquier error (no solo HorasException) quita el "cargando"
      if (!mounted || peticion != _peticionDia) return;
      setState(() {
        _turnos = [];
        _eventos = [];
        _cargandoDia = false;
        _errorDia = e is HorasException ? e.mensaje : 'Error al cargar el día.';
      });
    }
  }

  Future<void> _recargar() =>
      Future.wait([_cargarMes(_mesVisible), _cargarDia(_seleccionado)]);

  // =========================================================
  // CÁLCULOS DEL DÍA SELECCIONADO
  // =========================================================
  int get _limite => HorasReglas.limiteMinutos(_seleccionado);
  int get _usados => sumaMinutos(_turnos, _eventos);
  bool get _bloqueado => diaBloqueado(_eventos);
  bool get _laborable => HorasReglas.esLaborable(_seleccionado);
  bool get _editable => _laborable && !_bloqueado && !_cargandoDia;

  String? _validar(int inicio, int fin, {String? editandoId}) =>
      HorasReglas.validar(
        dia: _seleccionado,
        inicio: inicio,
        fin: fin,
        turnos: _turnos,
        eventos: _eventos,
        editandoId: editandoId,
      );

  // =========================================================
  // ACCIONES
  // =========================================================
  void _seleccionar(DateTime dia) {
    final d = soloFecha(dia);
    if (isSameDay(d, _seleccionado)) return;
    final cambiaMes = mesYear(d) != mesYear(_mesVisible);
    setState(() {
      _seleccionado = d;
      if (cambiaMes) _mesVisible = d;
    });
    if (cambiaMes) _cargarMes(d);
    _cargarDia(d);
  }

  void _irAHoy() {
    final cambiaMes = mesYear(_mesVisible) != mesYear(_hoy);
    setState(() {
      _mesVisible = _hoy;
      _seleccionado = _hoy;
    });
    if (cambiaMes) _cargarMes(_hoy);
    _cargarDia(_hoy);
  }

  /// Selector rápido de mes y año (al tocar el título del calendario)
  Future<void> _elegirMes() async {
    final elegido = await showDialog<DateTime>(
      context: context,
      builder: (_) => _SelectorMes(
        actual: _mesVisible,
        hoy: _hoy,
        primero: DateTime(2020, 1),
        ultimo: DateTime(_hoy.year + 1, 12),
      ),
    );
    if (elegido == null || mesYear(elegido) == mesYear(_mesVisible)) return;
    setState(() => _mesVisible = elegido);
    _cargarMes(elegido);
  }

  Future<void> _nuevoTurno() async {
    // Propuesta: empieza donde acabó el último turno (o a las 08:00)
    final inicio = _turnos.isEmpty
        ? 8 * 60
        : (_turnos.last['fin'] as int).clamp(
            HorasReglas.horaMinima,
            HorasReglas.horaMaxima,
          );
    final restante = (_limite - _usados).clamp(0, 24 * 60);
    final fin = (inicio + restante).clamp(inicio, HorasReglas.horaMaxima);

    final ok = await TurnoSheet.abrir(
      context,
      TurnoSheet(
        titulo: 'Nuevo turno',
        textoBoton: 'Crear turno',
        inicio: inicio,
        fin: fin,
        validar: (i, f) => _validar(i, f),
        onGuardar: (i, f) =>
            _guardar(() => HorasService.crear(_seleccionado, i, f)),
      ),
    );
    if (ok) _hecho('Turno creado');
  }

  /// Botón "Generar plantilla": abre el diálogo y crea los turnos elegidos
  Future<void> _generarPlantilla() async {
    final dia = _seleccionado;
    // Las del usuario o, si no ha guardado ninguna, las de por defecto
    final plantillas = await PlantillasService.cargar();
    if (!mounted) return;
    final existentes = [..._turnos];
    final resultado = await showDialog<PlantillaResultado>(
      context: context,
      builder: (_) => PlantillaDialog(
        dia: dia,
        plantillas: plantillas,
        turnosDelDia: [
          for (final t in existentes) [t['inicio'] as int, t['fin'] as int],
        ],
        validar: (sel, reemplazar) => HorasReglas.validarVarios(
          dia: dia,
          nuevos: sel,
          // Los turnos del día se sustituyen, así que no cuentan
          turnos: reemplazar ? <Map<String, dynamic>>[] : existentes,
          eventos: _eventos,
        ),
      ),
    );
    if (resultado == null || resultado.seleccion.isEmpty || !mounted) return;

    bool igual(Map<String, dynamic> t, List<int> s) =>
        t['inicio'] == s[0] && t['fin'] == s[1];

    // Normal y verano no se mezclan: se quitan los turnos del día que no
    // estén en la selección y se crean los que falten. Los iguales se dejan.
    final borrar = [
      for (final t in existentes)
        if (!resultado.seleccion.any((s) => igual(t, s))) t,
    ];
    final crear = [
      for (final s in resultado.seleccion)
        if (!existentes.any((t) => igual(t, s))) s,
    ];
    if (borrar.isEmpty && crear.isEmpty) {
      _hecho('El día ya tenía ese horario');
      return;
    }

    setState(() => _cargandoDia = true);

    for (final t in borrar) {
      final error = await _guardar(() => HorasService.eliminar('${t['id']}'));
      if (error != null) {
        if (!mounted) return;
        _aviso('No se pudo sustituir el turno: $error');
        _recargar();
        return;
      }
    }

    var creados = 0;
    for (final t in crear) {
      final error = await _guardar(() => HorasService.crear(dia, t[0], t[1]));
      if (error != null) {
        if (!mounted) return;
        _aviso(
          creados == 0
              ? error
              : 'Se crearon $creados de ${crear.length} turnos. $error',
        );
        _recargar();
        return;
      }
      creados++;
    }
    _hecho(borrar.isEmpty ? (creados == 1 ? 'Turno creado' : '$creados turnos creados') : 'Horario sustituido');
  }

  Future<void> _editarTurno(Map<String, dynamic> t) async {
    final id = '${t['id']}';
    if (!_editable) return;
    final ok = await TurnoSheet.abrir(
      context,
      TurnoSheet(
        titulo: 'Editar turno',
        textoBoton: 'Guardar cambios',
        inicio: t['inicio'],
        fin: t['fin'],
        validar: (i, f) => _validar(i, f, editandoId: id),
        onGuardar: (i, f) => _guardar(() => HorasService.actualizar(id, i, f)),
      ),
    );
    if (ok) _hecho('Turno actualizado');
  }

  Future<void> _eliminarTurno(Map<String, dynamic> t) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar turno'),
        content: Text(
          'Vas a eliminar el turno de ${minutosAHora(t['inicio'])} a ${minutosAHora(t['fin'])}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    final error = await _guardar(() => HorasService.eliminar('${t['id']}'));
    if (error == null) {
      _hecho('Turno eliminado');
    } else {
      _aviso(error);
    }
  }

  /// Ejecuta la llamada y devuelve null si fue bien o el mensaje de error
  Future<String?> _guardar(Future<void> Function() llamada) async {
    try {
      await llamada();
      return null;
    } on HorasException catch (e) {
      return e.mensaje;
    } catch (e) {
      return 'Error inesperado: $e';
    }
  }

  void _hecho(String mensaje) {
    if (!mounted) return;
    SnackbarHelper.show(
      context,
      message: mensaje,
      backgroundColor: AppColors.success,
    );
    _recargar();
  }

  void _aviso(String mensaje) {
    if (!mounted) return;
    SnackbarHelper.show(
      context,
      message: mensaje,
      backgroundColor: AppColors.danger,
    );
  }

  // =========================================================
  // UI
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return MainLayout(
      currentRoute: 'im3horas',
      child: RefreshIndicator(
        onRefresh: _recargar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _calendario(),
            const SizedBox(height: 8),
            _leyenda(),
            const Divider(height: 32),
            _cabeceraDia(),
            const SizedBox(height: 16),
            ..._contenidoDia(),
          ],
        ),
      ),
    );
  }

  // ---------------- CALENDARIO ----------------
  Widget _calendario() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          TableCalendar(
            locale: 'es_ES',
            firstDay: DateTime(2020, 1, 1),
            lastDay: DateTime(_hoy.year + 1, 12, 31),
            focusedDay: _mesVisible,
            startingDayOfWeek: StartingDayOfWeek.monday,
            availableCalendarFormats: const {CalendarFormat.month: 'Mes'},
            availableGestures: AvailableGestures.horizontalSwipe,
            rowHeight: 46,
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextFormatter: (date, locale) {
                final t = DateFormat.yMMMM(locale).format(date);
                return '${t[0].toUpperCase()}${t.substring(1)} ▾';
              },
              titleTextStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
              leftChevronIcon: const Icon(
                Icons.chevron_left,
                color: AppColors.primary,
              ),
              rightChevronIcon: const Icon(
                Icons.chevron_right,
                color: AppColors.primary,
              ),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: Colors.grey[700], fontSize: 12),
              weekendStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            enabledDayPredicate: HorasReglas.esLaborable,
            selectedDayPredicate: (d) => isSameDay(d, _seleccionado),
            onDaySelected: (dia, _) => _seleccionar(dia),
            onHeaderTapped: (_) => _elegirMes(),
            onPageChanged: (mes) {
              _mesVisible = mes;
              _cargarMes(mes);
            },
            calendarBuilders: CalendarBuilders(
              prioritizedBuilder: (context, dia, mes) => _celda(dia, mes),
            ),
          ),
          if (!isSameDay(_seleccionado, _hoy) ||
              mesYear(_mesVisible) != mesYear(_hoy))
            TextButton.icon(
              onPressed: _irAHoy,
              icon: const Icon(Icons.today, size: 18),
              label: const Text('Volver a hoy'),
            ),
        ],
      ),
    );
  }

  Widget _celda(DateTime dia, DateTime mesFoco) {
    final fuera = dia.month != mesFoco.month;
    final finde = !HorasReglas.esLaborable(dia);
    final esHoy = isSameDay(dia, _hoy);
    final seleccionado = isSameDay(dia, _seleccionado);
    final tipo = fuera ? null : TipoDia.de(_tiposMes[fechaIso(dia)]);

    Color? fondo;
    Color texto = AppColors.text;
    if (esHoy && !fuera) {
      fondo = AppColors.primary;
      texto = Colors.white;
    } else if (tipo != null) {
      fondo = tipo.color;
      texto = Colors.white;
    } else if (fuera || finde) {
      texto = Colors.grey.shade400;
    }

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(10),
          border: seleccionado
              ? Border.all(
                  color: esHoy || tipo != null
                      ? AppColors.text
                      : AppColors.primary,
                  width: 2.5,
                )
              : null,
        ),
        child: Text(
          '${dia.day}',
          style: TextStyle(
            color: texto,
            fontWeight: esHoy || seleccionado
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _leyenda() {
    Widget item(Color c, String t, {bool borde = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: borde ? null : c,
            borderRadius: BorderRadius.circular(4),
            border: borde ? Border.all(color: c, width: 2) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(t, style: TextStyle(fontSize: 12, color: Colors.grey[800])),
      ],
    );

    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        for (final t in TipoDia.todos) item(t.color, t.nombre),
        item(AppColors.primary, 'Hoy'),
        item(AppColors.primary, 'Seleccionado', borde: true),
      ],
    );
  }

  // ---------------- DÍA SELECCIONADO ----------------
  Widget _cabeceraDia() {
    final titulo = DateFormat(
      "EEEE, d 'de' MMMM",
      'es_ES',
    ).format(_seleccionado);
    final progreso = _limite == 0 ? 0.0 : (_usados / _limite).clamp(0.0, 1.0);
    final completo = _usados >= _limite;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo[0].toUpperCase() + titulo.substring(1),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        if (_laborable) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                minutosAHora(_usados),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 6),
                child: Text(
                  'de ${minutosAHora(_limite)} h',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              color: completo ? AppColors.secondary : AppColors.primary,
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _contenidoDia() {
    if (_cargandoDia) {
      return const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      ];
    }

    if (_errorDia != null) {
      return [
        _banner(Icons.cloud_off, _errorDia!, AppColors.danger),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _cargarDia(_seleccionado),
          child: const Text('Reintentar'),
        ),
      ];
    }

    final restante = _limite - _usados;

    return [
      if (!_laborable)
        _banner(
          Icons.weekend_outlined,
          'Los fines de semana no se fichan.',
          Colors.grey,
        )
      else if (_bloqueado)
        _banner(
          Icons.lock_outline,
          'Este día está bloqueado y no se puede modificar.',
          AppColors.warning,
        ),

      // Turnos
      if (_turnos.isNotEmpty) ...[
        const _Titulo('Turnos trabajados'),
        for (final t in _turnos) _turnoTile(t),
        const SizedBox(height: 8),
      ],

      if (_editable) ...[
        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _generarPlantilla,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text(
              'Generar plantilla',
              style: TextStyle(fontSize: 17),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: restante > 0 ? _nuevoTurno : null,
            icon: const Icon(Icons.add),
            label: Text(
              restante > 0 ? 'Añadir turno' : 'Día completo',
              style: const TextStyle(fontSize: 17),
            ),
          ),
        ),
      ],

      if (_laborable && _turnos.isEmpty && _eventos.isEmpty && _editable)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            'No hay nada registrado este día. Añade tu primer turno.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),

      // Eventos
      if (_eventos.isNotEmpty) ...[
        const SizedBox(height: 16),
        const _Titulo('Eventos'),
        for (final e in _eventos) _eventoCard(e),
      ],
    ];
  }

  Widget _turnoTile(Map<String, dynamic> t) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        onTap: _editable ? () => _editarTurno(t) : null,
        leading: const Icon(Icons.schedule, color: AppColors.primary),
        title: Text(
          '${minutosAHora(t['inicio'])} – ${minutosAHora(t['fin'])}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text('${minutosAHora(t['minutos'])} h'),
        trailing: _editable
            ? IconButton(
                tooltip: 'Eliminar turno',
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                onPressed: () => _eliminarTurno(t),
              )
            : null,
      ),
    );
  }

  Widget _eventoCard(Map<String, dynamic> e) {
    final color = TipoDia.colorEvento('${e['tipo_evento']}');
    final nombre = texto(e['tipo_evento_nombre']) ?? 'Evento';
    final total = texto(e['suma_minutos_formatted']);
    final desde = texto(e['fecha_inicio_format']);
    final hasta = texto(e['fecha_fin_format']);
    final fechas = [
      if (desde != null) 'Desde $desde',
      if (hasta != null) 'hasta $hasta',
    ].join(' ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nombre,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          if (total != null) ...[
            const SizedBox(height: 4),
            Text('Total: $total h'),
          ],
          if (fechas.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              fechas,
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _banner(IconData icono, String texto, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icono, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  final String texto;
  const _Titulo(this.texto);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      texto,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.grey[800],
      ),
    ),
  );
}

/// Diálogo para elegir mes y año de un vistazo.
class _SelectorMes extends StatefulWidget {
  final DateTime actual;
  final DateTime hoy;
  final DateTime primero;
  final DateTime ultimo;

  const _SelectorMes({
    required this.actual,
    required this.hoy,
    required this.primero,
    required this.ultimo,
  });

  @override
  State<_SelectorMes> createState() => _SelectorMesState();
}

class _SelectorMesState extends State<_SelectorMes> {
  static const _meses = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  late int _anio = widget.actual.year;

  bool _permitido(int mes) {
    final d = DateTime(_anio, mes);
    return !d.isBefore(DateTime(widget.primero.year, widget.primero.month)) &&
        !d.isAfter(DateTime(widget.ultimo.year, widget.ultimo.month));
  }

  @override
  Widget build(BuildContext context) {
    final anios = [
      for (var a = widget.primero.year; a <= widget.ultimo.year; a++) a,
    ];

    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Año: flechas + desplegable
            Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.chevron_left,
                    color: AppColors.primary,
                  ),
                  onPressed: _anio > widget.primero.year
                      ? () => setState(() => _anio--)
                      : null,
                ),
                Expanded(
                  child: Center(
                    child: DropdownButton<int>(
                      value: _anio,
                      underline: const SizedBox.shrink(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                      items: [
                        for (final a in anios)
                          DropdownMenuItem(value: a, child: Text('$a')),
                      ],
                      onChanged: (a) => setState(() => _anio = a ?? _anio),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.chevron_right,
                    color: AppColors.primary,
                  ),
                  onPressed: _anio < widget.ultimo.year
                      ? () => setState(() => _anio++)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Meses en rejilla 3 x 4
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [for (var m = 1; m <= 12; m++) _botonMes(m)],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }

  Widget _botonMes(int mes) {
    final elegido = _anio == widget.actual.year && mes == widget.actual.month;
    final esMesHoy = _anio == widget.hoy.year && mes == widget.hoy.month;
    final activo = _permitido(mes);

    return Material(
      color: elegido ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: activo
            ? () => Navigator.pop(context, DateTime(_anio, mes))
            : null,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: esMesHoy && !elegido
                ? Border.all(color: AppColors.primary, width: 1.5)
                : null,
          ),
          child: Text(
            _meses[mes - 1],
            style: TextStyle(
              fontWeight: elegido || esMesHoy
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: elegido
                  ? Colors.white
                  : activo
                  ? AppColors.text
                  : Colors.grey.shade400,
            ),
          ),
        ),
      ),
    );
  }
}
