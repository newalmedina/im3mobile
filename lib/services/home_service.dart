import '../config/api.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// Llamadas de los bloques de la Home (los axios / store de la web).
class HomeService {
  /// Tipos de publicación (PUBLICATION_TYPE en la web)
  static const String tipoNoticia = '1';
  static const String tipoComunicado = '2';

  // =========================================================
  // BANNER
  // =========================================================
  /// Devuelve {'imagen': url, 'enlace': url} o null si no hay banner.
  static Future<Map<String, String>?> getBanner() async {
    final res = await ApiService.get(ApiConfig.homeBanner, auth: true);
    if (res['ok'] != true) return null;

    final banner = _limpio(res['selectedBanner']);
    if (banner.isEmpty) return null;

    final version = _limpio(res['fecha_modificacion']);

    return {
      'imagen':
          '${ApiConfig.homeBannerFiles}$banner?v=${Uri.encodeComponent(version)}',
      'enlace': _limpio(res['selectedUrl']),
    };
  }

  // =========================================================
  // PUBLICACIONES (noticias y comunicados)
  // =========================================================
  /// Una página de publicaciones del usuario (getNews / getNotices de la web).
  static Future<List<Map<String, dynamic>>> getPublicaciones({
    required String tipo,
    int inicio = 0,
    int cantidad = 9,
  }) async {
    final idUser = await AuthService.getUserId();
    if (idUser == null) return [];

    final user = await AuthService.getUser();
    final locale = _limpio(user?['locale']).isEmpty
        ? 'es'
        : _limpio(user?['locale']);

    final uri = Uri.parse('${ApiConfig.homeVisorUser}$idUser').replace(
      queryParameters: {
        'locale': locale,
        'tipo': tipo,
        'ini_resultados': '$inicio',
        'num_resultados': '$cantidad',
      },
    );

    final res = await ApiService.get(uri.toString(), auth: true);
    if (res['ok'] != true) return [];

    // ApiService mete las listas en 'data'
    final data = res['data'];
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // =========================================================
  // DESTACADO (pinnedArticle en la web)
  // =========================================================
  /// Primera noticia con idiomas[0].pin. Si no está en la primera página,
  /// sigue buscando (como getNewsPage en la web), hasta [maxPaginas].
  static Future<Map<String, dynamic>?> getDestacado() async {
    const porPagina = 9;
    const maxPaginas = 3;

    for (var p = 0; p < maxPaginas; p++) {
      final lista = await getPublicaciones(
        tipo: tipoNoticia,
        inicio: p * porPagina,
        cantidad: porPagina,
      );

      for (final a in lista) {
        if (_esVerdadero(idioma(a)?['pin'])) return a;
      }

      // No hay más páginas
      if (lista.length < porPagina) break;
    }
    return null;
  }

  // =========================================================
  // AYUDAS
  // =========================================================
  /// Contenido en el idioma del usuario (idiomas[0] en la web)
  static Map<String, dynamic>? idioma(Map<String, dynamic> articulo) {
    final l = articulo['idiomas'];
    if (l is List && l.isNotEmpty && l.first is Map) {
      return Map<String, dynamic>.from(l.first as Map);
    }
    return null;
  }

  /// URL de la imagen destacada (primero la del idioma, si no la general)
  static String? imagenDestacada(Map<String, dynamic> articulo) {
    var nombre = _limpio(idioma(articulo)?['new_imagen_destacada']);
    if (nombre.isEmpty) nombre = _limpio(articulo['new_imagen_destacada']);
    return nombre.isEmpty ? null : '${ApiConfig.homePublicacionesImg}$nombre';
  }

  static String _limpio(dynamic v) {
    final s = '${v ?? ''}'.trim();
    return s == 'null' ? '' : s;
  }

  static bool _esVerdadero(dynamic v) =>
      v == true || '$v' == '1' || '$v'.toLowerCase() == 'true';

  // =========================================================
  // COMUNICADOS (notices.vue en la web)
  // =========================================================
  /// Últimos comunicados (en la home la web pide 3)
  static Future<List<Map<String, dynamic>>> getComunicados({
    int cantidad = 3,
  }) => getPublicaciones(tipo: tipoComunicado, cantidad: cantidad);

  /// ¿Tiene el usuario este permiso? (hasPermission de la web)
  static Future<bool> tienePermiso(String permiso) async {
    final user = await AuthService.getUser();
    final l = user?['permisos'];
    return l is List && l.map((e) => '$e').contains(permiso);
  }

  /// Fecha "13/10/2026" (formatDate de la web)
  static String fecha(dynamic v) {
    final s = _limpio(v);
    final d = DateTime.tryParse(s.replaceFirst(' ', 'T'));
    if (d == null) return s;
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(d.day)}/${dos(d.month)}/${d.year}';
  }

  /// Quita las etiquetas HTML y traduce los acentos (&aacute; -> á...)
  static String textoPlano(dynamic html) {
    var s = _limpio(html)
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]*>'), '');

    const entidades = {
      '&nbsp;': ' ',
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&#39;': "'",
      '&aacute;': 'á',
      '&eacute;': 'é',
      '&iacute;': 'í',
      '&oacute;': 'ó',
      '&uacute;': 'ú',
      '&ntilde;': 'ñ',
      '&Aacute;': 'Á',
      '&Eacute;': 'É',
      '&Iacute;': 'Í',
      '&Oacute;': 'Ó',
      '&Uacute;': 'Ú',
      '&Ntilde;': 'Ñ',
      '&uuml;': 'ü',
      '&iexcl;': '¡',
      '&iquest;': '¿',
      '&ordm;': 'º',
      '&ordf;': 'ª',
      '&euro;': '€',
    };
    entidades.forEach((k, v) => s = s.replaceAll(k, v));
    s = s.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (m) => String.fromCharCode(int.parse(m[1]!)),
    );
    return s.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  /// true / 1 / "1" / "true"
  static bool siNo(dynamic v) => _esVerdadero(v);

  // =========================================================
  // OBJETIVOS
  // =========================================================
  /// Lista de objetivos del usuario (common/getGoals en la web)
  /// GET .../api_users/v1/objetivos/{id_user}
  static Future<List<Map<String, dynamic>>> getObjetivos() async {
    final idUser = await AuthService.getUserId();
    if (idUser == null) return [];

    final res = await ApiService.get(
      '${ApiConfig.homeObjetivos}$idUser',
      auth: true,
    );
    if (res['ok'] != true) return [];

    // ApiService mete las listas en 'data'
    final data = res['data'];
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Cabecera de objetivos del usuario: título, responsable, documento...
  static Future<Map<String, dynamic>?> getObjetivosData() async {
    final idUser = await AuthService.getUserId();
    if (idUser == null) return null;

    final res = await ApiService.get(
      '${ApiConfig.homeObjetivosData}$idUser',
      auth: true,
    );
    // Igual que la web: si no trae id, no hay datos
    if (res['ok'] != true || _limpio(res['id']).isEmpty) return null;
    return Map<String, dynamic>.from(res);
  }

  /// URL del documento adjunto, o null si no hay
  static String? urlDocumentoObjetivos(String documento) {
    final d = _limpio(documento);
    return d.isEmpty ? null : '${ApiConfig.homeObjetivosFiles}$d';
  }

  /// Días desde el último accidente (common/getDaysWithoutAccidents en la web).
  /// Devuelve null si no hay datos o la fecha no se puede leer.
  static Future<int?> getDiasSinAccidentes() async {
    final idUser = await AuthService.getUserId();
    if (idUser == null) return null;

    final res = await ApiService.get(
      '${ApiConfig.homeDiasAccidentes}$idUser',
      auth: true,
    );
    if (res['ok'] != true) return null;

    // Como en el store de la web: el primer registro
    final data = res['data'];
    Map? registro;
    if (data is List && data.isNotEmpty && data.first is Map) {
      registro = data.first as Map;
    } else if (data is Map) {
      registro = data;
    }

    final fecha = _parseFecha('${registro?['fecha_accidente'] ?? ''}');
    if (fecha == null) return null;

    // Se cuentan días naturales (sin horas)
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final dia = DateTime(fecha.year, fecha.month, fecha.day);
    final dias = hoy.difference(dia).inDays;
    return dias < 0 ? 0 : dias;
  }

  /// Acepta "2024-05-12", "2024-05-12 08:30:00" y "12/05/2024"
  static DateTime? _parseFecha(String texto) {
    final t = texto.trim();
    if (t.isEmpty) return null;

    final iso = DateTime.tryParse(t.replaceFirst(' ', 'T'));
    if (iso != null) return iso;

    final partes = t.split(RegExp(r'[/\-.]'));
    if (partes.length >= 3) {
      final d = int.tryParse(partes[0]);
      final m = int.tryParse(partes[1]);
      final a = int.tryParse(partes[2].split(' ').first);
      if (d != null && m != null && a != null) return DateTime(a, m, d);
    }
    return null;
  }

  // =========================================================
  // NUEVAS INCORPORACIONES
  // =========================================================

  static Future<List<Map<String, dynamic>>> getIncorporaciones() async {
    final res = await ApiService.get(ApiConfig.homeIncorporaciones, auth: true);
    if (res['ok'] != true) return [];
    final data = res['data'];
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// URL de la foto de un usuario (o la de "sin foto")
  static String fotoUsuario(dynamic imagen) {
    final img = '${imagen ?? ''}'.trim();
    return '${ApiConfig.fotosUsuarios}'
        '${img.isEmpty ? 'usuario_sin_foto.png' : img}';
  }

  // =========================================================
  // TRABAJADORES
  // =========================================================

  static Future<Map<String, dynamic>?> getTrabajador(String id) async {
    final res = await ApiService.get(
      '${ApiConfig.trabajadorInfo}$id',
      auth: true,
    );
    if (res['ok'] != true) return null;
    return _primerMapa(res['data'] ?? res);
  }

  static Future<List<Map<String, dynamic>>> getCompaneros(String id) async {
    final res = await ApiService.get(
      '${ApiConfig.trabajadorCompaneros}$id',
      auth: true,
    );
    if (res['ok'] != true) return [];
    final data = res['data'];
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<Map<String, dynamic>?> getHorarioSemana(String id) async {
    final res = await ApiService.get(
      '${ApiConfig.trabajadorHorario}$id',
      auth: true,
    );
    if (res['ok'] != true) return null;
    return _primerMapa(res['data'] ?? res);
  }

  /// Si viene una lista coge el primero; si viene un objeto, ese
  static Map<String, dynamic>? _primerMapa(dynamic data) {
    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  /// Documentación de la home (documents.vue en la web). Solo los 3 primeros.
  static Future<List<Map<String, dynamic>>> getDocumentos() async {
    final res = await ApiService.get(
      '${ApiConfig.homeDocumentos}?orderBy=fecha_modificacion',
      auth: true,
    );
    if (res['ok'] != true) return [];

    final data = res['data'];
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .take(3)
        .toList();
  }

  /// Dirección del archivo de un documento (el `file` de DocumentLink).
  /// - URL completa: se usa tal cual.
  /// - Ruta (/intranet/files/... o files/...): se monta sobre el servidor.
  /// Dirección del archivo de un documento:
  /// https://.../intranet/files/docs_wellcome/{nombre_archivo}
  static Uri? urlDocumento(Map<String, dynamic> d) {
    String txt(String campo) {
      final s = '${d[campo] ?? ''}'.trim();
      return s == 'null' ? '' : s;
    }

    // Si el link ya es una URL completa, se usa tal cual
    final link = txt('link');
    if (link.startsWith('http')) return Uri.tryParse(link);

    // Si no, el archivo guardado en el servidor
    var archivo = txt('nombre_archivo');
    if (archivo.isEmpty) archivo = link;
    if (archivo.isEmpty) return null;

    // Por si viniera con la ruta delante, nos quedamos con el nombre
    archivo = archivo.split('/').last;
    return Uri.parse('${ApiConfig.homeDocumentosFiles}$archivo');
  }

  // =========================================================
  // NOTICIAS (latest-news.vue en la web)
  // =========================================================
  /// Últimas noticias del usuario (getNews de la web)
  static Future<List<Map<String, dynamic>>> getNoticias({int cantidad = 3}) =>
      getPublicaciones(tipo: tipoNoticia, cantidad: cantidad);
}
