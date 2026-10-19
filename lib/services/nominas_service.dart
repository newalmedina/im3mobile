import 'dart:convert';
import 'dart:typed_data';

import '../config/api.dart';
import 'api_service.dart';
import 'auth_service.dart';

class NominasException implements Exception {
  final String mensaje;
  NominasException(this.mensaje);
  @override
  String toString() => mensaje;
}

/// Tipos de documento (los mismos que nameView / nameFile de la web)
class TipoNomina {
  static String nombre(dynamic tipo) {
    switch ('$tipo') {
      case '2':
        return 'Nómina extra';
      case '3':
        return 'Renta';
      default:
        return 'Nómina';
    }
  }

  /// Parte del nombre del archivo: nomina / nomina_extra / renta
  static String archivo(dynamic tipo) {
    switch ('$tipo') {
      case '2':
        return 'nomina_extra';
      case '3':
        return 'renta';
      default:
        return 'nomina';
    }
  }
}

/// Llamadas a la API de nóminas (las mismas que la pantalla de la web).
class NominasService {
  /// Lista de nóminas del usuario, tal cual vienen del servidor.
  /// Cada una trae al menos: id, fecha_nomina, tipo, description.
  static Future<List<Map<String, dynamic>>> getMisNominas() async {
    final idUser = await AuthService.getUserId();
    if (idUser == null) {
      throw NominasException(
        'No se ha encontrado tu usuario. Vuelve a iniciar sesión.',
      );
    }

    final res = await ApiService.get(
      '${ApiConfig.intranetBaseUrl}${ApiConfig.nominas}/$idUser',
      auth: true,
    );
    _comprobar(res);

    // La respuesta puede ser la lista directamente ({'data': [...]})
    // o venir dentro de una clave (payslips / nominas).
    final data = res['payslips'] ?? res['nominas'] ?? res['data'];
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  /// Descarga el PDF: POST descargar_archivo con { archivo_id }.
  static Future<Uint8List> descargar(Map<String, dynamic> nomina) async {
    final res = await ApiService.postBytes(
      '${ApiConfig.intranetBaseUrl}${ApiConfig.descargarArchivo}',
      body: {'archivo_id': nomina['id']},
      auth: true,
    );

    if (res.status == 0) {
      throw NominasException('No se pudo conectar con el servidor.');
    }
    if (res.status == 401) {
      throw NominasException('Tu sesión no es válida. Vuelve a iniciar sesión.');
    }

    final bytes = res.bytes;
    final esJson = bytes.isNotEmpty && bytes.first == 0x7B; // '{'
    if (res.status < 200 || res.status >= 300 || bytes.isEmpty || esJson) {
      throw NominasException(
        _mensajeError(bytes) ?? 'No se ha podido descargar la nómina.',
      );
    }
    return bytes;
  }

  /// Nombre del archivo igual que la web: AAMM_CIF_tipo.pdf
  /// (si no hay CIF: AAMM_tipo.pdf)
  static Future<String> nombreArchivo(Map<String, dynamic> nomina) async {
    final f = '${nomina['fecha_nomina'] ?? ''}';
    final ano = f.length >= 4 ? f.substring(2, 4) : '';
    final mes = f.length >= 7 ? f.substring(5, 7) : '';
    final tipo = TipoNomina.archivo(nomina['tipo']);

    final user = await AuthService.getUser();
    final cif = '${user?['cif'] ?? user?['nif'] ?? user?['dni'] ?? ''}'.trim();

    return cif.isEmpty ? '$ano${mes}_$tipo.pdf' : '$ano${mes}_${cif}_$tipo.pdf';
  }

  /// Lee una fecha del servidor sin cambiar de zona horaria
  /// (como moment.parseZone en la web).
  static DateTime? fecha(dynamic valor) {
    final m = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch('${valor ?? ''}');
    if (m == null) return null;
    return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  // ------------------------------------------------------------------

  static String? _mensajeError(Uint8List bytes) {
    try {
      final j = jsonDecode(utf8.decode(bytes));
      if (j is Map) {
        final msg = j['mensaje'] ?? j['message'] ?? j['error'];
        if (msg != null) return msg.toString();
      }
    } catch (_) {}
    return null;
  }

  static void _comprobar(Map<String, dynamic> res) {
    final status = res['http_status'];
    if (status == 0) {
      throw NominasException('No se pudo conectar con el servidor.');
    }
    if (status == 401) {
      throw NominasException('Tu sesión no es válida. Vuelve a iniciar sesión.');
    }
    if (res['ok'] != true) {
      final msg = res['mensaje'] ?? res['message'] ?? res['error'];
      throw NominasException(msg?.toString() ?? 'Error del servidor ($status).');
    }
  }
}
