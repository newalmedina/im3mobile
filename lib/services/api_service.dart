import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api.dart';
import 'auth_service.dart';

/// Servicio para hacer las llamadas a la API. SIN modelos.
///
/// Devuelve el JSON tal cual vino del servidor, como Map,
/// más dos claves que añade este servicio:
///   - 'ok'          -> true si el HTTP fue 2xx
///   - 'http_status' -> código HTTP (0 = sin conexión / timeout)
///
/// auth: true -> manda el token del usuario:
///   - en la cabecera "auth-token" (igual que la web)
///   - y también en el body como "token" (POST/PUT)
class ApiService {
  static const Duration _timeout = Duration(seconds: 20);

  /// Formatos del token que se prueban, en orden (sin "Bearer")
  static const List<String> _formatos = [''];

  /// El formato que ya funcionó (se recuerda mientras la app esté abierta)
  static String? _formatoOk;

  static Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) => _send('POST', endpoint, body: body, auth: auth);

  static Future<Map<String, dynamic>> get(
    String endpoint, {
    bool auth = false,
  }) => _send('GET', endpoint, auth: auth);

  static Future<Map<String, dynamic>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) => _send('PATCH', endpoint, body: body, auth: auth);

  static Future<Map<String, dynamic>> delete(
    String endpoint, {
    bool auth = false,
  }) => _send('DELETE', endpoint, auth: auth);

  /// POST multipart/form-data, como el `new FormData()` de la web.
  /// [fields]: campos de texto. [archivos]: ficheros (fotos, adjuntos...).
  /// El token va en la cabecera "auth-token".
  static Future<Map<String, dynamic>> postMultipart(
    String endpoint, {
    required Map<String, String> fields,
    List<http.MultipartFile> archivos = const [],
    bool auth = false,
  }) async {
    final url = endpoint.startsWith('http')
        ? endpoint
        : ApiConfig.baseUrl + endpoint;

    String? token;
    if (auth) {
      final user = await AuthService.getUser();
      token = user?['token']?.toString();
    }

    if (kDebugMode) {
      debugPrint('➡️ POST (multipart) $url');
      debugPrint('➡️ CAMPOS: ${jsonEncode(fields)}');
      for (final a in archivos) {
        debugPrint(
          '➡️ ARCHIVO: ${a.field} = ${a.filename} (${a.length} bytes)',
        );
      }
    }

    try {
      final request = http.MultipartRequest('POST', Uri.parse(url))
        ..headers['Accept'] = 'application/json'
        ..fields.addAll(fields)
        ..files.addAll(archivos);
      if (token != null && token.isNotEmpty) {
        request.headers[ApiConfig.tokenHeader] = token;
      }
      final streamed = await request.send().timeout(_timeout);
      return _procesar(await http.Response.fromStream(streamed));
    } catch (e) {
      return _sinConexion(e);
    }
  }

  /// POST que devuelve un ARCHIVO (bytes), como el `responseType: 'blob'`
  /// de axios en la web. Se usa para descargar PDFs.
  /// status 0 = sin conexión / timeout.
  static Future<({int status, Uint8List bytes})> postBytes(
    String endpoint, {
    Map<String, dynamic>? body,
    bool auth = false,
    String accept = 'application/pdf',
  }) async {
    final url = endpoint.startsWith('http')
        ? endpoint
        : ApiConfig.baseUrl + endpoint;

    String? token;
    if (auth) {
      final user = await AuthService.getUser();
      token = user?['token']?.toString();
    }

    if (kDebugMode) {
      debugPrint('➡️ POST (archivo) $url');
      debugPrint('➡️ BODY: ${jsonEncode(body)}');
    }

    try {
      final res = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': accept,
              if (token != null && token.isNotEmpty)
                ApiConfig.tokenHeader: token,
            },
            body: jsonEncode(body ?? {}),
          )
          .timeout(const Duration(seconds: 60));

      if (kDebugMode) {
        debugPrint('⬅️ STATUS: ${res.statusCode}');
        debugPrint('⬅️ ARCHIVO: ${res.bodyBytes.length} bytes');
      }
      return (status: res.statusCode, bytes: res.bodyBytes);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ ERROR DE CONEXIÓN: $e');
      return (status: 0, bytes: Uint8List(0));
    }
  }

  // ------------------------------------------------------------------

  static Future<Map<String, dynamic>> _send(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    final url = endpoint.startsWith('http')
        ? endpoint
        : ApiConfig.baseUrl + endpoint;

    // Sin token: petición normal
    if (!auth) return _request(method, url, body: body);

    final user = await AuthService.getUser();
    final token = user?['token']?.toString() ?? '';
    if (token.isEmpty) {
      if (kDebugMode) debugPrint('➡️ auth-token: ❌ no hay token guardado');
      return _request(method, url, body: body);
    }

    // El token también va en el body (en GET no hay body)
    final bodyConToken = method == 'GET' ? null : {...?body, 'token': token};

    final orden = _formatoOk != null ? [_formatoOk!] : _formatos;
    Map<String, dynamic> res = {};
    for (final formato in orden) {
      res = await _request(
        method,
        url,
        body: bodyConToken,
        authorization: '$formato$token',
      );

      if (res['http_status'] != 401) {
        if (res['http_status'] != 0) _formatoOk = formato;
        return res;
      }

      if (kDebugMode) debugPrint('🔁 401: el servidor no aceptó el token');
    }
    return res;
  }

  /// Hace UNA petición y devuelve el JSON tal cual
  static Future<Map<String, dynamic>> _request(
    String method,
    String url, {
    Map<String, dynamic>? body,
    String? authorization,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (authorization != null) ApiConfig.tokenHeader: authorization,
    };

    // ---- LOG: lo que enviamos (sin contraseñas ni token completo) ----
    if (kDebugMode) {
      final bodyLog = body == null ? null : Map<String, dynamic>.from(body);
      for (final k in ['password', 'pass']) {
        if (bodyLog?.containsKey(k) == true) bodyLog![k] = '***';
      }
      final t = bodyLog?['token']?.toString();
      if (t != null && t.length > 15) {
        bodyLog!['token'] = '${t.substring(0, 15)}...';
      }
      debugPrint('➡️ $method $url');
      debugPrint('➡️ BODY: ${jsonEncode(bodyLog)}');
      if (authorization != null) {
        final a = authorization;
        debugPrint(
          '➡️ auth-token: "${a.substring(0, a.length < 30 ? a.length : 30)}..."',
        );
      }
    }

    try {
      final request = http.Request(method, Uri.parse(url))
        ..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);

      final streamed = await request.send().timeout(_timeout);
      return _procesar(await http.Response.fromStream(streamed));
    } catch (e) {
      return _sinConexion(e);
    }
  }

  /// Convierte la respuesta en Map y añade 'ok' y 'http_status'
  static Map<String, dynamic> _procesar(http.Response res) {
    // ---- LOG: lo que devuelve el servidor, tal cual ----
    if (kDebugMode) {
      debugPrint('⬅️ STATUS: ${res.statusCode}');
      debugPrint('⬅️ RESPUESTA: ${res.body}');
    }

    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(res.body);
      data = decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    } catch (_) {
      if (kDebugMode) debugPrint('⚠️ La respuesta NO es JSON');
      data = {};
    }

    data['ok'] = res.statusCode >= 200 && res.statusCode < 300;
    data['http_status'] = res.statusCode;
    return data;
  }

  static Map<String, dynamic> _sinConexion(Object e) {
    if (kDebugMode) debugPrint('❌ ERROR DE CONEXIÓN: $e');
    return {
      'ok': false,
      'http_status': 0,
      'error': 'No se pudo conectar con el servidor.',
      'detalle': e.toString(),
    };
  }
}
