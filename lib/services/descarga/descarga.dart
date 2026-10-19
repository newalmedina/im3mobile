/// Guarda un PDF y lo abre.
/// - Web (Chrome): lo descarga como hace la web (enlace con "download").
/// - Android / iOS: lo guarda en la carpeta de la app y lo abre.
export 'descarga_io.dart' if (dart.library.js_interop) 'descarga_web.dart';
