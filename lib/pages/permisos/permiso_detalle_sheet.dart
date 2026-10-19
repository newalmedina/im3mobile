import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/permisos_service.dart';
import '../../theme/theme.dart';
import '../../utils/horas_reglas.dart';
import 'permisos_catalogo.dart';

/// Lo que devuelve la hoja al cerrarse
enum DetalleResultado { guardado, eliminar }

/// Detalle de un permiso.
/// - Presentado: se puede cambiar todo y el justificante.
/// - Aprobado / Denegado: solo se puede adjuntar, cambiar o quitar
///   el justificante.
/// - El justificante, si existe, siempre se puede descargar.
class PermisoDetalleSheet extends StatefulWidget {
  final Map<String, dynamic> permiso;
  final bool puedeEliminar;

  const PermisoDetalleSheet({
    super.key,
    required this.permiso,
    required this.puedeEliminar,
  });

  static Future<DetalleResultado?> abrir(
    BuildContext context,
    Map<String, dynamic> permiso, {
    required bool puedeEliminar,
  }) {
    return showModalBottomSheet<DetalleResultado>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) =>
          PermisoDetalleSheet(permiso: permiso, puedeEliminar: puedeEliminar),
    );
  }

  @override
  State<PermisoDetalleSheet> createState() => _PermisoDetalleSheetState();
}

class _PermisoDetalleSheetState extends State<PermisoDetalleSheet> {
  static final _fmtDia = DateFormat('dd/MM/yyyy', 'es_ES');

  Map<String, dynamic> get p => widget.permiso;

  late final EstadoPermiso _estado = EstadoPermiso.de(p['estado']);
  late final bool _recuperable =
      '${p['tipo_permiso']}' == TipoPermiso.recuperable;

  /// Presentado = se puede editar todo
  late final bool _editable = '${p['estado']}' == EstadoPermiso.presentado;

  /// Valores tal cual vienen del servidor (para el modo "solo justificante")
  DateTime? _iniServidor;
  DateTime? _finServidor;
  late final String _categoriaServidor = texto(p['categoria_retribuido']) ?? '';
  late final String _comentariosServidor = texto(p['comentarios']) ?? '';

  // Campos editables
  late bool _unDia;
  String _categoria = '';
  DateTime? _fechaIni;
  DateTime? _fechaFin;
  int? _horaIni; // minutos desde las 00:00
  int? _horaFin;
  final _comentarios = TextEditingController();

  // Justificante
  String? _adjuntoServidor; // nombre en el servidor (para descargar)
  String? _adjuntoNombre; // nombre original para mostrar
  PlatformFile? _archivoNuevo;
  bool _quitarAdjunto = false;

  bool _intentado = false;
  bool _guardando = false;
  String? _errorServidor;

  @override
  void initState() {
    super.initState();
    _iniServidor = PermisosService.fecha(p['fecha_ini']);
    _finServidor = PermisosService.fecha(p['fecha_fin']);

    _unDia = '${p['duracion']}' == '1';
    _categoria = categoriasPermiso.containsKey(_categoriaServidor)
        ? _categoriaServidor
        : '';

    final ini = _iniServidor;
    final fin = _finServidor;
    if (ini != null) _fechaIni = DateTime(ini.year, ini.month, ini.day);
    if (fin != null) _fechaFin = DateTime(fin.year, fin.month, fin.day);
    if (_unDia && ini != null && fin != null) {
      final m1 = _minutos(ini);
      final m2 = _minutos(fin);
      if (!(m1 == 0 && m2 == 0)) {
        _horaIni = m1;
        _horaFin = m2;
      }
    }

    _comentarios.text = _comentariosServidor;
    _adjuntoServidor = texto(p['nombre_adjunto']);
    _adjuntoNombre = texto(p['nombre_original_adjunto']) ?? _adjuntoServidor;
  }

  @override
  void dispose() {
    _comentarios.dispose();
    super.dispose();
  }

  static int _minutos(DateTime d) => d.hour * 60 + d.minute;

  /// Igual que la web: el justificante solo existe en el permiso normal
  bool get _admiteArchivo => !_recuperable;

  /// Campos donde puede venir la fecha en que se solicitó el permiso.
  /// Se usa el primero que traiga valor.
  static const _camposFechaSolicitud = [
    'fecha_solicitud',
    'created_at',
    'fecha_creacion',
    'fecha_alta',
  ];

  /// Fecha en que se solicitó el permiso (null si el servidor no la manda)
  DateTime? get _fechaSolicitud {
    for (final c in _camposFechaSolicitud) {
      final f = PermisosService.fecha(p[c]);
      if (f != null) return f;
    }
    return null;
  }

  /// Último día en que se puede tocar el justificante (1 mes tras solicitarlo)
  DateTime? get _limiteJustificante {
    final s = _fechaSolicitud;
    if (s == null) return null;
    return DateTime(s.year, s.month + 1, s.day, 23, 59, 59);
  }

  /// Aprobado / Denegado: solo dentro del mes desde que se solicitó.
  /// Presentado: siempre.
  bool get _dentroDePlazo {
    if (_editable) return true;
    final limite = _limiteJustificante;
    if (limite == null) return false;
    return !DateTime.now().isAfter(limite);
  }

  /// Se puede adjuntar, cambiar o quitar el justificante
  bool get _puedeTocarArchivo => _admiteArchivo && _dentroDePlazo;

  bool get _tieneAdjuntoActual => _adjuntoServidor != null && !_quitarAdjunto;

  /// Solo se quita el actual, sin subir otro
  bool get _soloQuitar => _quitarAdjunto && _archivoNuevo == null;

  String? get _error {
    if (!_editable) {
      return (_archivoNuevo == null && !_quitarAdjunto)
          ? 'Elige un archivo o quita el actual.'
          : null;
    }
    if (!_recuperable && _categoria.isEmpty) {
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
        return 'La hora de fin debe ser posterior a la de inicio.';
      }
    } else {
      if (_fechaFin == null) return 'Elige la fecha de fin.';
      if (_fechaFin!.isBefore(_fechaIni!)) {
        return 'La fecha de fin no puede ser anterior a la de inicio.';
      }
    }
    return null;
  }

  // =========================================================
  // ACCIONES
  // =========================================================
  Future<void> _elegirFecha({required bool inicio}) async {
    final actual = inicio ? _fechaIni : (_fechaFin ?? _fechaIni);
    final d = await showDatePicker(
      context: context,
      initialDate: actual ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 2, 12, 31),
      helpText: inicio ? 'Fecha de inicio' : 'Fecha de fin',
    );
    if (d == null || !mounted) return;
    setState(() {
      if (inicio) {
        _fechaIni = d;
        if (_fechaFin != null && _fechaFin!.isBefore(d)) _fechaFin = d;
      } else {
        _fechaFin = d;
      }
    });
  }

  Future<void> _elegirHora({required bool inicio}) async {
    final actual = inicio ? _horaIni : _horaFin;
    final t = await showTimePicker(
      context: context,
      initialTime: actual != null
          ? TimeOfDay(hour: actual ~/ 60, minute: actual % 60)
          : const TimeOfDay(hour: 9, minute: 0),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t == null || !mounted) return;
    setState(() {
      final m = t.hour * 60 + t.minute;
      if (inicio) {
        _horaIni = m;
      } else {
        _horaFin = m;
      }
    });
  }

  Future<void> _elegirArchivo() async {
    // file_picker 13: pickFile() es estático y devuelve el archivo o null
    final f = await FilePicker.pickFile();
    if (f == null || !mounted) return;
    setState(() {
      _archivoNuevo = f;
      _errorServidor = null;
    });
  }

  Future<void> _descargar() async {
    final nombre = _adjuntoServidor;
    if (nombre == null) return;
    final url = Uri.parse(PermisosService.urlAdjunto(nombre));
    bool ok = false;
    try {
      ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) {
      setState(() => _errorServidor = 'No se ha podido abrir el justificante.');
    }
  }

  Future<void> _guardar() async {
    setState(() => _intentado = true);
    if (_error != null) return;
    if (_fechaIni == null) {
      setState(() => _errorServidor = 'El permiso no tiene fecha válida.');
      return;
    }

    setState(() {
      _guardando = true;
      _errorServidor = null;
    });

    try {
      await PermisosService.actualizar(
        id: '${p['id']}',
        estado: '${p['estado']}',
        tipoPermiso: '${p['tipo_permiso']}',
        unDia: _unDia,
        fechaIni: _fechaIni!,
        fechaFin: _fechaFin,
        // En modo "solo justificante" se mandan las horas originales
        horaIni:
            _horaIni ?? (_iniServidor != null ? _minutos(_iniServidor!) : 0),
        horaFin:
            _horaFin ?? (_finServidor != null ? _minutos(_finServidor!) : 0),
        categoria: _editable
            ? (_recuperable ? '' : _categoria)
            : _categoriaServidor,
        comentarios: _editable
            ? _comentarios.text.trim()
            : _comentariosServidor,
        archivo: _archivoNuevo,
        // Si hay archivo nuevo, ya sustituye al anterior
        borrarArchivo: _soloQuitar,
      );
      if (!mounted) return;
      Navigator.pop(context, DetalleResultado.guardado);
    } on PermisosException catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _errorServidor = e.mensaje;
      });
    }
  }

  // =========================================================
  // UI
  // =========================================================
  @override
  Widget build(BuildContext context) {
    final error = _intentado ? _error : null;
    final puedeGuardar = _editable || _puedeTocarArchivo;

    final IconData iconoBoton = _editable
        ? Icons.save_outlined
        : (_soloQuitar ? Icons.delete_outline : Icons.upload_file);
    final String textoBoton = _editable
        ? 'Guardar cambios'
        : (_soloQuitar ? 'Quitar justificante' : 'Subir justificante');

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      TipoPermiso.nombre(p['tipo_permiso']),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  _Badge(_estado),
                ],
              ),
              const SizedBox(height: 16),
              if (!_editable) _aviso(_textoAviso()),
              if (_editable) ..._formulario() else ..._soloLectura(),
              if (_admiteArchivo) ...[
                const SizedBox(height: 4),
                _justificante(),
              ],
              if (error != null) _textoError(error),
              if (_errorServidor != null) _textoError(_errorServidor!),
              const SizedBox(height: 16),
              if (puedeGuardar)
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: (!_editable && _soloQuitar)
                          ? AppColors.danger
                          : AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _guardando ? null : _guardar,
                    icon: _guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(iconoBoton),
                    label: Text(
                      textoBoton,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              if (widget.puedeEliminar) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _guardando
                        ? null
                        : () =>
                              Navigator.pop(context, DetalleResultado.eliminar),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar permiso'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Presentado: todos los campos editables
  List<Widget> _formulario() => [
    SegmentedButton<bool>(
      segments: const [
        ButtonSegment(
          value: true,
          label: Text('Un día'),
          icon: Icon(Icons.today),
        ),
        ButtonSegment(
          value: false,
          label: Text('Varios días'),
          icon: Icon(Icons.date_range),
        ),
      ],
      selected: {_unDia},
      onSelectionChanged: _guardando
          ? null
          : (s) => setState(() => _unDia = s.first),
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppColors.primary,
        selectedForegroundColor: Colors.white,
      ),
    ),
    const SizedBox(height: 16),
    if (!_recuperable) ...[
      DropdownButtonFormField<String>(
        initialValue: _categoria.isEmpty ? null : _categoria,
        isExpanded: true,
        decoration: _deco('Tipo de permiso', Icons.category_outlined),
        items: [
          for (final e in categoriasPermiso.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: _guardando
            ? null
            : (v) => setState(() => _categoria = v ?? ''),
      ),
      const SizedBox(height: 12),
    ],
    _selector(
      _unDia ? 'Día' : 'Fecha de inicio',
      _fechaIni == null ? null : _fmtDia.format(_fechaIni!),
      Icons.event_outlined,
      () => _elegirFecha(inicio: true),
    ),
    if (!_unDia)
      _selector(
        'Fecha de fin',
        _fechaFin == null ? null : _fmtDia.format(_fechaFin!),
        Icons.event_outlined,
        () => _elegirFecha(inicio: false),
      ),
    if (_unDia)
      Row(
        children: [
          Expanded(
            child: _selector(
              'Hora inicio',
              _horaIni == null ? null : minutosAHora(_horaIni!),
              Icons.schedule,
              () => _elegirHora(inicio: true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _selector(
              'Hora fin',
              _horaFin == null ? null : minutosAHora(_horaFin!),
              Icons.schedule,
              () => _elegirHora(inicio: false),
            ),
          ),
        ],
      ),
    TextField(
      controller: _comentarios,
      enabled: !_guardando,
      minLines: 3,
      maxLines: 5,
      decoration: _deco(
        _recuperable ? 'Cómo lo vas a recuperar' : 'Descripción',
        Icons.notes,
      ),
    ),
    const SizedBox(height: 12),
  ];

  /// Aprobado / Denegado: datos sin poder tocarlos
  List<Widget> _soloLectura() {
    final categoria = categoriasPermiso[_categoriaServidor];
    final numHoras = texto(p['num_horas']);
    return [
      _fila('Recuperable', _recuperable ? 'Sí' : 'No'),
      if (!_recuperable && categoria != null) _fila('Tipo', categoria),
      _fila('Fecha', _textoRango()),
      if (_horaIni != null && _horaFin != null)
        _fila(
          'Horario',
          '${minutosAHora(_horaIni!)} – ${minutosAHora(_horaFin!)}',
        ),
      if (numHoras != null) _fila('Horas', numHoras),
      if (_comentariosServidor.isNotEmpty)
        _fila(
          _recuperable ? 'Recuperación' : 'Descripción',
          _comentariosServidor,
        ),
    ];
  }

  String _textoAviso() {
    final estado = _estado.nombre.toLowerCase();
    if (!_admiteArchivo) {
      return 'Este permiso está $estado y ya no se puede modificar.';
    }
    if (_puedeTocarArchivo) {
      final limite = _limiteJustificante;
      final hasta = limite == null ? '' : ' hasta el ${_fmtDia.format(limite)}';
      return 'Este permiso está $estado. Puedes adjuntar, cambiar o quitar '
          'el justificante$hasta.';
    }
    final limite = _limiteJustificante;
    return limite == null
        ? 'Este permiso está $estado y ya no se puede modificar.'
        : 'Este permiso está $estado. El plazo para cambiar el justificante '
              'terminó el ${_fmtDia.format(limite)} (1 mes desde la solicitud).';
  }

  String _textoRango() {
    if (_fechaIni == null) return '-';
    if (_unDia || _fechaFin == null || _fechaFin == _fechaIni) {
      return _fmtDia.format(_fechaIni!);
    }
    return '${_fmtDia.format(_fechaIni!)} – ${_fmtDia.format(_fechaFin!)}';
  }

  /// Bloque del justificante: descargar el actual, quitarlo, subir otro
  Widget _justificante() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Justificante',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          if (_tieneAdjuntoActual)
            _archivoFila(
              nombre: _adjuntoNombre ?? 'Archivo adjunto',
              detalle: _archivoNuevo != null
                  ? 'Se sustituirá por el nuevo'
                  : null,
              acciones: [
                IconButton(
                  tooltip: 'Descargar',
                  icon: const Icon(Icons.download, color: AppColors.primary),
                  onPressed: _descargar,
                ),
                if (_puedeTocarArchivo)
                  IconButton(
                    tooltip: 'Quitar justificante',
                    icon: const Icon(Icons.close, color: AppColors.danger),
                    onPressed: _guardando
                        ? null
                        : () => setState(() {
                            _quitarAdjunto = true;
                            _errorServidor = null;
                          }),
                  ),
              ],
            ),
          if (_archivoNuevo != null)
            _archivoFila(
              nombre: _archivoNuevo!.name,
              detalle: 'Nuevo, se sube al guardar',
              acciones: [
                IconButton(
                  tooltip: 'Quitar',
                  icon: const Icon(Icons.close, color: AppColors.danger),
                  onPressed: _guardando
                      ? null
                      : () => setState(() => _archivoNuevo = null),
                ),
              ],
            ),
          if (!_tieneAdjuntoActual && _archivoNuevo == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _quitarAdjunto
                  ? Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 18,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Se quitará el justificante al guardar.',
                            style: TextStyle(color: Colors.grey[800]),
                          ),
                        ),
                        TextButton(
                          onPressed: _guardando
                              ? null
                              : () => setState(() => _quitarAdjunto = false),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                          ),
                          child: const Text('Deshacer'),
                        ),
                      ],
                    )
                  : Text(
                      'Sin justificante.',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
            ),
          if (_puedeTocarArchivo)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _guardando ? null : _elegirArchivo,
                icon: const Icon(Icons.attach_file),
                label: Text(
                  _tieneAdjuntoActual || _archivoNuevo != null
                      ? 'Cambiar archivo'
                      : 'Adjuntar archivo',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _archivoFila({
    required String nombre,
    String? detalle,
    required List<Widget> acciones,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(Icons.insert_drive_file_outlined, color: Colors.grey[700]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              if (detalle != null)
                Text(
                  detalle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
            ],
          ),
        ),
        ...acciones,
      ],
    ),
  );

  Widget _selector(
    String etiqueta,
    String? valor,
    IconData icono,
    VoidCallback onTap,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      onTap: _guardando ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: _deco(etiqueta, icono),
        child: Text(
          valor ?? 'Elegir',
          style: TextStyle(
            color: valor == null ? Colors.grey[500] : AppColors.text,
          ),
        ),
      ),
    ),
  );

  InputDecoration _deco(String label, IconData icono) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icono),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
  );

  Widget _fila(String etiqueta, String valor) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(etiqueta, style: TextStyle(color: Colors.grey[600])),
        ),
        Expanded(
          child: Text(
            valor,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Widget _aviso(String t) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _estado.color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(Icons.info_outline, color: _estado.color),
        const SizedBox(width: 10),
        Expanded(child: Text(t)),
      ],
    ),
  );

  Widget _textoError(String t) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Text(
      t,
      style: const TextStyle(
        color: AppColors.danger,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
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
