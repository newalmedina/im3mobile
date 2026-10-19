import 'package:flutter/material.dart';

import 'package:im3_mobile_app/pages/news/news_detail_page.dart';
import 'package:im3_mobile_app/pages/notices/notices_page.dart';
import 'package:im3_mobile_app/services/home_service.dart';
import 'package:im3_mobile_app/theme/theme.dart';

/// Bloque "Comunicados" de la Home. Equivale a notices.vue + notice.vue.
/// Al pulsar un comunicado se abre su detalle, y "Ver más" abre el
/// listado de comunicados. Las dos pantallas se abren con flecha atrás.
class HomeNotices extends StatefulWidget {
  const HomeNotices({super.key});

  /// Cuántos comunicados se muestran (en la web son 3)
  static const int cantidad = 3;

  @override
  State<HomeNotices> createState() => _HomeNoticesState();
}

class _HomeNoticesState extends State<HomeNotices> {
  List<Map<String, dynamic>> _lista = [];
  bool _conIcono = false; // permiso front-comun-noti
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final lista = await HomeService.getComunicados(
      cantidad: HomeNotices.cantidad,
    );
    final conIcono = await HomeService.tienePermiso('front-comun-noti');
    if (!mounted) return;
    setState(() {
      _lista = lista;
      _conIcono = conIcono;
      _cargando = false;
    });
  }

  void _abrir(Map<String, dynamic> c) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewsDetailPage(id: '${c['id']}', titulo: 'Comunicados'),
      ),
    );
  }

  void _verMas() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NoticesPage(conFlecha: true)),
    );
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
              'Comunicados',
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
            'No hay comunicados.',
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

  Widget _fila(Map<String, dynamic> c, {required bool ultimo}) {
    final idioma = HomeService.idioma(c) ?? {};
    final fecha = HomeService.fecha(idioma['fecha_publi']);
    final titulo = '${idioma['titulo'] ?? ''}'.trim();
    final soloImagenes = HomeService.siNo(c['solo_imagenes']);
    final resumen = soloImagenes
        ? ''
        : HomeService.textoPlano(idioma['texto']).replaceAll('\n', ' ');

    return InkWell(
      onTap: () => _abrir(c),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          border: ultimo
              ? null
              : Border(bottom: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      color: AppColors.text,
                    ),
                  ),
                  if (resumen.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      resumen,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
            if (_conIcono) ...[
              const SizedBox(width: 8),
              const Icon(Icons.add, color: AppColors.primary, size: 26),
            ],
          ],
        ),
      ),
    );
  }
}
