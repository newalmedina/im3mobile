import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../layouts/main_layout.dart';
import '../../services/permisos_service.dart';
import '../../theme/theme.dart';
import '../../utils/horas_reglas.dart';
import '../../widgets/snackbar_helper.dart';
import 'permiso_detalle_sheet.dart';
import 'permiso_form_sheet.dart';
import 'permisos_catalogo.dart';

/// Mis permisos: ver el estado de los que he pedido, pedir uno nuevo,
/// editar los "Presentado", adjuntar justificante y eliminar.
class PermisosPage extends StatefulWidget {
  const PermisosPage({super.key});

  @override
  State<PermisosPage> createState() => _PermisosPageState();
}

class _PermisosPageState extends State<PermisosPage> {
  static final _fmtDia = DateFormat('dd/MM/yyyy', 'es_ES');

  List<Map<String, dynamic>> _todos = [];
  String _estado = ''; // '' = todos
  String _tipo =
      ''; // '' = todos, TipoPermiso.permiso o TipoPermiso.recuperable
  DateTimeRange? _filtroRango; // null = sin filtro de fechas
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  // =========================================================
  // DATOS
  // =========================================================
  Future<void> _cargar() async {
    setState(() {
      _cargando = _todos.isEmpty; // si ya hay datos, recarga sin parpadeo
      _error = null;
    });
    try {
      final lista = await PermisosService.getMisPermisos(
        fechaIni: _filtroRango?.start,
        fechaFin: _filtroRango?.end,
      );
      if (!mounted) return;
      setState(() {
        _todos = lista;
        _cargando = false;
      });
    } on PermisosException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.mensaje;
      });
    }
  }

  bool _esRecuperable(Map<String, dynamic> p) =>
      '${p['tipo_permiso']}' == TipoPermiso.recuperable;

  /// Permisos que cumplen el filtro de tipo (recuperable o no)
  List<Map<String, dynamic>> get _porTipo {
    if (_tipo.isEmpty) return _todos;
    final quiereRecuperable = _tipo == TipoPermiso.recuperable;
    return _todos.where((p) => _esRecuperable(p) == quiereRecuperable).toList();
  }

  /// Permisos que cumplen el filtro de tipo y el de estado
  List<Map<String, dynamic>> get _filtrados => _estado.isEmpty
      ? _porTipo
      : _porTipo.where((p) => '${p['estado']}' == _estado).toList();

  /// Cuántos hay de un estado (dentro del tipo elegido)
  int _cuantos(String estado) =>
      _porTipo.where((p) => '${p['estado']}' == estado).length;

  /// Cuántos hay de un tipo ('' = todos)
  int _cuantosTipo(String tipo) {
    if (tipo.isEmpty) return _todos.length;
    final quiereRecuperable = tipo == TipoPermiso.recuperable;
    return _todos.where((p) => _esRecuperable(p) == quiereRecuperable).length;
  }

  bool _sePuedeEliminar(Map<String, dynamic> p) =>
      '${p['estado']}' == EstadoPermiso.presentado;

  // =========================================================
  // ACCIONES
  // =========================================================
  Future<void> _nuevo() async {
    final ok = await PermisoFormSheet.abrir(context);
    if (!ok || !mounted) return;
    SnackbarHelper.show(
      context,
      message: 'Permiso solicitado',
      backgroundColor: AppColors.success,
    );
    // que se vea el nuevo
    setState(() {
      _estado = '';
      _tipo = '';
    });
    _cargar();
  }

  /// Abre el diálogo para escribir las fechas (o elegirlas en el calendario)
  Future<void> _elegirFechas() async {
    final r = await showDialog<DateTimeRange>(
      context: context,
      builder: (_) => _FiltroFechasDialog(inicial: _filtroRango),
    );
    if (r == null || !mounted) return;
    setState(() => _filtroRango = r);
    _cargar();
  }

  void _quitarFechas() {
    setState(() => _filtroRango = null);
    _cargar();
  }

  Future<void> _eliminar(Map<String, dynamic> p) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar permiso'),
        content: Text('Vas a eliminar la solicitud del ${_rango(p)}.'),
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
    if (confirmar != true || !mounted) return;

    try {
      await PermisosService.eliminar('${p['id']}');
      if (!mounted) return;
      setState(() => _todos.removeWhere((x) => '${x['id']}' == '${p['id']}'));
      SnackbarHelper.show(
        context,
        message: 'Permiso eliminado',
        backgroundColor: AppColors.success,
      );
    } on PermisosException catch (e) {
      if (!mounted) return;
      SnackbarHelper.show(
        context,
        message: e.mensaje,
        backgroundColor: AppColors.danger,
      );
    }
  }

  /// Abre el detalle: editar (Presentado), adjuntar justificante
  /// (Aprobado/Denegado), descargar el justificante o eliminar.
  Future<void> _verDetalle(Map<String, dynamic> p) async {
    final r = await PermisoDetalleSheet.abrir(
      context,
      p,
      puedeEliminar: _sePuedeEliminar(p),
    );
    if (r == null || !mounted) return;

    if (r == DetalleResultado.eliminar) {
      _eliminar(p);
      return;
    }

    SnackbarHelper.show(
      context,
      message: 'Permiso actualizado',
      backgroundColor: AppColors.success,
    );
    _cargar();
  }

  // =========================================================
  // TEXTOS
  // =========================================================
  /// "15/10/2026" o "15/10/2026 – 18/10/2026"
  String _rango(Map<String, dynamic> p) {
    final ini = PermisosService.fecha(p['fecha_ini']);
    final fin = PermisosService.fecha(p['fecha_fin']);
    if (ini == null) return '-';
    if ('${p['duracion']}' == '1' || fin == null || isMismoDia(ini, fin)) {
      return _fmtDia.format(ini);
    }
    return '${_fmtDia.format(ini)} – ${_fmtDia.format(fin)}';
  }

  /// "09:00 – 11:00" (solo permisos de un día)
  String? _horas(Map<String, dynamic> p) {
    if ('${p['duracion']}' != '1') return null;
    final ini = PermisosService.fecha(p['fecha_ini']);
    final fin = PermisosService.fecha(p['fecha_fin']);
    if (ini == null || fin == null) return null;
    final m1 = ini.hour * 60 + ini.minute;
    final m2 = fin.hour * 60 + fin.minute;
    if (m1 == 0 && m2 == 0) return null;
    return '${minutosAHora(m1)} – ${minutosAHora(m2)}';
  }

  static bool isMismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // =========================================================
  // UI
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return MainLayout(
      currentRoute: 'permisos',
      child: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const Text(
              'Mis permisos',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _nuevo,
                icon: const Icon(Icons.add),
                label: const Text(
                  'Solicitar permiso',
                  style: TextStyle(fontSize: 17),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _filtroFechas(),
            const SizedBox(height: 12),
            _tituloFiltro('Tipo'),
            _filtroTipo(),
            const SizedBox(height: 12),
            _tituloFiltro('Estado'),
            _filtros(),
            const SizedBox(height: 16),
            ..._contenido(),
          ],
        ),
      ),
    );
  }

  Widget _filtroFechas() {
    final activo = _filtroRango != null;
    final texto = activo
        ? '${_fmtDia.format(_filtroRango!.start)} - '
              '${_fmtDia.format(_filtroRango!.end)}'
        : 'Todas las fechas';

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: activo ? AppColors.primary : AppColors.text,
              side: BorderSide(
                color: activo ? AppColors.primary : Colors.grey.shade300,
                width: activo ? 1.5 : 1,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _elegirFechas,
            icon: const Icon(Icons.date_range_outlined, size: 20),
            label: Text(texto, overflow: TextOverflow.ellipsis),
          ),
        ),
        if (activo)
          IconButton(
            tooltip: 'Quitar filtro de fechas',
            icon: const Icon(Icons.close),
            onPressed: _quitarFechas,
          ),
      ],
    );
  }

  Widget _tituloFiltro(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      t,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey[600],
      ),
    ),
  );

  /// Filtro por tipo: Todos / No recuperable / Recuperable
  Widget _filtroTipo() {
    Widget chip(String clave, String nombre, IconData icono) {
      final activo = _tipo == clave;
      return ChoiceChip(
        avatar: Icon(
          icono,
          size: 18,
          color: activo ? Colors.white : AppColors.primary,
        ),
        label: Text('$nombre  ${_cuantosTipo(clave)}'),
        selected: activo,
        showCheckmark: false,
        onSelected: (_) => setState(() => _tipo = clave),
        selectedColor: AppColors.primary,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: activo ? AppColors.primary : Colors.grey.shade300,
        ),
        labelStyle: TextStyle(
          color: activo ? Colors.white : AppColors.text,
          fontWeight: activo ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('', 'Todos', Icons.list_alt),
        chip(TipoPermiso.permiso, 'No recuperable', Icons.event_busy_outlined),
        chip(TipoPermiso.recuperable, 'Recuperable', Icons.replay),
      ],
    );
  }

  /// Filtro por estado
  Widget _filtros() {
    Widget chip(String clave, String nombre, int n, Color color) {
      final activo = _estado == clave;
      return ChoiceChip(
        label: Text('$nombre  $n'),
        selected: activo,
        showCheckmark: false,
        onSelected: (_) => setState(() => _estado = clave),
        selectedColor: color,
        backgroundColor: Colors.white,
        side: BorderSide(color: activo ? color : Colors.grey.shade300),
        labelStyle: TextStyle(
          color: activo ? Colors.white : AppColors.text,
          fontWeight: activo ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('', 'Todos', _porTipo.length, AppColors.primary),
        for (final e in EstadoPermiso.filtro)
          chip(e.clave, e.nombre, _cuantos(e.clave), e.color),
      ],
    );
  }

  List<Widget> _contenido() {
    if (_cargando) {
      return const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      ];
    }

    if (_error != null) {
      return [
        _banner(Icons.cloud_off, _error!, AppColors.danger),
        TextButton(onPressed: _cargar, child: const Text('Reintentar')),
      ];
    }

    final lista = _filtrados;
    if (lista.isEmpty) {
      final estado = EstadoPermiso.de(_estado).nombre.toLowerCase();
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Icon(
                Icons.event_note_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                _todos.isEmpty
                    ? (_filtroRango != null
                          ? 'No tienes permisos en esas fechas.'
                          : 'Todavía no has solicitado ningún permiso.')
                    : _porTipo.isEmpty
                    ? (_tipo == TipoPermiso.recuperable
                          ? 'No tienes permisos recuperables.'
                          : 'No tienes permisos no recuperables.')
                    : 'No tienes permisos en estado "$estado".',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ];
    }

    return [for (final p in lista) _tarjeta(p)];
  }

  Widget _tarjeta(Map<String, dynamic> p) {
    final estado = EstadoPermiso.de(p['estado']);
    final recuperable = _esRecuperable(p);
    final titulo = recuperable
        ? 'Permiso recuperable'
        : categoriasPermiso['${p['categoria_retribuido']}'] ?? 'Permiso';
    final horas = _horas(p);
    final adjunto = (texto(p['nombre_adjunto']) ?? '').isNotEmpty;

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _verDetalle(p),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: estado.color, width: 5)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            titulo,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _Badge(estado),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _TipoTag(recuperable: recuperable),
                    const SizedBox(height: 4),
                    _linea(Icons.event_outlined, _rango(p)),
                    if (horas != null) _linea(Icons.schedule, horas),
                    if (adjunto) _linea(Icons.attach_file, 'Con justificante'),
                  ],
                ),
              ),
              if (_sePuedeEliminar(p))
                IconButton(
                  tooltip: 'Eliminar permiso',
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.danger,
                  ),
                  onPressed: () => _eliminar(p),
                )
              else
                const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linea(IconData icono, String t) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Row(
      children: [
        Icon(icono, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Expanded(
          child: Text(t, style: TextStyle(color: Colors.grey[800])),
        ),
      ],
    ),
  );

  Widget _banner(IconData icono, String t, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(icono, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(t)),
      ],
    ),
  );
}

// =========================================================
// FILTRO DE FECHAS
// =========================================================

/// Diálogo con dos campos "Desde" / "Hasta" que se escriben a mano
/// (la barra se pone sola) o se rellenan desde el calendario.
/// Devuelve el rango elegido, o null si se cancela.
class _FiltroFechasDialog extends StatefulWidget {
  final DateTimeRange? inicial;
  const _FiltroFechasDialog({this.inicial});

  @override
  State<_FiltroFechasDialog> createState() => _FiltroFechasDialogState();
}

class _FiltroFechasDialogState extends State<_FiltroFechasDialog> {
  static final _fmt = DateFormat('dd/MM/yyyy');
  static final _primera = DateTime(2020);
  static final _ultima = DateTime(DateTime.now().year + 2, 12, 31);

  late final TextEditingController _desde;
  late final TextEditingController _hasta;
  String? _errorDesde;
  String? _errorHasta;

  @override
  void initState() {
    super.initState();
    final r = widget.inicial;
    _desde = TextEditingController(text: r == null ? '' : _fmt.format(r.start));
    _hasta = TextEditingController(text: r == null ? '' : _fmt.format(r.end));
  }

  @override
  void dispose() {
    _desde.dispose();
    _hasta.dispose();
    super.dispose();
  }

  /// "15/10/2026" -> DateTime. null si no es una fecha real (31/02, 99/99...)
  DateTime? _leer(String t) {
    if (!RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(t)) return null;
    try {
      final d = _fmt.parseStrict(t);
      if (d.isBefore(_primera) || d.isAfter(_ultima)) return null;
      return d;
    } catch (_) {
      return null;
    }
  }

  String? _validar(String t) {
    if (t.isEmpty) return 'Obligatorio';
    if (t.length < 10) return 'Formato dd/mm/aaaa';
    if (_leer(t) == null) return 'Fecha no válida';
    return null;
  }

  void _aplicar() {
    final eDesde = _validar(_desde.text);
    final eHasta = _validar(_hasta.text);
    String? eRango;
    if (eDesde == null && eHasta == null) {
      final ini = _leer(_desde.text)!;
      final fin = _leer(_hasta.text)!;
      if (fin.isBefore(ini)) eRango = 'Debe ser igual o posterior a "Desde"';
    }
    setState(() {
      _errorDesde = eDesde;
      _errorHasta = eHasta ?? eRango;
    });
    if (eDesde != null || eHasta != null || eRango != null) return;

    Navigator.pop(
      context,
      DateTimeRange(start: _leer(_desde.text)!, end: _leer(_hasta.text)!),
    );
  }

  /// Abre el calendario (solo calendario, sin escribir) y rellena los campos
  Future<void> _calendario() async {
    final ini = _leer(_desde.text);
    final fin = _leer(_hasta.text);
    final r = await showDateRangePicker(
      context: context,
      firstDate: _primera,
      lastDate: _ultima,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      initialDateRange: ini != null && fin != null && !fin.isBefore(ini)
          ? DateTimeRange(start: ini, end: fin)
          : null,
      helpText: 'Filtrar por fechas',
      saveText: 'Aceptar',
    );
    if (r == null || !mounted) return;
    setState(() {
      _desde.text = _fmt.format(r.start);
      _hasta.text = _fmt.format(r.end);
      _errorDesde = null;
      _errorHasta = null;
    });
  }

  Widget _campo(
    String label,
    TextEditingController c,
    String? error, {
    required bool ultimo,
  }) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      textInputAction: ultimo ? TextInputAction.done : TextInputAction.next,
      onSubmitted: ultimo ? (_) => _aplicar() : null,
      inputFormatters: [FechaInputFormatter()],
      onChanged: (_) => setState(() {
        if (c == _desde) {
          _errorDesde = null;
        } else {
          _errorHasta = null;
        }
      }),
      decoration: InputDecoration(
        labelText: label,
        hintText: 'dd/mm/aaaa',
        errorText: error,
        counterText: '',
        prefixIcon: const Icon(Icons.event_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filtrar por fechas'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _campo('Desde', _desde, _errorDesde, ultimo: false),
            const SizedBox(height: 12),
            _campo('Hasta', _hasta, _errorHasta, ultimo: true),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _calendario,
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Elegir en el calendario'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: Colors.grey),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _aplicar,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}

/// Máscara dd/mm/aaaa: solo deja escribir números (máx. 8)
/// y pone las barras solas. Al borrar, la barra se va con el número.
class FechaInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digitos = newValue.text.replaceAll(RegExp(r'\D'), '');
    final antes = oldValue.text.replaceAll(RegExp(r'\D'), '');

    // Se borró solo una barra: borrar también el número de delante
    if (newValue.text.length < oldValue.text.length &&
        digitos == antes &&
        digitos.isNotEmpty) {
      digitos = digitos.substring(0, digitos.length - 1);
    }

    if (digitos.length > 8) digitos = digitos.substring(0, 8);

    final b = StringBuffer();
    for (var i = 0; i < digitos.length; i++) {
      if (i == 2 || i == 4) b.write('/');
      b.write(digitos[i]);
    }
    final texto = b.toString();
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

// =========================================================
// WIDGETS
// =========================================================

/// Etiqueta "Recuperable" / "No recuperable"
class _TipoTag extends StatelessWidget {
  final bool recuperable;
  const _TipoTag({required this.recuperable});

  @override
  Widget build(BuildContext context) {
    final color = recuperable ? AppColors.primary : Colors.grey.shade700;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              recuperable ? Icons.replay : Icons.event_busy_outlined,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              recuperable ? 'Recuperable' : 'No recuperable',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Etiqueta de color con el estado
class _Badge extends StatelessWidget {
  final EstadoPermiso estado;
  const _Badge(this.estado);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: estado.color,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      estado.nombre,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
