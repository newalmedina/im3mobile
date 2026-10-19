import 'dart:math' show max;

import 'package:flutter/material.dart';

import 'package:im3_mobile_app/pages/workers/worker_page.dart';
import 'package:im3_mobile_app/services/home_service.dart';
import 'package:im3_mobile_app/theme/theme.dart';

/// Carrusel de nuevas incorporaciones. Equivale a incorporaciones.vue.
/// Se carga solo; si no hay nadie no ocupa espacio.
class HomeIncorporaciones extends StatefulWidget {
  const HomeIncorporaciones({super.key});

  /// Cuántas personas se ven a la vez
  static const int porVista = 2;

  @override
  State<HomeIncorporaciones> createState() => _HomeIncorporacionesState();
}

class _HomeIncorporacionesState extends State<HomeIncorporaciones> {
  List<Map<String, dynamic>> _lista = [];
  bool _cargando = true;
  int _pagina = 0;

  final _controller = PageController(
    viewportFraction: 1 / HomeIncorporaciones.porVista,
  );

  int get _ultima => max(0, _lista.length - HomeIncorporaciones.porVista);

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final p = _controller.page?.round() ?? 0;
      if (p != _pagina) setState(() => _pagina = p);
    });
    _cargar();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final l = await HomeService.getIncorporaciones();
    if (!mounted) return;
    setState(() {
      _lista = l;
      _cargando = false;
    });
  }

  void _mover(int sentido) {
    final destino = (_pagina + sentido * HomeIncorporaciones.porVista).clamp(
      0,
      _ultima,
    );
    _controller.animateToPage(
      destino,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const _Hueco();
    if (_lista.isEmpty) return const SizedBox.shrink();

    final conFlechas = _lista.length > HomeIncorporaciones.porVista;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nuevas incorporaciones Im3 ¡Bienvenidos!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                height: 1.2,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, c) {
                final ancho = c.maxWidth / HomeIncorporaciones.porVista;
                final foto = ancho - 12;
                final alto = foto + 8 + 64;

                return SizedBox(
                  height: alto,
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: _controller,
                        padEnds: false,
                        itemCount: _lista.length,
                        itemBuilder: (_, i) => _Trabajador(usuario: _lista[i]),
                      ),
                      if (conFlechas) ...[
                        Positioned(
                          left: 0,
                          top: foto / 2 - 18,
                          child: _Flecha(
                            icono: Icons.chevron_left,
                            activa: _pagina > 0,
                            onTap: () => _mover(-1),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: foto / 2 - 18,
                          child: _Flecha(
                            icono: Icons.chevron_right,
                            activa: _pagina < _ultima,
                            onTap: () => _mover(1),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Una persona: foto cuadrada, nombre y división. Al pulsar abre su perfil.
class _Trabajador extends StatelessWidget {
  const _Trabajador({required this.usuario});

  final Map<String, dynamic> usuario;

  @override
  Widget build(BuildContext context) {
    final id = '${usuario['id'] ?? ''}'.trim();
    final nombre = '${usuario['nombre'] ?? ''}'.trim();
    final division = '${usuario['division'] ?? ''}'.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: id.isEmpty
            ? null
            : () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => WorkerPage(id: id))),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    HomeService.fotoUsuario(usuario['imagen']),
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progreso) =>
                        progreso == null
                        ? child
                        : Container(color: Colors.grey.shade200),
                    errorBuilder: (_, __, ___) => Image.network(
                      HomeService.fotoUsuario(null),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: Colors.grey.shade200),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              nombre,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.3,
                color: AppColors.text,
              ),
            ),
            if (division.isNotEmpty)
              Text(
                division,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                  color: AppColors.text.withOpacity(0.75),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Flecha redonda del color principal
class _Flecha extends StatelessWidget {
  const _Flecha({
    required this.icono,
    required this.activa,
    required this.onTap,
  });

  final IconData icono;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: activa ? 1 : 0.35,
      child: Material(
        color: AppColors.primary,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: activa ? onTap : null,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icono, color: Colors.white, size: 24),
          ),
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
        height: 260,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
