import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:im3_mobile_app/pages/news/news_detail_page.dart';
import 'package:im3_mobile_app/services/home_service.dart';
import 'package:im3_mobile_app/theme/theme.dart';

/// Noticia destacada (fijada) de la Home. Equivale a pinned.vue.
/// Se carga sola; si no hay ninguna fijada no ocupa espacio.
/// Al pulsarla se abre su detalle (con flecha atrás).
class HomePinned extends StatefulWidget {
  const HomePinned({super.key});

  /// Alto de la zona de la imagen
  static const double alturaImagen = 200;

  @override
  State<HomePinned> createState() => _HomePinnedState();
}

class _HomePinnedState extends State<HomePinned> {
  Map<String, dynamic>? _articulo;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final a = await HomeService.getDestacado();
    if (!mounted) return;
    setState(() {
      _articulo = a;
      _cargando = false;
    });
  }

  void _abrir(Map<String, dynamic> a) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => NewsDetailPage(id: '${a['id']}')));
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const _Hueco();

    final a = _articulo;
    if (a == null) return const SizedBox.shrink();

    final idioma = HomeService.idioma(a) ?? {};
    final titulo = '${idioma['titulo'] ?? ''}'.trim();
    final destacado = '${idioma['destacado'] ?? ''}'.trim();
    final imagen = HomeService.imagenDestacada(a);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      // La sombra va fuera; el fondo blanco y el recorte en el Material,
      // para que el efecto al pulsar (InkWell) se vea encima.
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _abrir(a),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (imagen != null) _imagen(imagen),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (titulo.isNotEmpty)
                        Text(
                          titulo,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                            color: AppColors.text,
                          ),
                        ),
                      if (titulo.isNotEmpty && destacado.isNotEmpty)
                        const SizedBox(height: 8),
                      if (destacado.isNotEmpty)
                        Text(
                          destacado,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                            color: Colors.grey[800],
                          ),
                        ),
                      const SizedBox(height: 10),
                      // Pista de que se puede pulsar
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Leer más',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Imagen completa encima de la misma imagen desenfocada (como la web)
  Widget _imagen(String url) {
    return SizedBox(
      height: HomePinned.alturaImagen,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo: la misma imagen ampliada, desenfocada y algo oscurecida
          ClipRect(
            child: Transform.scale(
              scale: 1.3,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  color: const Color(0x26000000),
                  colorBlendMode: BlendMode.darken,
                  errorBuilder: (_, __, ___) =>
                      Container(color: Colors.grey.shade200),
                ),
              ),
            ),
          ),
          // Imagen completa, sin recortar (con loader mientras carga)
          Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            loadingBuilder: (context, child, progreso) => progreso == null
                ? child
                : const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.5,
                    ),
                  ),
          ),
        ],
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
        height: HomePinned.alturaImagen + 90,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
