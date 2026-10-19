/// Reglas de fichaje (las mismas que calendario.js).
class HorasReglas {
  /// Máximo de minutos por día (turnos + eventos).
  /// calendario.js: 510 (8:30 h) de lunes a jueves y 480 (8:00 h) el viernes.
  static int limiteMinutos(DateTime dia) =>
      dia.weekday == DateTime.friday ? 480 : 510;

  /// Horas permitidas (min="07:00" y max="19:00" de los inputs del HTML)
  static const int horaMinima = 7 * 60;
  static const int horaMaxima = 19 * 60;

  /// Sábado y domingo no se pueden fichar
  static bool esLaborable(DateTime dia) =>
      dia.weekday != DateTime.saturday && dia.weekday != DateTime.sunday;

  /// Devuelve null si la franja es válida, o el mensaje de error.
  /// [editandoId]: id del turno que se está modificando (se excluye de la suma).
  static String? validar({
    required DateTime dia,
    required int inicio,
    required int fin,
    required List<Map<String, dynamic>> turnos,
    required List<Map<String, dynamic>> eventos,
    String? editandoId,
  }) {
    if (inicio < horaMinima) {
      return 'La hora de inicio no puede ser antes de las ${minutosAHora(horaMinima)}.';
    }
    if (fin > horaMaxima) {
      return 'La hora final no puede ser después de las ${minutosAHora(horaMaxima)}.';
    }
    if (fin <= inicio) {
      return 'La hora final tiene que ser posterior a la de inicio.';
    }

    final otros = turnos.where((t) => '${t['id']}' != editandoId).toList();

    // Solape con otros turnos del mismo día
    for (final t in otros) {
      if (inicio < t['fin'] && fin > t['inicio']) {
        return 'Se solapa con el turno de ${minutosAHora(t['inicio'])} a ${minutosAHora(t['fin'])}.';
      }
    }

    // Solape con permisos (rangoInvalido en calendario.js)
    final desde = _enDia(dia, inicio);
    final hasta = _enDia(dia, fin);
    for (final e in eventos) {
      if (e['tipo_evento'] != 'PER') continue;
      final pInicio = DateTime.tryParse('${e['fecha_inicio']}');
      final pFin = DateTime.tryParse('${e['fecha_fin']}');
      if (pInicio == null || pFin == null) continue;
      if (desde.isBefore(pFin) && hasta.isAfter(pInicio)) {
        return 'Ese horario coincide con un permiso.';
      }
    }

    // Límite diario
    final limite = limiteMinutos(dia);
    final usados = sumaMinutos(otros, eventos);
    final restante = limite - usados;
    if (fin - inicio > restante) {
      return restante <= 0
          ? 'Ya has llegado al máximo de ${minutosAHora(limite)} h de este día.'
          : 'Te pasas del máximo de ${minutosAHora(limite)} h. Te quedan ${minutosAHora(restante)} h.';
    }
    return null;
  }

  /// Plantillas de horario: lista de [inicio, fin] en minutos.
  ///   Normal  -> lunes a jueves 08:00-14:00 y 15:00-17:15, viernes 08:00-15:00
  ///   Verano  -> todos los días 07:00-15:00
  static List<List<int>> plantilla(DateTime dia, {bool verano = false}) {
    if (verano) {
      return [
        [7 * 60, 15 * 60],
      ];
    }
    if (dia.weekday == DateTime.friday) {
      return [
        [8 * 60, 15 * 60],
      ];
    }
    return [
      [8 * 60, 14 * 60],
      [15 * 60, 17 * 60 + 15],
    ];
  }

  /// Valida varios turnos nuevos a la vez (los de la plantilla).
  /// Cada uno se comprueba contra los registros del día MÁS los anteriores
  /// de la lista, así el máximo diario cuenta todos juntos.
  static String? validarVarios({
    required DateTime dia,
    required List<List<int>> nuevos,
    required List<Map<String, dynamic>> turnos,
    required List<Map<String, dynamic>> eventos,
  }) {
    if (nuevos.isEmpty) return 'Selecciona al menos un turno.';
    final acumulados = [...turnos];
    for (var i = 0; i < nuevos.length; i++) {
      final inicio = nuevos[i][0];
      final fin = nuevos[i][1];
      final error = validar(
        dia: dia,
        inicio: inicio,
        fin: fin,
        turnos: acumulados,
        eventos: eventos,
      );
      if (error != null) {
        return '${minutosAHora(inicio)} – ${minutosAHora(fin)}: $error';
      }
      acumulados.add({
        'id': 'plantilla_$i',
        'inicio': inicio,
        'fin': fin,
        'minutos': fin - inicio,
      });
    }
    return null;
  }

  static DateTime _enDia(DateTime dia, int minutos) =>
      DateTime(dia.year, dia.month, dia.day, minutos ~/ 60, minutos % 60);
}

// ------------------------------------------------------------------
// Utilidades
// ------------------------------------------------------------------

/// Minutos usados en el día: turnos + eventos (como calendario.js)
int sumaMinutos(
  List<Map<String, dynamic>> turnos,
  List<Map<String, dynamic>> eventos,
) =>
    turnos.fold<int>(0, (s, t) => s + (t['minutos'] as int)) +
    eventos.fold<int>(0, (s, e) => s + aEntero(e['suma_minutos']));

/// true si algún evento bloquea el día (blok_day)
bool diaBloqueado(List<Map<String, dynamic>> eventos) => eventos.any((e) {
  final b = e['blok_day'];
  return b == true || b == 1 || b == '1';
});

/// Texto de un campo del JSON, o null si viene vacío
String? texto(dynamic v) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty || s == 'null' ? null : s;
}

/// "08:30" o "08:30:00" -> 510
int horaAMinutos(String hhmm) {
  final p = hhmm.split(':');
  if (p.length < 2) return 0;
  return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
}

/// 510 -> "08:30"
String minutosAHora(int minutos) {
  final h = (minutos ~/ 60).toString().padLeft(2, '0');
  final m = (minutos % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

int aEntero(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

DateTime soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

String _dos(int n) => n.toString().padLeft(2, '0');

/// 2026-10-15
String fechaIso(DateTime d) => '${d.year}-${_dos(d.month)}-${_dos(d.day)}';

/// 2026-10
String mesYear(DateTime d) => '${d.year}-${_dos(d.month)}';
