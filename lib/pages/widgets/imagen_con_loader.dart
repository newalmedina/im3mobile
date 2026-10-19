import 'package:flutter/material.dart';
import 'package:im3_mobile_app/theme/theme.dart';

/// Imagen de red que muestra un loader mientras se descarga
/// y un icono si no se puede cargar.
///
/// Uso:
///   ImagenConLoader(url: miUrl, height: 180, fit: BoxFit.cover)
class ImagenConLoader extends StatelessWidget {
  const ImagenConLoader({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final imagen = Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      // Mientras carga: loader centrado
      loadingBuilder: (context, child, progreso) {
        if (progreso == null) return child; // ya ha cargado
        final total = progreso.expectedTotalBytes;
        return _Caja(
          width: width,
          height: height,
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.5,
            value: total != null
                ? progreso.cumulativeBytesLoaded / total
                : null,
          ),
        );
      },
      // Si falla: icono de imagen rota
      errorBuilder: (context, error, stack) => _Caja(
        width: width,
        height: height,
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.grey.shade400,
          size: 32,
        ),
      ),
    );

    if (borderRadius == null) return imagen;
    return ClipRRect(borderRadius: borderRadius!, child: imagen);
  }
}

class _Caja extends StatelessWidget {
  const _Caja({required this.child, this.width, this.height});

  final Widget child;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height ?? 120,
      color: Colors.grey.shade100,
      alignment: Alignment.center,
      child: SizedBox(width: 28, height: 28, child: child),
    );
  }
}
