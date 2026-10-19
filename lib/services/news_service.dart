import '../config/api.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'home_service.dart';

/// Llamadas de Noticias (pages/noticias/index.vue y _id.vue de la web).
class NewsService {
  /// PAGE_SIZE de la web
  static const int porPagina = 12;

  static String get _api => '${ApiConfig.intranetBaseUrl}api/';

  // =========================================================
  // LISTADO
  // =========================================================
  /// Una página (sin filtros, scroll infinito).
  /// [tipo]: HomeService.tipoNoticia (por defecto) o tipoComunicado.
  static Future<List<Map<String, dynamic>>> getPagina(
    int inicio, {
    String tipo = HomeService.tipoNoticia,
  }) =>
      HomeService.getPublicaciones(
        tipo: tipo,
        inicio: inicio,
        cantidad: porPagina,
      );

  /// Todas las noticias para el buscador y "Guardados" (cargarBuscador).
  /// Cada una lleva '_search' con el texto de búsqueda ya preparado.
  static Future<List<Map<String, dynamic>>> getTodas({
    String tipo = HomeService.tipoNoticia,
  }) async {
    final lista = await HomeService.getPublicaciones(
      tipo: tipo,
      inicio: 0,
      cantidad: 10000,
    );
    for (final a in lista) {
      final idioma = HomeService.idioma(a) ?? {};
      a['_search'] = [
        idioma['titulo'],
        HomeService.textoPlano(idioma['texto']),
        a['etiquetaslist'],
      ]
          .map((e) => '${e ?? ''}'.trim())
          .where((e) => e.isNotEmpty && e != 'null')
          .join(' ')
          .toLowerCase();
    }
    return lista;
  }

  // =========================================================
  // DETALLE
  // =========================================================
  /// Noticia completa con 'localizedArticle' (getPublicationDetail)
  static Future<Map<String, dynamic>?> getDetalle(String id) async {
    final res = await ApiService.get(
      '${_api}api_publicaciones/v1/publicacion/$id',
      auth: true,
    );
    if (res['ok'] != true) return null;

    final data = res['data'];
    if (data is! List || data.isEmpty || data.first is! Map) return null;
    final p = Map<String, dynamic>.from(data.first as Map);

    final locale = await _locale();
    final idiomas = (p['idiomas'] is List ? p['idiomas'] as List : const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    p['localizedArticle'] = idiomas.firstWhere(
      (e) => '${e['locale']}' == locale,
      orElse: () => idiomas.isNotEmpty ? idiomas.first : <String, dynamic>{},
    );
    return p;
  }

  /// URLs de las imágenes del slider
  static Future<List<String>> getImagenes(String id) async {
    final uri = Uri.parse('${_api}api_files/v1/imagenes_publicacion')
        .replace(queryParameters: {'publicacion_id': id});
    final res = await ApiService.get(uri.toString(), auth: true);
    if (res['codigo'] != 'OK' || res['imagenes'] is! List) return [];

    return (res['imagenes'] as List)
        .whereType<Map>()
        .map((img) => '${img['nombre'] ?? ''}'.trim())
        .where((n) => n.isNotEmpty && n != 'null')
        .map((n) => '${ApiConfig.homePublicacionesImg}$n')
        .toList();
  }

  static Future<bool> esFavorito(String id) async {
    final res = await ApiService.get(
      '${_api}api_visores/v1/favorito/$id',
      auth: true,
    );
    return HomeService.siNo(res['favorito']);
  }

  /// El backend alterna guardado / no guardado.
  /// Devuelve null si ha ido bien, o el motivo del fallo.
  static Future<String?> cambiarFavorito(String id) async {
    final res = await ApiService.patch(
      '${_api}api_visores/v1/favorito/$id',
      body: {},
      auth: true,
    );
    return _fallo(res);
  }

  /// me_gusta / indiferente / no_me_gusta (cambiarOpinion + actualizarOpinion).
  /// Devuelve null si ha ido bien, o el motivo del fallo.
  static Future<String?> opinar(
    String id, {
    required String anterior,
    required String nueva,
  }) async {
    final r1 = await ApiService.patch(
      '${_api}api_visores/v1/opiniones/$id',
      body: {'opinion': nueva},
      auth: true,
    );
    final f1 = _fallo(r1);
    if (f1 != null) return 'visores: $f1';

    final r2 = await ApiService.patch(
      '${_api}api_publicaciones/v1/opiniones/$id',
      body: {'opinion_anterior': anterior, 'opinion_actual': nueva},
      auth: true,
    );
    final f2 = _fallo(r2);
    return f2 == null ? null : 'publicaciones: $f2';
  }

  /// null si la respuesta es 2xx; si no, "HTTP 401 ..." o el error de conexión
  static String? _fallo(Map<String, dynamic> res) {
    if (res['ok'] == true) return null;
    final status = res['http_status'];
    if (status == 0) {
      return 'sin conexión (${res['detalle'] ?? res['error'] ?? ''})';
    }
    final msg = res['message'] ?? res['mensaje'] ?? res['error'] ?? '';
    return 'HTTP $status $msg'.trim();
  }

  static Future<void> marcarVisitado(String id) async {
    final userId = await AuthService.getUserId();
    await ApiService.patch(
      '${_api}api_publicaciones/v1/visitado/$id',
      body: {'usuario': '${userId ?? ''}'},
      auth: true,
    );
  }

  static Future<void> guardarLog() async {
    await ApiService.post(
      '${_api}api_users/v1/guardar_log',
      body: {},
      auth: true,
    );
  }

  static Future<String> _locale() async {
    final user = await AuthService.getUser();
    final l = '${user?['locale'] ?? ''}'.trim();
    return (l.isEmpty || l == 'null') ? 'es' : l;
  }
}
