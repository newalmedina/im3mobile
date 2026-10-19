import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:im3_mobile_app/theme/theme.dart';

/// Utilidades y piezas comunes del perfil de trabajador.
/// Las usan worker_page, worker_imagen, worker_info y worker_companeros.

// =========================================================
// Utilidades
// =========================================================

class WorkerUtils {
  WorkerUtils._();

  /// Valor como texto limpio ('' si es null)
  static String texto(dynamic v) => v == null ? '' : '$v'.trim();

  /// mapa[clave] si es un Map, si no null
  static dynamic sub(dynamic mapa, String clave) =>
      mapa is Map ? mapa[clave] : null;

  /// true / 1 / '1' / 'true'
  static bool si(dynamic v) =>
      v == true || v == 1 || v == '1' || v == 'true';

  /// "Nombre Apellido"
  static String nombreCompleto(Map<String, dynamic>? p) => p == null
      ? ''
      : '${texto(p['nombre'])} ${texto(p['apellido'])}'.trim();

  /// Id de usuario de un compañero (por si empleadoDiv trae otro id)
  static String idUsuario(Map<String, dynamic> p) =>
      texto(p['id_user'] ?? p['user_id'] ?? p['id']);

  /// Abre mailto:, tel: o una web
  static Future<void> abrir(String enlace) async {
    var e = enlace.trim();
    if (e.isEmpty) return;
    if (!e.startsWith('mailto:') &&
        !e.startsWith('tel:') &&
        !e.startsWith('http')) {
      e = 'https://$e';
    }
    final uri = Uri.tryParse(e);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// =========================================================
// Piezas visuales
// =========================================================

/// Tarjeta blanca como las de la home
class WorkerTarjeta extends StatelessWidget {
  const WorkerTarjeta({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
      child: child,
    );
  }
}

/// Título de bloque ("Información general", "Trabaja con")
class WorkerTitulo extends StatelessWidget {
  const WorkerTitulo(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.text,
        ),
      ),
    );
  }
}

/// Subtítulo dentro de un bloque ("Emails", "Teléfono"...)
class WorkerSubtitulo extends StatelessWidget {
  const WorkerSubtitulo(this.texto, {super.key, this.arriba = true});

  final String texto;

  /// Margen por arriba (false para el primero del bloque)
  final bool arriba;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: arriba ? 14 : 0, bottom: 4),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
        ),
      ),
    );
  }
}

/// Indicador pequeño mientras carga un bloque
class WorkerCargando extends StatelessWidget {
  const WorkerCargando({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// Mensaje de error con botón de reintentar
class WorkerFallo extends StatelessWidget {
  const WorkerFallo({
    super.key,
    required this.texto,
    required this.onReintentar,
    this.centrado = false,
  });

  final String texto;
  final VoidCallback onReintentar;
  final bool centrado;

  @override
  Widget build(BuildContext context) {
    final contenido = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          centrado ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(texto, style: TextStyle(color: Colors.grey[700])),
        TextButton.icon(
          onPressed: onReintentar,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Reintentar'),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
      ],
    );
    return centrado ? Center(child: contenido) : contenido;
  }
}
