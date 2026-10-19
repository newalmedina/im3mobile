import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Igual que la web: crea un Blob, un <a download> y hace click.
/// Devuelve null si ha ido bien, o un mensaje si no.
Future<String?> guardarYAbrirPdf(Uint8List bytes, String nombre) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = nombre;
  web.document.body?.appendChild(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
  return null;
}
