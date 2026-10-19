import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:im3_mobile_app/services/home_service.dart';
import 'package:im3_mobile_app/services/news_service.dart';
import 'package:im3_mobile_app/theme/theme.dart';
import 'package:im3_mobile_app/widgets/imagen_con_loader.dart';

/// Detalle de una publicación (noticia o comunicado).
/// Equivale a pages/noticias/_id.vue. Se abre encima con flecha atrás.
class NewsDetailPage extends StatefulWidget {
  const NewsDetailPage({super.key, required this.id, this.titulo = 'Noticias'});

  final String id;

  /// Texto de la barra de arriba ('Noticias', 'Comunicados'...)
  final String titulo;

  @override
  State<NewsDetailPage> createState() => _NewsDetailPageState();
}

class _NewsDetailPageState extends State<NewsDetailPage> {
  static const _verde = Color(0xFF19B511);
  static const _azulGuardado = Color(0xFF1890FF);

  Map<String, dynamic>? _pub;
  List<String> _imagenes = [];
  bool _cargando = true;
  bool _favorito = false;
  bool _enviando = false;
  String _opinion = '';
  final Map<String, int> _contadores = {
    'me_gusta': 0,
    'indiferente': 0,
    'no_me_gusta': 0,
  };

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  static String _txt(dynamic v) {
    final s = '${v ?? ''}'.trim();
    return s == 'null' ? '' : s;
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final pub = await NewsService.getDetalle(widget.id);
    if (!mounted) return;
    if (pub == null) {
      setState(() => _cargando = false);
      return;
    }

    final r = await Future.wait([
      NewsService.getImagenes(widget.id),
      NewsService.esFavorito(widget.id),
    ]);
    if (!mounted) return;

    setState(() {
      _pub = pub;
      _imagenes = r[0] as List<String>;
      _favorito = r[1] as bool;
      _opinion = _txt(pub['opinion']);
      for (final k in _contadores.keys.toList()) {
        _contadores[k] = int.tryParse(_txt(pub['count_$k'])) ?? 0;
      }
      _cargando = false;
    });

    NewsService.marcarVisitado(widget.id);
    NewsService.guardarLog();
  }

  Future<void> _opinar(String nueva) async {
    if (_enviando || nueva == _opinion) return;
    _enviando = true;
    final anterior = _opinion;
    final fallo = await NewsService.opinar(
      widget.id,
      anterior: anterior,
      nueva: nueva,
    );
    _enviando = false;
    if (!mounted) return;

    if (fallo != null) {
      _aviso('No se ha podido guardar tu opinión ($fallo)');
      return;
    }
    setState(() {
      if (_contadores.containsKey(anterior)) {
        _contadores[anterior] = math.max(0, _contadores[anterior]! - 1);
      }
      _contadores[nueva] = (_contadores[nueva] ?? 0) + 1;
      _opinion = nueva;
    });
    if (nueva != 'me_gusta') {
      _aviso('Gracias por tu opinión. Nos ayuda a mejorar.');
    }
  }

  Future<void> _cambiarFavorito() async {
    final fallo = await NewsService.cambiarFavorito(widget.id);
    if (!mounted) return;
    if (fallo == null) {
      setState(() => _favorito = !_favorito);
    } else {
      _aviso('No se ha podido actualizar el guardado ($fallo)');
    }
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  // ---------------------------------------------------------------- vista
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.titulo),
      ),
      body: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final pub = _pub;
    if (pub == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No se ha podido cargar la noticia',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    final art = pub['localizedArticle'] is Map
        ? Map<String, dynamic>.from(pub['localizedArticle'] as Map)
        : <String, dynamic>{};
    final fecha = HomeService.fecha(art['fecha_publi']);
    final titulo = _txt(art['titulo']);
    final destacado = _txt(art['destacado']);
    final texto = HomeService.textoPlano(art['texto']);
    final soloImagenes = HomeService.siNo(pub['solo_imagenes']);
    final visitas = _txt(pub['visitCount']);
    final etiquetas = (pub['etiquetas'] is List ? pub['etiquetas'] as List : [])
        .map(_nombreEtiqueta)
        .where((e) => e.isNotEmpty)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // Reacciones y guardar
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _reaccion('me_gusta', Icons.sentiment_satisfied_alt, _verde),
            _reaccion('indiferente', Icons.sentiment_neutral, Colors.grey),
            _reaccion('no_me_gusta', Icons.sentiment_dissatisfied, Colors.red),
            IconButton(
              tooltip: _favorito ? 'Quitar de guardados' : 'Guardar',
              onPressed: _cambiarFavorito,
              icon: Icon(
                _favorito ? Icons.bookmark : Icons.bookmark_border,
                color: _favorito ? _azulGuardado : Colors.grey[700],
                size: 30,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Artículo
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    fecha,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  Text(
                    'Visitas: ${visitas.isEmpty ? '0' : visitas}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                  color: AppColors.text,
                ),
              ),
              if (_imagenes.isNotEmpty) ...[
                const SizedBox(height: 14),
                _Galeria(urls: _imagenes, alta: soloImagenes),
              ],
              if (!soloImagenes) ...[
                if (destacado.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: AppColors.primary, width: 3),
                      ),
                    ),
                    child: Text(
                      destacado,
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.4,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ],
                if (texto.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SelectableText(
                    texto,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: AppColors.text,
                    ),
                  ),
                ],
                if (etiquetas.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final e in etiquetas)
                        Chip(
                          label: Text(e),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.grey.shade100,
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _nombreEtiqueta(dynamic e) {
    if (e is Map) {
      return _txt(e['nombre'] ?? e['etiqueta'] ?? e['titulo']);
    }
    return _txt(e);
  }

  Widget _reaccion(String clave, IconData icono, Color color) {
    final activo = _opinion == clave;
    final n = _contadores[clave] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Badge(
        isLabelVisible: n > 0,
        label: Text('$n'),
        offset: const Offset(6, -4),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _opinar(clave),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: activo ? color.withValues(alpha: 0.15) : null,
              border: Border.all(
                color: activo ? color : Colors.transparent,
                width: 2,
              ),
            ),
            child: Icon(icono, color: color, size: 28),
          ),
        ),
      ),
    );
  }
}

/// Slider de imágenes con flechas, números y loader en cada imagen.
/// Al pulsar una imagen se abre a pantalla completa con zoom.
class _Galeria extends StatefulWidget {
  const _Galeria({required this.urls, required this.alta});

  final List<String> urls;

  /// true en las noticias "solo imágenes" (newsletter): más alto
  final bool alta;

  @override
  State<_Galeria> createState() => _GaleriaState();
}

class _GaleriaState extends State<_Galeria> {
  final _ctrl = PageController();
  int _i = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _ir(int i) {
    final n = widget.urls.length;
    _ctrl.animateToPage(
      (i + n) % n,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _verGrande(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: InteractiveViewer(
              maxScale: 5,
              child: ImagenConLoader(url: url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    final ancho = MediaQuery.sizeOf(context).width;
    final alto = widget.alta ? ancho * 1.4 : 240.0;

    return Column(
      children: [
        SizedBox(
          height: alto,
          child: Stack(
            children: [
              PageView.builder(
                controller: _ctrl,
                itemCount: urls.length,
                onPageChanged: (i) => setState(() => _i = i),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _verGrande(urls[i]),
                  child: ImagenConLoader(
                    url: urls[i],
                    height: alto,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              if (urls.length > 1) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: _flecha(Icons.chevron_left, () => _ir(_i - 1)),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: _flecha(Icons.chevron_right, () => _ir(_i + 1)),
                ),
              ],
            ],
          ),
        ),
        if (urls.length > 1) ...[
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < urls.length; i++)
                GestureDetector(
                  onTap: () => _ir(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: i == _i ? 32 : 28,
                    height: i == _i ? 32 : 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _i
                          ? const Color(0xFF71BD45)
                          : const Color(0xFF20409A),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _flecha(IconData icono, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icono, color: Colors.white),
        onPressed: onTap,
      ),
    ),
  );
}
