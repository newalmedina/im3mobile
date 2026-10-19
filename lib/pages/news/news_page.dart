import 'dart:async';

import 'package:flutter/material.dart';

import 'package:im3_mobile_app/layouts/main_layout.dart';
import 'package:im3_mobile_app/services/home_service.dart';
import 'package:im3_mobile_app/services/news_service.dart';
import 'package:im3_mobile_app/theme/theme.dart';
import 'package:im3_mobile_app/widgets/imagen_con_loader.dart';

import 'news_detail_page.dart';

/// Listado de noticias con buscador y "Guardados".
/// Equivale a pages/noticias/index.vue.
///
///   - Punto de menú:        const NewsPage()                 (con menú lateral)
///   - Desde la Home (Ver más): const NewsPage(conFlecha: true) (con flecha atrás)
class NewsPage extends StatefulWidget {
  const NewsPage({super.key, this.conFlecha = false});

  /// true -> se abre encima con flecha atrás en vez de con el menú
  final bool conFlecha;

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  static const _azulGuardado = Color(0xFF1890FF);
  static const _porPagina = NewsService.porPagina;

  final _scroll = ScrollController();
  final _buscador = TextEditingController();
  Timer? _debounce;

  // Sin filtro: se piden páginas de 12 al hacer scroll
  final List<Map<String, dynamic>> _lista = [];
  bool _cargando = true;
  bool _cargandoMas = false;
  bool _hayMas = true;

  // Con filtro: se descargan todas una vez y se filtra en el móvil
  List<Map<String, dynamic>>? _todas;
  bool _cargandoTodas = false;
  String _query = '';
  bool _soloGuardados = false;
  int _visibles = _porPagina;

  bool get _filtrando => _query.isNotEmpty || _soloGuardados;

  List<Map<String, dynamic>> get _filtradas {
    var l = _todas ?? const <Map<String, dynamic>>[];
    if (_query.isNotEmpty) {
      l = l.where((a) => '${a['_search'] ?? ''}'.contains(_query)).toList();
    }
    if (_soloGuardados) {
      l = l.where((a) => HomeService.siNo(a['favorito'])).toList();
    }
    return l;
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _cargarPrimera();
    _cargarTodas(); // como la web: el buscador se precarga al entrar
    NewsService.guardarLog();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _buscador.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- datos
  Future<void> _cargarPrimera() async {
    final l = await NewsService.getPagina(0);
    if (!mounted) return;
    setState(() {
      _lista
        ..clear()
        ..addAll(l);
      _hayMas = l.length >= _porPagina;
      _cargando = false;
    });
  }

  Future<void> _cargarMas() async {
    if (_cargandoMas || !_hayMas) return;
    setState(() => _cargandoMas = true);
    final l = await NewsService.getPagina(_lista.length);
    if (!mounted) return;
    setState(() {
      _lista.addAll(l);
      _hayMas = l.length >= _porPagina;
      _cargandoMas = false;
    });
  }

  Future<void> _cargarTodas({bool forzar = false}) async {
    if (_cargandoTodas || (_todas != null && !forzar)) return;
    setState(() => _cargandoTodas = true);
    final l = await NewsService.getTodas();
    if (!mounted) return;
    setState(() {
      // Si falla, se queda en null para poder reintentar
      _todas = l.isEmpty ? null : l;
      _cargandoTodas = false;
    });
  }

  Future<void> _refrescar() async {
    setState(() {
      _visibles = _porPagina;
      _hayMas = true;
    });
    await Future.wait([_cargarPrimera(), _cargarTodas(forzar: true)]);
  }

  // ---------------------------------------------------------- interacción
  void _onScroll() {
    if (!_scroll.hasClients || _scroll.position.extentAfter > 300) return;
    if (_filtrando) {
      if (_visibles < _filtradas.length) {
        setState(() => _visibles += _porPagina);
      }
    } else {
      _cargarMas();
    }
  }

  void _onBuscar(String texto) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _query = texto.trim().toLowerCase();
        _visibles = _porPagina;
      });
      if (_filtrando) _cargarTodas();
    });
  }

  void _toggleGuardados() {
    setState(() {
      _soloGuardados = !_soloGuardados;
      _visibles = _porPagina;
    });
    if (_filtrando) _cargarTodas();
  }

  Future<void> _abrir(Map<String, dynamic> articulo) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewsDetailPage(id: '${articulo['id']}'),
      ),
    );
    // Al volver, por si ha guardado o quitado de guardados
    if (mounted) _cargarTodas(forzar: true);
  }

  // ---------------------------------------------------------------- vista
  @override
  Widget build(BuildContext context) {
    final contenido = Column(
      children: [
        _barraFiltros(),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _refrescar,
            child: _cuerpo(),
          ),
        ),
      ],
    );

    // Punto de menú: dentro del layout con la barra y el menú lateral
    if (!widget.conFlecha) {
      return MainLayout(currentRoute: 'noticias', child: contenido);
    }

    // Abierta encima (desde la Home): flecha atrás
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Noticias'),
      ),
      body: contenido,
    );
  }

  Widget _barraFiltros() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _buscador,
              builder: (_, valor, __) => TextField(
                controller: _buscador,
                onChanged: _onBuscar,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Buscar noticias',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: valor.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _buscador.clear();
                            _onBuscar('');
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Guardados',
            onPressed: _toggleGuardados,
            icon: Icon(
              _soloGuardados ? Icons.bookmark : Icons.bookmark_border,
              color: _soloGuardados ? _azulGuardado : Colors.grey,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    final cargando =
        _filtrando ? (_todas == null && _cargandoTodas) : _cargando;
    if (cargando) {
      return _mensaje(
        const CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final items =
        _filtrando ? _filtradas.take(_visibles).toList() : _lista;

    if (items.isEmpty) {
      final texto = _filtrando && _todas == null
          ? 'No se han podido cargar las noticias'
          : _soloGuardados && _query.isEmpty
              ? 'No tienes noticias guardadas'
              : _filtrando
                  ? 'No hay resultados'
                  : 'No hay noticias';
      return _mensaje(
        Text(texto, style: TextStyle(color: Colors.grey[600], fontSize: 15)),
      );
    }

    final conPie = !_filtrando && _cargandoMas;
    return ListView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: items.length + (conPie ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        return _NoticiaCard(
          articulo: items[i],
          onTap: () => _abrir(items[i]),
        );
      },
    );
  }

  /// Contenido centrado que se puede arrastrar para refrescar
  Widget _mensaje(Widget hijo) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 240, child: Center(child: hijo)),
        ],
      );
}

/// Tarjeta de una noticia (ArticleCard de la web)
class _NoticiaCard extends StatelessWidget {
  const _NoticiaCard({required this.articulo, required this.onTap});

  final Map<String, dynamic> articulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final idioma = HomeService.idioma(articulo) ?? {};
    final fecha = HomeService.fecha(idioma['fecha_publi']);
    final titulo = '${idioma['titulo'] ?? ''}'.trim();
    final destacado = '${idioma['destacado'] ?? ''}'.trim();
    final imagen = HomeService.imagenDestacada(articulo);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        elevation: 1,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (imagen != null)
                ImagenConLoader(url: imagen, height: 180, fit: BoxFit.cover),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (fecha.isNotEmpty)
                      Text(
                        fecha,
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      titulo,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                        color: AppColors.text,
                      ),
                    ),
                    if (destacado.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        destacado,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
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
      ),
    );
  }
}
