import 'package:flutter/material.dart';
import 'package:im3_mobile_app/pages/news/news_detail_page.dart';
import 'package:im3_mobile_app/pages/news/news_page.dart';
import 'package:im3_mobile_app/services/home_service.dart';
import 'package:im3_mobile_app/theme/theme.dart';

/// Bloque "Últimas noticias" de la Home. Equivale a latest-news.vue.
/// Al pulsar una noticia se abre su detalle, y "Ver más" abre el
/// listado de noticias. Las dos pantallas se abren con flecha atrás.
class HomeLatestNews extends StatefulWidget {
  const HomeLatestNews({super.key});

  /// Cuántas noticias se muestran (en la web son 3)
  static const int cantidad = 3;

  @override
  State<HomeLatestNews> createState() => _HomeLatestNewsState();
}

class _HomeLatestNewsState extends State<HomeLatestNews> {
  List<Map<String, dynamic>> _lista = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final lista = await HomeService.getNoticias(
      cantidad: HomeLatestNews.cantidad,
    );
    if (!mounted) return;
    setState(() {
      _lista = lista;
      _cargando = false;
    });
  }

  void _abrir(Map<String, dynamic> n) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => NewsDetailPage(id: '${n['id']}')));
  }

  void _verMas() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NewsPage(conFlecha: true)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Últimas noticias',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            ..._contenido(),
            if (!_cargando)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _verMas,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Ver más'),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _contenido() {
    if (_cargando) {
      return const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      ];
    }

    if (_lista.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'No hay noticias.',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      ];
    }

    return [
      for (var i = 0; i < _lista.length; i++)
        _fila(_lista[i], ultimo: i == _lista.length - 1),
    ];
  }

  Widget _fila(Map<String, dynamic> n, {required bool ultimo}) {
    final idioma = HomeService.idioma(n) ?? {};
    final fecha = HomeService.fecha(idioma['fecha_publi']);
    final titulo = '${idioma['titulo'] ?? ''}'.trim();
    final resumen = HomeService.textoPlano(
      idioma['destacado'],
    ).replaceAll('\n', ' ');
    final imagen = HomeService.imagenDestacada(n);

    return InkWell(
      onTap: () => _abrir(n),
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
            _miniatura(imagen),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (fecha.isNotEmpty)
                    Text(
                      fecha,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                      color: AppColors.text,
                    ),
                  ),
                  if (resumen.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      resumen,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Imagen pequeña a la izquierda; si no hay o falla, un hueco gris
  Widget _miniatura(String? url) {
    const ancho = 96.0;
    const alto = 72.0;

    final hueco = Container(
      width: ancho,
      height: alto,
      color: Colors.grey.shade200,
      child: Icon(Icons.article_outlined, color: Colors.grey[400]),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: url == null
          ? hueco
          : Image.network(
              url,
              width: ancho,
              height: alto,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => hueco,
              loadingBuilder: (context, child, progreso) =>
                  progreso == null ? child : hueco,
            ),
    );
  }
}
