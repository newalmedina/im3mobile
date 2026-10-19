import 'package:flutter/material.dart';

import 'package:im3_mobile_app/theme/theme.dart';

/// Envuelve el contenido de una pantalla y muestra un botón para volver
/// arriba cuando se ha bajado más de [umbral] píxeles.
///
/// No necesita ScrollController: escucha el scroll de la lista que haya
/// dentro (ListView, SingleChildScrollView...), así que sirve para todas
/// las pantallas que usan MainLayout sin tocarlas.
class ScrollToTop extends StatefulWidget {
  const ScrollToTop({
    super.key,
    required this.child,
    this.umbral = 400,
  });

  final Widget child;

  /// A partir de cuántos píxeles de scroll aparece el botón
  final double umbral;

  @override
  State<ScrollToTop> createState() => _ScrollToTopState();
}

class _ScrollToTopState extends State<ScrollToTop> {
  ScrollPosition? _posicion;
  bool _visible = false;

  bool _alHacerScroll(ScrollNotification n) {
    // Solo la lista principal y vertical (no carruseles horizontales
    // ni listas metidas dentro de otras)
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;

    final ctx = n.context;
    if (ctx != null) {
      _posicion = Scrollable.maybeOf(ctx)?.position ?? _posicion;
    }

    final mostrar = n.metrics.pixels > widget.umbral;
    if (mostrar != _visible) setState(() => _visible = mostrar);

    return false; // deja pasar la notificación (RefreshIndicator, etc.)
  }

  void _subir() {
    final p = _posicion;
    if (p == null || !p.hasPixels) return;
    p.animateTo(
      0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _alHacerScroll,
          child: widget.child,
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: SafeArea(
            child: IgnorePointer(
              ignoring: !_visible,
              child: AnimatedSlide(
                offset: _visible ? Offset.zero : const Offset(0, 0.5),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: AnimatedOpacity(
                  opacity: _visible ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: FloatingActionButton.small(
                    // null para que no choque con otros botones flotantes
                    heroTag: null,
                    tooltip: 'Volver arriba',
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    onPressed: _subir,
                    child: const Icon(Icons.keyboard_arrow_up, size: 28),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
