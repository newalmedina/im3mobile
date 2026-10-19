import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Guarda el PDF en la carpeta de documentos de la app y lo abre
/// con el visor de PDF del móvil.
/// Devuelve null si ha ido bien, o un mensaje si no.
Future<String?> guardarYAbrirPdf(Uint8List bytes, String nombre) async {
  final dir = await getApplicationDocumentsDirectory();
  final archivo = File('${dir.path}/$nombre');
  await archivo.writeAsBytes(bytes, flush: true);

  final r = await OpenFilex.open(archivo.path, type: 'application/pdf');
  if (r.type != ResultType.done) {
    return 'La nómina se ha guardado, pero no hay ninguna app para abrir PDF.';
  }
  return null;
}
