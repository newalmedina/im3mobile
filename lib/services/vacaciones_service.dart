import '../config/api.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// Tipos de vacaciones (campo tipo_vacaciones)
class TipoVacaciones {
  static const String aprobada = '1';
  static const String propuesta = '2';
  static const String denegada = '3';
  static const String pagada = '4'; // compensación descanso

  /// Valor especial del formulario: borrar la solicitud
  static const String borrar = 'delete';
}

/// Llamadas de la página de vacaciones (pages/calendario.vue de la web).
class VacacionesService {
  static String get _api => '${ApiConfig.intranetBaseUrl}api/';

  /// Descarga todo lo que necesita la página (asyncData + created de la web).
  /// Devuelve null si no hay usuario en la sesión.
  static Future<VacacionesDatos?> cargar() async {
    final uid = await AuthService.getUserId();
    if (uid == null || uid.trim().isEmpty) return null;
    final user = await AuthService.getUser() ?? <String, dynamic>{};
    final ano = DateTime.now().year;

    // De dos en dos para no saturar al servidor
    final r1 = await Future.wait([
      ApiService.get(
        '${_api}api_calendarios/v1/calendario/usuario/$uid/ano/$ano',
        auth: true,
      ),
      ApiService.get(
        '${_api}api_calendario_user/v1/tramos/usuario/$uid',
        auth: true,
      ),
    ]);
    final calendario = r1[0]['ok'] == true ? r1[0] : <String, dynamic>{};
    final tramos = _lista(r1[1]);

    var oficina = <String, Map<String, dynamic>>{};
    var usuario = <String, Map<String, dynamic>>{};
    var bajasTramos = <Map<String, dynamic>>[];
    var bajasDias = <String, Map<String, dynamic>>{};

    final calId = _txt(calendario['id']);
    if (calId.isNotEmpty) {
      final uriOficina = Uri.parse(
        '${_api}api_calendarios/v1/fechas_calendario/calendario/$calId',
      ).replace(queryParameters: {
        'mostrar_prev_next_calendar': 'true',
        'user_id': uid,
      });

      final r2 = await Future.wait([
        ApiService.get(uriOficina.toString(), auth: true),
        ApiService.get(
          '${_api}api_calendario_user/v1/usuario/$uid/dos_anos/$ano',
          auth: true,
        ),
      ]);
      oficina = _porFecha(r2[0]);
      usuario = _porFecha(r2[1]);

      final r3 = await Future.wait([
        ApiService.get(
          '${_api}api_bajas/v1/tramos/usuarios_responsable/$uid/dos_anos/$ano',
          auth: true,
        ),
        ApiService.get(
          '${_api}api_bajas/v1/usuario/$uid/dos_anos/$ano',
          auth: true,
        ),
      ]);
      bajasTramos = _lista(r3[0]);
      bajasDias = _porFecha(r3[1]);
    }

    final pais = int.tryParse(_txt(user['pais'])) ?? 0;

    // España: se añaden el 1 y el 6 de enero del año siguiente (como la web)
    if (pais == 1) {
      for (final dia in [1, 6]) {
        oficina[VacacionesDatos.clave(DateTime(ano + 1, 1, dia))] = {
          'descripcion': '',
          'horas_dia': 8.25,
          'id': 0,
          'tipo_festivo': '4',
        };
      }
    }

    // Chile y Brasil: días disfrutados desde la API de RRHH
    double? disfrutadas;
    final email = _txt(user['email']);
    if ((pais == 2 || pais == 5) && email.isNotEmpty) {
      final uri = Uri.parse('${_api}api_chile/v1/rh_workers_holiday_list')
          .replace(queryParameters: {
        'texto_buscador': email,
        'extra_action': 'filtrar_div',
      });
      final res = await ApiService.get(uri.toString(), auth: true);
      final l = _lista(res);
      if (l.isNotEmpty) {
        disfrutadas =
            double.tryParse(_txt(l.first['total_vacaciones_disfrutadas']));
      }
    }

    return VacacionesDatos(
      usuarioId: uid,
      user: user,
      pais: pais,
      calendario: calendario,
      oficina: oficina,
      usuario: usuario,
      tramos: tramos,
      bajasTramos: bajasTramos,
      bajasDias: bajasDias,
      disfrutadasRemoto: disfrutadas,
    );
  }

  /// Crea una fecha por cada cuerpo (POST .../fechas, uno por día como la web)
  static Future<String?> crearFechas(List<Map<String, dynamic>> cuerpos) async {
    var fallos = 0;
    String? motivo;
    for (final b in cuerpos) {
      final res = await ApiService.post(
        '${_api}api_calendario_user/v1/fechas',
        body: b,
        auth: true,
      );
      if (res['ok'] != true) {
        fallos++;
        motivo ??= _motivo(res);
      }
    }
    return fallos == 0 ? null : '$fallos de ${cuerpos.length} días ($motivo)';
  }

  /// Borra las fechas de una solicitud (DELETE .../fechas/{id})
  static Future<String?> borrarFechas(List<String> ids) async {
    var fallos = 0;
    String? motivo;
    for (final id in ids) {
      final res = await ApiService.delete(
        '${_api}api_calendario_user/v1/fechas/$id',
        auth: true,
      );
      if (res['ok'] != true) {
        fallos++;
        motivo ??= _motivo(res);
      }
    }
    return fallos == 0 ? null : '$fallos de ${ids.length} días ($motivo)';
  }

  // ------------------------------------------------------------- ayudas
  static String _motivo(Map<String, dynamic> res) {
    final s = res['http_status'];
    if (s == 0) return 'sin conexión';
    return 'HTTP $s';
  }

  static String _txt(dynamic v) {
    final s = '${v ?? ''}'.trim();
    return s == 'null' ? '' : s;
  }

  /// Respuesta en forma de lista (ApiService la deja en 'data')
  static List<Map<String, dynamic>> _lista(Map<String, dynamic> res) {
    if (res['ok'] != true) return [];
    final d = res['data'];
    if (d is! List) return [];
    return d
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Respuesta en forma de objeto { "2026/10/19": {...}, ... }
  /// (si el servidor manda [] cuando está vacío, queda vacío)
  static Map<String, Map<String, dynamic>> _porFecha(
    Map<String, dynamic> res,
  ) {
    final out = <String, Map<String, dynamic>>{};
    if (res['ok'] != true) return out;
    final fecha = RegExp(r'^\d{4}/\d{2}/\d{2}$');
    res.forEach((k, v) {
      if (fecha.hasMatch(k) && v is Map) {
        out[k] = Map<String, dynamic>.from(v);
      }
    });
    return out;
  }
}

/// Todos los datos de la página y los cálculos de la web
/// (getTipoDia, checkFestivo, calcularDiasTramo, disponibles...).
class VacacionesDatos {
  VacacionesDatos({
    required this.usuarioId,
    required this.user,
    required this.pais,
    required this.calendario,
    required this.oficina,
    required this.usuario,
    required this.tramos,
    required this.bajasTramos,
    required this.bajasDias,
    required this.disfrutadasRemoto,
  });

  final String usuarioId;
  final Map<String, dynamic> user;

  /// 1 = España, 2 = Chile, 5 = Brasil...
  final int pais;
  final Map<String, dynamic> calendario;

  /// fechas_calendario: festivos y horas de la oficina, por 'YYYY/MM/DD'
  final Map<String, Map<String, dynamic>> oficina;

  /// fechas_calendario_user: días pedidos por el usuario, por 'YYYY/MM/DD'
  final Map<String, Map<String, dynamic>> usuario;

  /// Tramos de vacaciones (tabla)
  final List<Map<String, dynamic>> tramos;

  /// Tramos de baja (tabla)
  final List<Map<String, dynamic>> bajasTramos;

  /// Días de baja, por 'YYYY/MM/DD'
  final Map<String, Map<String, dynamic>> bajasDias;

  /// Chile / Brasil: total_vacaciones_disfrutadas de RRHH
  final double? disfrutadasRemoto;

  static int get anoActual => DateTime.now().year;

  bool get esChile => pais == 2;
  bool get esBrasil => pais == 5;

  bool get tieneCalendario => _txt(calendario['id']).isNotEmpty;
  bool get publicado => _txt(calendario['publicado']) == '1';
  String get descripcion => _txt(calendario['descripcion']);

  double get diasVacaciones => _num(user['dias_vacaciones']);
  double get diasPendientes => _num(user['dias_vacaciones_pendientes']);
  double get totalVacaciones => diasVacaciones + diasPendientes;

  // ------------------------------------------------------------ fechas
  static String clave(DateTime d) =>
      '${d.year}/${_dos(d.month)}/${_dos(d.day)}';

  static String corta(DateTime d) =>
      '${_dos(d.day)}/${_dos(d.month)}/${d.year}';

  /// "2026-07-01T00:00:00+02:00" o "2026/07/01" -> 2026-07-01 (sin zona)
  static DateTime? fecha(dynamic v) {
    final s = _txt(v);
    if (s.length < 10) return null;
    final p = s.substring(0, 10).replaceAll('/', '-').split('-');
    if (p.length != 3) return null;
    final y = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  static bool laborable(DateTime d) =>
      d.weekday != DateTime.saturday && d.weekday != DateTime.sunday;

  /// pretyRange de la web
  static String rango(dynamic ini, dynamic fin) {
    final a = fecha(ini), b = fecha(fin);
    if (a == null) return '';
    if (b == null || a == b) return corta(a);
    return '(${corta(a)} - ${corta(b)})';
  }

  /// Días laborables (L-V) entre dos fechas, ambas incluidas, como claves
  static List<String> diasLaborables(DateTime ini, DateTime fin) {
    final out = <String>[];
    for (var d = ini; !d.isAfter(fin); d = DateTime(d.year, d.month, d.day + 1)) {
      if (laborable(d)) out.add(clave(d));
    }
    return out;
  }

  // ---------------------------------------------------------- festivos
  /// checkFestivo de la web. Devuelve:
  ///   ''    -> no es festivo
  ///   '3'.. -> tipo de festivo
  ///   null  -> el día existe pero sin tipo (la web lo trata distinto
  ///            según dónde, por eso se conserva)
  String? checkFestivo(String k) {
    final e = oficina[k];
    if (e == null) return '';
    final tf = e['tipo_festivo'];
    if (tf == null) return null;
    final s = '$tf';
    return (s != '2' && s != '1') ? s : '';
  }

  /// Para contar días: solo cuenta si checkFestivo es '' (getTipoDia)
  bool sinFestivoEstricto(String k) => checkFestivo(k) == '';

  /// Para validar y enviar: cuenta si es '' o null (checkMaxDaysRequested)
  bool sinFestivo(String k) {
    final f = checkFestivo(k);
    return f == null || f.isEmpty;
  }

  /// checkVacaciones de la web (usado en calcularDiasTramo)
  bool _checkVacaciones(String k) {
    final e = usuario[k];
    if (e == null) return true;
    final tf = _txt(e['tipo_festivo']);
    if (tf.isEmpty) return true;
    return tf == '2' || tf == '1';
  }

  /// Días de un tramo (calcularDiasTramo)
  int diasTramo(dynamic ini, dynamic fin) {
    final a = fecha(ini), b = fecha(fin);
    if (a == null || b == null) return 0;
    return diasLaborables(a, b).where(_checkVacaciones).length;
  }

  /// Horas del día en el calendario de la oficina (8.25 se muestra 8.15)
  String horasDia(String k) {
    final h = oficina[k]?['horas_dia'];
    if (h == null) return '';
    final v = double.tryParse('$h');
    if (v == null) return '';
    if (v == 8.25) return '8.15';
    return _fmt(v);
  }

  // ------------------------------------------------------------ conteos
  /// getTipoDia (solo año actual) / getTipoDiaChile (todos los años)
  int tipoDia(String tipo, {bool soloAnoActual = true}) {
    var total = 0;
    usuario.forEach((k, e) {
      if (soloAnoActual && _txt(e['ano_solicitud']) != '$anoActual') return;
      if (_txt(e['tipo_vacaciones']) != tipo) return;
      if (!sinFestivoEstricto(k)) return;
      total++;
    });
    return total;
  }

  int get propuestas => tipoDia(TipoVacaciones.propuesta);
  int get aprobadas => tipoDia(TipoVacaciones.aprobada);
  int get pagadas => tipoDia(TipoVacaciones.pagada);
  int get propuestasChile =>
      tipoDia(TipoVacaciones.propuesta, soloAnoActual: false);

  /// Resto de países
  double get disponibles =>
      totalVacaciones - (aprobadas + propuestas + pagadas);

  // Chile / Brasil
  double get acumuladas => _red(diasVacaciones);

  double get disfrutadas {
    if (disfrutadasRemoto != null) return disfrutadasRemoto!;
    // Método antiguo: días L-V de los tramos aprobados
    var t = 0;
    for (final tr in tramos) {
      if (_txt(tr['tipo_vacaciones']) != TipoVacaciones.aprobada) continue;
      final a = fecha(tr['tramo_fecha_ini']), b = fecha(tr['tramo_fecha_fin']);
      if (a != null && b != null) t += diasLaborables(a, b).length;
    }
    return t.toDouble();
  }

  double get disponiblesChile => _red(diasVacaciones - disfrutadas);
  double get disponiblesBrasil =>
      _red(diasVacaciones - disfrutadas - propuestasChile);

  // ------------------------------------------------------------- tablas
  /// Años de solicitud disponibles, del más reciente al más antiguo
  List<int> get anosTramos {
    final s = <int>{};
    for (final t in tramos) {
      final y = int.tryParse(_txt(t['ano_solicitud']).padRight(4).substring(0, 4).trim());
      if (y != null) s.add(y);
    }
    return s.toList()..sort((a, b) => b.compareTo(a));
  }

  List<Map<String, dynamic>> tramosDelAno(int ano) => tramos
      .where((t) => _txt(t['ano_solicitud']).contains('$ano'))
      .toList();

  // ---------------------------------------------------------- solicitud
  /// Comprobaciones antes de enviar (handleSubmitDates).
  /// Devuelve el mensaje de error o null si se puede enviar.
  String? validar(List<String> fechas, String tipo) {
    if (fechas.isEmpty) return 'El rango no tiene días laborables.';
    if (tipo == TipoVacaciones.borrar) return null;

    final validas = fechas.where(sinFestivo).length;
    if (esBrasil) {
      if (validas > disponiblesBrasilAnoActual) {
        return 'No tienes suficientes días disponibles.';
      }
    } else if (aprobadas + propuestas + validas > totalVacaciones) {
      return 'No tienes suficientes días disponibles.';
    }

    for (final f in fechas) {
      final e = usuario[f];
      if (e != null && _txt(e['tipo_vacaciones']) != TipoVacaciones.denegada) {
        return 'Algunas fechas ya están incluidas en otros rangos. '
            'Selecciona un rango sin coincidencias.';
      }
    }

    for (final f in fechas) {
      if (bajasDias.containsKey(f)) {
        return 'Algunas fechas coinciden con días de baja.';
      }
    }
    return null;
  }

  double get disponiblesBrasilAnoActual => disponiblesChile - propuestasChile;

  /// Cuerpos del POST, uno por día (enviarFechas)
  List<Map<String, dynamic>> cuerposSolicitud({
    required List<String> fechas,
    required DateTime ini,
    required DateTime fin,
    required String tipo,
  }) {
    var disp = esBrasil
        ? disponiblesBrasilAnoActual
        : totalVacaciones - (aprobadas + propuestas);

    return [
      for (final f in fechas)
        () {
          final String ano;
          if (disp > 0) {
            ano = '$anoActual';
            final d = fecha(f);
            if (d != null && laborable(d) && sinFestivo(f)) disp--;
          } else {
            ano = '${anoActual + 1}';
          }
          final festivo = checkFestivo(f);
          return <String, dynamic>{
            'usuario_id': usuarioId,
            'fecha': f,
            'tramo_fecha_ini': clave(ini),
            'tramo_fecha_fin': clave(fin),
            'tipo_vacaciones': tipo,
            if (festivo != null) 'tipo_festivo': festivo,
            'ano_solicitud': ano,
          };
        }(),
    ];
  }

  /// Ids de los días a borrar
  List<String> idsDe(List<String> fechas) => [
        for (final f in fechas)
          if (usuario[f] != null && _txt(usuario[f]!['id']).isNotEmpty)
            _txt(usuario[f]!['id']),
      ];

  // ------------------------------------------------------------- ayudas
  static String _txt(dynamic v) {
    final s = '${v ?? ''}'.trim();
    return s == 'null' ? '' : s;
  }

  static double _num(dynamic v) => double.tryParse(_txt(v)) ?? 0;
  static double _red(double v) => (v * 100).round() / 100;
  static String _dos(int n) => n.toString().padLeft(2, '0');

  /// 22.0 -> "22", 3.5 -> "3.5"
  static String _fmt(double v) => v == v.roundToDouble()
      ? v.toInt().toString()
      : v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');

  static String numero(double v) => _fmt(v);
}
