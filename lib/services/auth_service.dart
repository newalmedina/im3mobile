import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api.dart';
import 'api_service.dart';

/// Login, validación del token, logout y cambio de contraseña.
///   - Login: contra SIGN (devuelve el token)
///   - Validar token: contra la INTRANET (devuelve los datos del usuario:
///     id_user, id_sign, user_full_name, es_responsable, vacaciones...)
class AuthService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _userKey = 'im3_user'; // STORAGE_USER_KEY

  // =========================================================
  // LOGIN: obtiene el token, lo valida y solo entonces deja entrar
  // Devuelve {'success': true} o {'success': false, 'error': '...'}
  // =========================================================
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    if (email.trim().isEmpty || password.isEmpty) {
      return {'success': false, 'error': 'Introduce email y contraseña.'};
    }

    final data = await ApiService.post(
      ApiConfig.login,
      body: {
        'email': email.trim(),
        'password': password,
        'aplicacion': ApiConfig.appSlug,
      },
    );

    // Sin conexión
    if (data['http_status'] == 0) {
      await logout();
      return {
        'success': false,
        'error': 'No se pudo conectar con el servidor.',
      };
    }

    if (data['ok'] != true || data['codigo'] != 'OK' || data['token'] == null) {
      return {'success': false, 'error': 'Credenciales incorrectas.'};
    }

    // 1. Guardar el token (la respuesta tal cual, sin las claves del servicio)
    data.remove('ok');
    data.remove('http_status');
    await _saveUser(data);

    // 2. Validar en la intranet antes de dejar entrar
    final valid = await validateToken();
    if (!valid) {
      return {
        'success': false,
        'error': 'Usuario inactivo o sin acceso a la plataforma.',
      };
    }

    // 3. Válido: validateToken ya guardó todos los datos del usuario
    return {'success': true};
  }

  // =========================================================
  // VALIDAR TOKEN EN LA INTRANET: se llama en cada pantalla (MainLayout)
  // Guarda TODO lo que devuelve la intranet junto al token.
  // =========================================================
  static Future<bool> validateToken() async {
    final stored = await getUser();
    final token = stored?['token'];
    if (stored == null || token == null || token.toString().isEmpty) {
      return false;
    }

    final data = await ApiService.post(
      ApiConfig.validateToken,
      body: {'token': token},
    );

    // Error de red: no echamos al usuario
    if (data['http_status'] == 0) {
      debugPrint('No se pudo validar el token: ${data['detalle']}');
      return true;
    }

    // 401 (token no válido) o 500 (el usuario no existe en la intranet)
    if (data['ok'] != true || data['codigo'] != 'OK') {
      await logout();
      return false;
    }

    // Sin el permiso requerido no puede entrar a la plataforma
    final List<String> permisos = data['permisos'] is List
        ? (data['permisos'] as List).map((e) => e.toString()).toList()
        : [];
    final requerido = ApiConfig.permisoRequerido;
    if (requerido != null && !permisos.contains(requerido)) {
      await logout();
      return false;
    }

    // Guardar todo lo de la intranet (sin las claves que añade ApiService)
    data.remove('ok');
    data.remove('http_status');
    await _saveUser({...stored, ...data, 'permisos': permisos, 'token': token});
    return true;
  }

  // =========================================================
  // USUARIO GUARDADO
  // =========================================================
  static Future<Map<String, dynamic>?> getUser() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Id del usuario en la intranet (en la web es `user.id_user`).
  /// Si todavía no está guardado (sesión anterior a este cambio),
  /// valida el token una vez para traerlo.
  static Future<String?> getUserId() async {
    String? leer(Map<String, dynamic>? u) {
      final v = u?['id_user']?.toString().trim() ?? '';
      return v.isEmpty || v == 'null' ? null : v;
    }

    var id = leer(await getUser());
    if (id == null && await validateToken()) {
      id = leer(await getUser());
    }
    return id;
  }

  static Future<void> _saveUser(Map<String, dynamic> user) =>
      _storage.write(key: _userKey, value: jsonEncode(user));

  static Future<void> logout() => _storage.delete(key: _userKey);

  // =========================================================
  // RECORDAR EMAIL Y CONTRASEÑA
  // =========================================================
  static Future<void> saveCredentials(String email, String password) async {
    await _storage.write(key: 'saved_email', value: email);
    await _storage.write(key: 'saved_pass', value: password);
  }

  static Future<Map<String, String>?> getCredentials() async {
    final email = await _storage.read(key: 'saved_email') ?? '';
    final pass = await _storage.read(key: 'saved_pass') ?? '';
    if (email.isEmpty || pass.isEmpty) return null;
    return {'email': email, 'password': pass};
  }

  static Future<void> clearCredentials() async {
    await _storage.delete(key: 'saved_email');
    await _storage.delete(key: 'saved_pass');
  }

  // =========================================================
  // CAMBIAR CONTRASEÑA (sigue siendo contra SIGN)
  // =========================================================
  static Future<Map<String, dynamic>> updatePassword(String pass) async {
    final data = await ApiService.post(
      ApiConfig.updatePassword,
      body: {'pass': pass},
      auth: true, // el backend usa $this->getUser() -> necesita el token
    );

    if (data['http_status'] == 0) {
      return {
        'success': false,
        'error': 'No se pudo conectar con el servidor.',
      };
    }

    if (data['http_status'] == 401) {
      return {
        'success': false,
        'error': 'Tu sesión no es válida. Vuelve a iniciar sesión.',
      };
    }

    // codigo 2 con HTTP 200 -> misma contraseña que la anterior
    if (data['codigo'].toString() == '2') {
      return {
        'success': false,
        'error':
            data['mensaje'] ?? 'No puedes reutilizar tu contraseña anterior',
      };
    }

    if (data['ok'] != true || data['codigo'] != 'OK') {
      return {'success': false, 'error': 'No se pudo cambiar la contraseña.'};
    }

    // Si tenía "recordar contraseña", actualizarla para el próximo login
    final saved = await getCredentials();
    if (saved != null) await saveCredentials(saved['email']!, pass);

    return {'success': true};
  }
}
