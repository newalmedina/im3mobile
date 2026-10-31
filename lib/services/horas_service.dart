import '../config/api.dart';
import '../utils/horas_reglas.dart';
import 'api_service.dart';

class HorasException implements Exception {
  final String mensaje;
  HorasException(this.mensaje);
  @override
  String toString() => mensaje;
}

/// Llamadas a la API de horas (las mismas que calendario.js).
/// Si algo falla lanza HorasException con un mensaje para el usuario.
class HorasService {
  /// Tipos de cada día del mes: {'2026-10-15': {'laboral', 'PER'}, ...}
  static Future<Map<String, Set<String>>> getMes(DateTime mes) =>
      _seguro(() async {
    final res = await ApiService.get(
      _url(ApiConfig.horasMes, {'mesYear': mesYear(mes)}),
      auth: true,
    );
    final dias = <String, Set<String>>{};
    for (final item in _lista(res)) {
      if (item is! Map) continue;
      final fecha = item['fecha']?.toString() ?? '';
      if (fecha.length < 10) continue;
      dias.putIfAbsent(fecha.substring(0, 10), () => {}).add('${item['tipo']}');
    }
    return dias;
  });

  /// Turnos del día, tal cual vienen del servidor, más tres claves
  /// que añade este servicio para no tener que calcularlas en la pantalla:
  ///   'inicio'  -> minutos desde las 00:00 (de hora_inicio)
  ///   'fin'     -> minutos desde las 00:00 (de hora_final)
  ///   'minutos' -> duración del turno
  static Future<List<Map<String, dynamic>>> getTurnos(DateTime dia) =>
      _seguro(() async {
    final res = await ApiService.get(
      _url(ApiConfig.horasTurnosDia, {'fecha': fechaIso(dia)}),
      auth: true,
    );
    final turnos = <Map<String, dynamic>>[];
    for (final t in _mapas(res)) {
      final inicio = _aMinutos(t['hora_inicio']);
      final fin = _aMinutos(t['hora_final']);
      // Un turno con horas raras o vacías no debe tumbar la pantalla
      if (inicio == null || fin == null) continue;
      t['inicio'] = inicio;
      t['fin'] = fin;
      t['minutos'] = fin - inicio;
      turnos.add(t);
    }
    turnos.sort((a, b) => (a['inicio'] as int).compareTo(b['inicio'] as int));
    return turnos;
  });

  /// Acepta "08:00", "08:00:00" o "1970-01-01T08:00:00". Null si no se entiende.
  static int? _aMinutos(dynamic valor) {
    if (valor == null) return null;
    final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(
      valor.toString().split('T').last,
    );
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    if (h > 23 || min > 59) return null;
    return h * 60 + min;
  }

  /// Vacaciones, permisos, bajas, festivos del día (tal cual del servidor)
  static Future<List<Map<String, dynamic>>> getEventos(DateTime dia) =>
      _seguro(() async {
    final res = await ApiService.get(
      _url(ApiConfig.horasEventosDia, {'fecha': fechaIso(dia)}),
      auth: true,
    );
    return _mapas(res);
  });

  static Future<void> crear(DateTime dia, int inicio, int fin) =>
      _seguro(() async {
    final d = fechaIso(
      dia,
    ).replaceAll('-', '/'); // el backend espera YYYY/MM/DD
    final res = await ApiService.post(
      _url(ApiConfig.horasCrear),
      body: {'fecha_toma': d, ..._cuerpo(inicio, fin)},
      auth: true,
    );
    _comprobar(res);
  });

  static Future<void> actualizar(String id, int inicio, int fin) =>
      _seguro(() async {
    final res = await ApiService.patch(
      _url('${ApiConfig.horasActualizar}$id'),
      body: _cuerpo(inicio, fin),
      auth: true,
    );
    _comprobar(res);
  });

  static Future<void> eliminar(String id) =>
      _seguro(() async {
    final res = await ApiService.delete(
      _url('${ApiConfig.horasEliminar}$id'),
      auth: true,
    );
    _comprobar(res);
  });

  // ------------------------------------------------------------------

  static Map<String, dynamic> _cuerpo(int inicio, int fin) => {
    'hora_inicio': minutosAHora(inicio),
    'hora_final': minutosAHora(fin),
    'tipo': 'laboral',
    'suma_horas': minutosAHora(fin - inicio),
    'suma_minutos': fin - inicio,
  };

  static String _url(String ruta, [Map<String, String>? query]) {
    final uri = Uri.parse('${ApiConfig.horasBaseUrl}$ruta');
    return (query == null ? uri : uri.replace(queryParameters: query))
        .toString();
  }

  static List<Map<String, dynamic>> _mapas(Map<String, dynamic> res) => _lista(
    res,
  ).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();

  /// Cualquier fallo que no sea nuestro (JSON raro, timeout, tipos...)
  /// se convierte en HorasException para que la pantalla lo pueda mostrar.
  static Future<T> _seguro<T>(Future<T> Function() llamada) async {
    try {
      return await llamada();
    } on HorasException {
      rethrow;
    } catch (e) {
      throw HorasException('Error inesperado: $e');
    }
  }

  static List _lista(Map<String, dynamic> res) {
    _comprobar(res);
    final data = res['data'];
    return data is List ? data : const [];
  }

  static void _comprobar(Map<String, dynamic> res) {
    final status = res['http_status'];
    if (status == 0) {
      throw HorasException('No se pudo conectar con el servidor.');
    }
    if (status == 401) {
      throw HorasException('Tu sesión no es válida. Vuelve a iniciar sesión.');
    }
    if (res['ok'] != true) {
      final msg = res['mensaje'] ?? res['message'] ?? res['error'];
      throw HorasException(msg?.toString() ?? 'Error del servidor ($status).');
    }
  }
}
