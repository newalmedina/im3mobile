class ApiConfig {
  // =========================================================
  // HOST COMÚN (cambia solo esto para pasar de entorno)
  // =========================================================
  static const String host = "https://dev.im3solutions.com/"; // PRODUCCIÓN
  // static const String host = "http://local.com/"; // LOCAL

  // =========================================================
  // API DE USUARIOS (sign)
  // =========================================================
  static const String baseUrl = "${host}sign/api";

  // Auth
  static const String login = "/api_users/v1/login"; // LOGIN_URL

  /// Validación del token contra la INTRANET (trae id_user, id_sign, etc.)
  static const String validateToken =
      "${intranetBaseUrl}api/api_users/v1/token";

  /// Nombre de esta app (APP_SLUG).
  /// Se manda en el login (campo "aplicacion", sale en los logs)
  /// y al validar el token (campo "app").
  static const String appSlug = "im3_mobile";

  /// Permiso que debe tener el usuario para entrar.
  /// OJO: el endpoint /token actual NO devuelve "permisos".
  /// Si el backend no los manda, pon null o nadie podrá entrar.
  static const String? permisoRequerido = null;

  static const String updatePassword = "/api_users/v1/update_password";

  /// Nombre de la cabecera donde va el token.
  static const String tokenHeader = "auth-token";

  // =========================================================
  // API DE HORAS (la misma que usa calendario.js en la web)
  // =========================================================

  /// Debe terminar en "/" porque las rutas empiezan por "api/...".
  static const String horasBaseUrl = "${host}im3horas/";

  // GET ?mesYear=YYYY-MM  -> [{fecha, tipo}] para pintar el mes
  static const String horasMes = "api/api_fechas/v1/new_fecha_rango";

  // GET ?fecha=YYYY-MM-DD -> turnos fichados del día
  static const String horasTurnosDia = "api/api_fechas/v1/get_fechas_by_day";

  // GET ?fecha=YYYY-MM-DD -> vacaciones, permisos, bajas, festivos del día
  static const String horasEventosDia =
      "api/api_user_calendar/v1/get_user_calendar_by_day";

  // POST crear turno
  static const String horasCrear = "api/api_fechas/v1/fecha";

  // PATCH .../{id}
  static const String horasActualizar = "api/api_fechas/v1/update_fecha/";

  // DELETE .../{id}
  static const String horasEliminar = "api/api_fechas/v1/delete_fecha/";

  // =========================================================
  // API DE LA INTRANET (permisos.vue en la web)
  // =========================================================

  /// En la web es `process.env.baseBackUrl + '/intranet/'`.
  /// Debe terminar en "/" porque las rutas empiezan por "api/...".
  static const String intranetBaseUrl = "${host}intranet/";

  // GET  .../{id_user}?estado=&autorizacion=solicitar -> lista de permisos
  // POST ...            (multipart) -> crear permiso
  // DELETE .../{id}     -> eliminar permiso
  static const String permisos = "api/api_permisos/v1/permisos";

  // GET .../{id_user} -> lista de nóminas  (⚠️ CONFIRMAR RUTA)
  static const String nominas = "api/api_users/v1/nominas";

  // POST { archivo_id } -> PDF de la nómina
  static const String descargarArchivo = "api/api_users/v1/descargar_archivo";

  // =========================================================
  // HOME
  // =========================================================
  // GET -> {selectedBanner, selectedUrl, fecha_modificacion}
  static const String homeBanner =
      "${intranetBaseUrl}api/api_banner/v1/get-banner";

  // Carpeta donde están las imágenes del banner
  static const String homeBannerFiles = "${intranetBaseUrl}files/banner/";

  // GET .../{id_user}?locale=&tipo=&ini_resultados=&num_resultados=
  // tipo 1 = noticias, 2 = comunicados
  static const String homeVisorUser =
      "${intranetBaseUrl}api/api_visores/v1/visor_user/";

  // Carpeta de las imágenes de las publicaciones
  static const String homePublicacionesImg =
      "${intranetBaseUrl}img/publicaciones_imagenes/";

  // =========================================================
  // OBJETIVOS (goals.vue y objetivos.vue en la web)
  // =========================================================
  // GET .../{id_user} -> lista de objetivos [{id, texto_objetivo, ...}]
  static const String homeObjetivos =
      "${intranetBaseUrl}api/api_users/v1/objetivos/";

  // GET .../{id_user} -> {id, titulo, responsable, mes, ano, documento, nombre_documento}
  static const String homeObjetivosData =
      "${intranetBaseUrl}api/api_users/v1/objetivosData/";

  // Carpeta de los documentos adjuntos
  static const String homeObjetivosFiles = "${intranetBaseUrl}files/objetivos/";

  static const String homeDiasAccidentes =
      "${intranetBaseUrl}api/api_users/v1/diasAccidentes/";

  // =========================================================
  // NUEVAS INCORPORACIONES (incorporaciones.vue en la web)
  // =========================================================
  // GET -> [{id, nombre, division, imagen}]
  // =========================================================
  // NUEVAS INCORPORACIONES (incorporaciones.vue en la web)
  // =========================================================
  static const String homeIncorporaciones =
      "${intranetBaseUrl}api/api_users/v1/incorporaciones";

  // Carpeta de las fotos de los usuarios
  static const String fotosUsuarios = "${intranetBaseUrl}img/user_imagenes/";

  // =========================================================
  // TRABAJADORES (pages/workers/_id.vue en la web)
  // =========================================================
  static const String trabajadorInfo =
      "${intranetBaseUrl}api/api_users/v1/info_user/";

  static const String trabajadorCompaneros =
      "${intranetBaseUrl}api/api_users/v1/empleadoDiv/";

  static const String trabajadorHorario =
      "${intranetBaseUrl}api/api_users/v1/api_user/get_usuario_horas_semana/";

  // =========================================================
  // DOCUMENTACIÓN (documents.vue en la web)
  // =========================================================
  // GET ?orderBy=fecha_modificacion
  // -> [{id, nombre, link, fecha_modificacion, nombre_archivo, nombre_archivo_original}]
  static const String homeDocumentos =
      "${intranetBaseUrl}api/api_doc_wellcome/v2/formacion_items_permisos";
  // Carpeta de los archivos de documentación
  static const String homeDocumentosFiles =
      "${intranetBaseUrl}files/docs_wellcome/";
}
