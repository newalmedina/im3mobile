import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../config/api.dart';
import 'api_service.dart';
import 'auth_service.dart';

class PermisosException implements Exception {
  final String mensaje;
  PermisosException(this.mensaje);
  @override
  String toString() => mensaje;
}

/// Llamadas a la API de permisos (las mismas que permisos.vue).
/// En la app el usuario solo ve y gestiona SUS permisos
/// (autorizacion = 'solicitar'), aunque en la web sea responsable o RRHH.
class PermisosService {
  /// Permisos del usuario, tal cual vienen del servidor.
  /// Se piden con estado '' (= "Todas" en la web) y se filtran en la app.
  /// Si se pasan [fechaIni] y/o [fechaFin], el servidor filtra por fechas.
  static Future<List<Map<String, dynamic>>> getMisPermisos({
    DateTime? fechaIni,
    DateTime? fechaFin,
  }) async {
    final idUser = await AuthService.getUserId();
    if (idUser == null) {
      throw PermisosException(
        'No se ha encontrado tu usuario. Vuelve a iniciar sesión.',
      );
    }

    final fmt = DateFormat('yyyy-MM-dd');

    final uri =
        Uri.parse(
          '${ApiConfig.intranetBaseUrl}${ApiConfig.permisos}/$idUser',
        ).replace(
          queryParameters: {
            'usuario_id': '',
            'estado': '',
            'fecha_ini': fechaIni != null ? fmt.format(fechaIni) : '',
            'fecha_fin': fechaFin != null ? fmt.format(fechaFin) : '',
            'autorizacion': 'solicitar',
          },
        );

    final res = await ApiService.get(uri.toString(), auth: true);
    _comprobar(res);
    final data = res['data'];
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  /// Crea un permiso. Mismos campos que enviarFormulario() en la web.
  /// [horaIni]/[horaFin]: minutos desde las 00:00 (solo si [unDia]).
  /// [archivo]: justificante elegido con file_picker (opcional).
  static Future<void> crear({
    required String tipoPermiso,
    required bool unDia,
    required DateTime fechaIni,
    DateTime? fechaFin,
    int? horaIni,
    int? horaFin,
    String categoria = '',
    String comentarios = '',
    PlatformFile? archivo,
  }) async {
    final res = await ApiService.postMultipart(
      '${ApiConfig.intranetBaseUrl}${ApiConfig.permisos}',
      auth: true,
      fields: {
        // Sin archivo -> la web manda borrar_archivo = 1
        if (archivo == null) 'borrar_archivo': '1',
        // Vacío = el usuario del token (igual que la web para un empleado)
        'usuario_target': '',
        'estado': '1', // Presentado
        ..._campos(
          tipoPermiso: tipoPermiso,
          unDia: unDia,
          fechaIni: fechaIni,
          fechaFin: fechaFin,
          horaIni: horaIni,
          horaFin: horaFin,
          categoria: categoria,
          comentarios: comentarios,
        ),
      },
      archivos: await _archivos(archivo),
    );
    _comprobar(res);
  }

  /// Actualiza un permiso: POST .../permisos/{id}, igual que la web al editar.
  /// El estado se manda tal cual estaba (guardar no cambia el estado).
  ///
  /// Justificante (igual que la web):
  /// - [archivo] != null -> se sube y sustituye al que hubiera.
  /// - [borrarArchivo] true y sin archivo nuevo -> se quita el actual.
  /// - Ninguno de los dos -> se deja el que tenga.
  static Future<void> actualizar({
    required String id,
    required String estado,
    required String tipoPermiso,
    required bool unDia,
    required DateTime fechaIni,
    DateTime? fechaFin,
    int? horaIni,
    int? horaFin,
    String categoria = '',
    String comentarios = '',
    PlatformFile? archivo,
    bool borrarArchivo = false,
  }) async {
    final res = await ApiService.postMultipart(
      '${ApiConfig.intranetBaseUrl}${ApiConfig.permisos}/$id',
      auth: true,
      fields: {
        if (archivo == null && borrarArchivo) 'borrar_archivo': '1',
        'usuario_target': '',
        'estado': estado,
        ..._campos(
          tipoPermiso: tipoPermiso,
          unDia: unDia,
          fechaIni: fechaIni,
          fechaFin: fechaFin,
          horaIni: horaIni,
          horaFin: horaFin,
          categoria: categoria,
          comentarios: comentarios,
        ),
      },
      archivos: await _archivos(archivo),
    );
    _comprobar(res);
  }

  static Future<void> eliminar(String id) async {
    final res = await ApiService.delete(
      '${ApiConfig.intranetBaseUrl}${ApiConfig.permisos}/$id',
      auth: true,
    );
    _comprobar(res);
  }

  /// URL pública del justificante, la misma que usa la web:
  /// baseBackUrl + '/intranet/files/permisos/' + nombre_adjunto
  static String urlAdjunto(String nombreAdjunto) =>
      '${ApiConfig.intranetBaseUrl}files/permisos/'
      '${Uri.encodeComponent(nombreAdjunto)}';

  /// Lee una fecha del servidor SIN cambiarla de zona horaria
  /// (como moment.parseZone en la web): "2026-10-15 09:00:00",
  /// "2026-10-15T09:00:00+02:00"... -> 15/10/2026 09:00
  static DateTime? fecha(dynamic valor) {
    final m = RegExp(
      r'(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2}))?',
    ).firstMatch('${valor ?? ''}');
    if (m == null) return null;
    return DateTime(
      int.parse(m[1]!),
      int.parse(m[2]!),
      int.parse(m[3]!),
      int.parse(m[4] ?? '0'),
      int.parse(m[5] ?? '0'),
    );
  }

  // ------------------------------------------------------------------

  /// El justificante como campo "archivo" del FormData (igual que la web).
  /// Se leen los bytes, así funciona igual en web, Android e iOS.
  static Future<List<http.MultipartFile>> _archivos(PlatformFile? f) async {
    if (f == null) return [];
    try {
      final bytes = await f.readAsBytes();
      return [http.MultipartFile.fromBytes('archivo', bytes, filename: f.name)];
    } catch (_) {
      throw PermisosException('No se ha podido leer el archivo.');
    }
  }

  /// Campos comunes de crear y actualizar
  static Map<String, String> _campos({
    required String tipoPermiso,
    required bool unDia,
    required DateTime fechaIni,
    DateTime? fechaFin,
    int? horaIni,
    int? horaFin,
    String categoria = '',
    String comentarios = '',
  }) {
    final ini = _dia(fechaIni);
    final fin = unDia ? ini : _dia(fechaFin ?? fechaIni);
    return {
      'fecha_ini': _fechaWeb(ini),
      'fecha_fin': _fechaWeb(fin),
      'duracion': unDia ? '1' : '2',
      'hora_ini': unDia ? _fechaWeb(_conHora(fechaIni, horaIni ?? 0)) : '',
      'hora_fin': unDia ? _fechaWeb(_conHora(fechaIni, horaFin ?? 0)) : '',
      'tipo_permiso': tipoPermiso,
      'categoria_retribuido': categoria,
      'comentarios': comentarios,
    };
  }

  /// Las fechas sin hora se mandan a mediodía para que ningún cambio de
  /// zona horaria en el servidor las pase al día anterior.
  static DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day, 12);

  static DateTime _conHora(DateTime d, int minutos) =>
      DateTime(d.year, d.month, d.day, minutos ~/ 60, minutos % 60);

  /// La web mete en el FormData el objeto moment tal cual, que se convierte
  /// en texto con moment().toString(): "Thu Oct 15 2026 12:00:00 GMT+0200".
  /// Se manda igual para que el backend lo lea exactamente como desde la web.
  static String _fechaWeb(DateTime d) {
    final base = DateFormat('EEE MMM dd yyyy HH:mm:ss', 'en_US').format(d);
    final off = d.timeZoneOffset;
    final signo = off.isNegative ? '-' : '+';
    final h = off.inHours.abs().toString().padLeft(2, '0');
    final m = (off.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return '$base GMT$signo$h$m';
  }

  static void _comprobar(Map<String, dynamic> res) {
    final status = res['http_status'];
    if (status == 0) {
      throw PermisosException('No se pudo conectar con el servidor.');
    }
    if (status == 401) {
      throw PermisosException(
        'Tu sesión no es válida. Vuelve a iniciar sesión.',
      );
    }
    if (res['ok'] != true) {
      final msg = res['mensaje'] ?? res['message'] ?? res['error'];
      throw PermisosException(
        msg?.toString() ?? 'Error del servidor ($status).',
      );
    }
  }
}
