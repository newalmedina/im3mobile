import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:im3_mobile_app/services/home_service.dart';
import 'package:im3_mobile_app/theme/theme.dart';

/// Bloque de Documentación. Equivale a documents.vue de la web.
/// Se carga solo; si no hay documentos no ocupa espacio.
class HomeDocuments extends StatefulWidget {
  const HomeDocuments({super.key});

  @override
  State<HomeDocuments> createState() => _HomeDocumentsState();
}

class _HomeDocumentsState extends State<HomeDocuments> {
  List<Map<String, dynamic>> _documentos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final lista = await HomeService.getDocumentos();
    if (!mounted) return;
    setState(() {
      _documentos = lista;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const _Hueco();
    if (_documentos.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Documentación',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < _documentos.length; i++)
                _Documento(
                  doc: _documentos[i],
                  ultimo: i == _documentos.length - 1,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una fila: clip + fecha pequeña + nombre en negrita (DocumentLink en la web)
class _Documento extends StatelessWidget {
  const _Documento({required this.doc, required this.ultimo});

  final Map<String, dynamic> doc;
  final bool ultimo;

  String _txt(String campo) {
    final s = '${doc[campo] ?? ''}'.trim();
    return s == 'null' ? '' : s;
  }

  /// "2026-03-10 12:30:00" -> "10/03/2026"
  String get _fecha {
    final f = DateTime.tryParse(_txt('fecha_modificacion'));
    if (f == null) return '';
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(f.day)}/${dos(f.month)}/${f.year}';
  }

  String get _nombre {
    final n = _txt('nombre');
    if (n.isNotEmpty) return n;
    final original = _txt('nombre_archivo_original');
    return original.isNotEmpty ? original : _txt('nombre_archivo');
  }

  Future<void> _abrir(BuildContext context) async {
    final url = HomeService.urlDocumento(doc);
    debugPrint('📄 DOCUMENTO: $doc');
    debugPrint('📄 URL: $url');

    var ok = false;
    if (url != null) {
      try {
        ok = await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('📄 ERROR AL ABRIR: $e');
      }
    }
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se ha podido abrir el documento')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _abrir(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: ultimo
              ? null
              : Border(bottom: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.attach_file,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_fecha.isNotEmpty)
                    Text(
                      _fecha,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  Text(
                    _nombre,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Recuadro gris mientras carga
class _Hueco extends StatelessWidget {
  const _Hueco();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
