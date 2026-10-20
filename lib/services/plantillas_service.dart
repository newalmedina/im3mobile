import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_service.dart';

/// Las dos plantillas del empleado: tramos [inicio, fin] en minutos.
class Plantillas {
  final List<List<int>> normal;
  final List<List<int>> verano;

  const Plantillas({required this.normal, required this.verano});

  List<List<int>> de(bool esVerano) => esVerano ? verano : normal;

  Plantillas con(bool esVerano, List<List<int>> tramos) => esVerano
      ? Plantillas(normal: normal, verano: tramos)
      : Plantillas(normal: tramos, verano: verano);

  Map<String, dynamic> toJson() => {'normal': normal, 'verano': verano};
}

/// Plantillas de horario guardadas en el móvil, una por usuario.
///
/// Si el usuario no ha guardado ninguna, se usan las de por defecto.
/// Se guardan en el almacén seguro con una clave propia ("plantillas_<id>"),
/// que el logout no toca: solo borra 'im3_user'.
class PlantillasService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // =========================================================
  // POR DEFECTO
  // =========================================================

  /// Normal: 08:00–14:00 y 15:00–17:15
  static const List<List<int>> normalPorDefecto = [
    [8 * 60, 14 * 60],
    [15 * 60, 17 * 60 + 15],
  ];

  /// Verano: 07:15–15:15 (jornada continua)
  static const List<List<int>> veranoPorDefecto = [
    [7 * 60 + 15, 15 * 60 + 15],
  ];

  static const Plantillas porDefecto = Plantillas(
    normal: normalPorDefecto,
    verano: veranoPorDefecto,
  );

  // =========================================================
  // LEER / GUARDAR
  // =========================================================
  static Future<String> _clave() async {
    final id = await AuthService.getUserId();
    return 'plantillas_${id ?? 'anonimo'}';
  }

  /// Las plantillas del usuario o, si no tiene, las de por defecto
  static Future<Plantillas> cargar() async {
    try {
      final raw = await _storage.read(key: await _clave());
      if (raw == null || raw.isEmpty) return porDefecto;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return Plantillas(
        normal: _leerTramos(json['normal']) ?? normalPorDefecto,
        verano: _leerTramos(json['verano']) ?? veranoPorDefecto,
      );
    } catch (e) {
      debugPrint('No se pudieron leer las plantillas: $e');
      return porDefecto;
    }
  }

  static Future<void> guardar(Plantillas p) async {
    await _storage.write(key: await _clave(), value: jsonEncode(p.toJson()));
  }

  /// Vuelve una plantilla a sus valores por defecto
  static Future<Plantillas> restablecer(Plantillas p, bool esVerano) async {
    final nuevas = p.con(
      esVerano,
      esVerano ? veranoPorDefecto : normalPorDefecto,
    );
    await guardar(nuevas);
    return nuevas;
  }

  /// null si el dato guardado no es una lista de tramos válida
  static List<List<int>>? _leerTramos(dynamic v) {
    if (v is! List || v.isEmpty) return null;
    final tramos = <List<int>>[];
    for (final t in v) {
      if (t is! List || t.length != 2) return null;
      final a = int.tryParse('${t[0]}');
      final b = int.tryParse('${t[1]}');
      if (a == null || b == null) return null;
      tramos.add([a, b]);
    }
    return tramos;
  }
}
