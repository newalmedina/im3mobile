import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Tipos de biometría que se ofrecen en el login
enum TipoBiometria { huella, cara }

/// Acceso con huella / reconocimiento facial.
///
/// IMPORTANTE: los datos de la biometría se guardan en un almacén SEPARADO
/// del de la sesión (otro fichero en Android, otra cuenta en iOS).
/// Así, aunque el logout borre todo el almacén de la sesión
/// (por ejemplo con deleteAll()), la biometría sigue activada.
///
/// Cómo funciona:
///   1. El usuario entra con email y contraseña.
///   2. Se le ofrece activar la biometría. Si acepta (y confirma con su
///      huella o cara), el email y la contraseña se guardan CIFRADOS.
///   3. Al abrir el login, si está activada, se pide la huella/cara
///      automáticamente y, si es correcta, se hace el login.
///   4. Cada vez que entra con email y contraseña, los datos guardados
///      se reemplazan por los nuevos.
class BiometriaService {
  static final LocalAuthentication _auth = LocalAuthentication();

  // Almacén propio, que el logout no toca
  // Claves propias (bio_...): el logout solo borra 'im3_user', no las toca
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const _kEmail = 'bio_email';
  static const _kPassword = 'bio_password';
  static const _kNoPreguntar = 'bio_no_preguntar';

  /// Qué biometría tiene el móvil configurada (vacío si ninguna o en web)
  static Future<Set<TipoBiometria>> tiposDisponibles() async {
    if (kIsWeb) return {};
    try {
      final soportado = await _auth.isDeviceSupported();
      final puede = await _auth.canCheckBiometrics;
      if (!soportado || !puede) return {};

      final tipos = await _auth.getAvailableBiometrics();
      final out = <TipoBiometria>{};
      if (tipos.contains(BiometricType.fingerprint)) {
        out.add(TipoBiometria.huella);
      }
      if (tipos.contains(BiometricType.face)) {
        out.add(TipoBiometria.cara);
      }
      // Muchos Android no dicen cuál tienen, solo "strong" / "weak".
      // En ese caso se ofrece la huella (el sistema usará la que tenga).
      if (out.isEmpty &&
          (tipos.contains(BiometricType.strong) ||
              tipos.contains(BiometricType.weak))) {
        out.add(TipoBiometria.huella);
      }
      return out;
    } on PlatformException catch (e) {
      debugPrint('Biometría no disponible: $e');
      return {};
    }
  }

  /// Pide la huella o la cara. true si es correcta.
  static Future<bool> autenticar(TipoBiometria tipo) async {
    try {
      return await _auth.authenticate(
        localizedReason: tipo == TipoBiometria.cara
            ? 'Mira a la cámara para entrar en IM3'
            : 'Pon tu huella para entrar en IM3',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Error de biometría: $e');
      return false;
    }
  }

  /// ¿Tiene guardados los datos para entrar con biometría?
  static Future<bool> activado() async {
    try {
      final email = await _storage.read(key: _kEmail);
      return email != null && email.isNotEmpty;
    } catch (e) {
      debugPrint('Error leyendo biometría: $e');
      return false;
    }
  }

  /// Guarda (o reemplaza) los datos de acceso biométrico
  static Future<void> activar(String email, String password) async {
    await _storage.write(key: _kEmail, value: email);
    await _storage.write(key: _kPassword, value: password);
    await _storage.delete(key: _kNoPreguntar);
  }

  static Future<void> desactivar() async {
    await _storage.delete(key: _kEmail);
    await _storage.delete(key: _kPassword);
  }

  static Future<Map<String, String>?> credenciales() async {
    final email = await _storage.read(key: _kEmail);
    final password = await _storage.read(key: _kPassword);
    if (email == null || password == null) return null;
    return {'email': email, 'password': password};
  }

  /// "No volver a preguntar" al hacer login normal
  static Future<bool> noPreguntar() async =>
      (await _storage.read(key: _kNoPreguntar)) == '1';

  static Future<void> setNoPreguntar() =>
      _storage.write(key: _kNoPreguntar, value: '1');
}
