import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../services/home_service.dart';

/// Banner de la cabecera de la Home.
/// Se carga solo; si no hay banner configurado no ocupa espacio.
class HomeBanner extends StatefulWidget {
  const HomeBanner({super.key});

  /// Proporción ancho / alto del banner.
  /// La imagen original es ~7 (7 veces más ancha que alta).
  /// Más bajo = más alto el banner (6 = un poco más alto, 5 = bastante más).
  static const double proporcion = 3;

  @override
  State<HomeBanner> createState() => _HomeBannerState();
}

class _HomeBannerState extends State<HomeBanner> {
  Map<String, String>? _banner;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final b = await HomeService.getBanner();
    if (!mounted) return;
    setState(() {
      _banner = b;
      _cargando = false;
    });
  }

  /// Abre el enlace del banner en el navegador (target="_blank" en la web)
  Future<void> _abrir() async {
    var enlace = _banner?['enlace'] ?? '';
    if (enlace.isEmpty) return;
    if (!enlace.startsWith('http')) enlace = 'https://$enlace';

    final uri = Uri.tryParse(enlace);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const _Hueco();

    final b = _banner;
    if (b == null) return const SizedBox.shrink();

    final tieneEnlace = (b['enlace'] ?? '').isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onTap: tieneEnlace ? _abrir : null,
          child: AspectRatio(
            aspectRatio: HomeBanner.proporcion,
            child: Image.network(
              b['imagen']!,
              width: double.infinity,
              // Entera, estirada un poco a lo alto
              fit: BoxFit.fill,
              loadingBuilder: (context, child, progreso) =>
                  progreso == null ? child : const _Hueco(margen: false),
              // Si la imagen no carga, el bloque desaparece (como en la web)
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Recuadro gris mientras carga
class _Hueco extends StatelessWidget {
  const _Hueco({this.margen = true});

  final bool margen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: margen ? 16 : 0),
      child: AspectRatio(
        aspectRatio: HomeBanner.proporcion,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
