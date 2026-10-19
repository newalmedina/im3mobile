import 'dart:async';

import 'package:flutter/material.dart';

import 'package:im3_mobile_app/layouts/main_layout.dart';
import 'package:im3_mobile_app/pages/news/news_detail_page.dart';
import 'package:im3_mobile_app/services/home_service.dart';
import 'package:im3_mobile_app/services/news_service.dart';
import 'package:im3_mobile_app/theme/theme.dart';

/// Listado de comunicados con buscador, "Guardados" y "Buenas prácticas".
/// Equivale a pages/comunicados/index.vue.
///
///   - Punto de menú:           const NoticesPage()
///   - Desde la Home (Ver más): const NoticesPage(conFlecha: true)
///
/// El detalle es el mismo de noticias (NewsDetailPage) con el título
/// "Comunicados", igual que en la web (comunicados/_id.vue es idéntico).
class NoticesPage extends StatefulWidget {
  const NoticesPage({super.key, this.conFlecha = false});

  /// true -> se abre encima con flecha atrás en vez de con el menú
  final bool conFlecha;

  @override
  State<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  static const _tipo = HomeService.tipoComunicado;
  static const _porPagina = NewsService.porPagina;
  static const _azulGuardado = Color(0xFF1890FF);
  static const _amarilloPildora = Color(0xFFFAAD14);

  final _scroll = ScrollController();
  final _buscador = TextEditingController();
  Timer? _debounce;
  Timer? _precarga;

  // Sin filtro: páginas de 12 al hacer scroll
  final List<Map<String, dynamic>> _lista = [];
  bool _cargando = true;
  bool _cargandoMas = false;
  bool _hayMas = true;

  // Con filtro: todos descargados una vez, filtrados en el móvil
  List<Map<String, dynamic>>? _todos;
  bool _cargandoTodos = false;
  String _query = '';
  bool _soloGuardados = false;
  bool _soloPildoras = false;
  int _visibles = _porPagina;

  bool get _filtrando => _query.isNotEmpty || _soloGuardados || _soloPildoras;

  List<Map<String, dynamic>> get _filtrados {
    var l = _todos ?? const <Map<String, dynamic>>[];
    if (_query.isNotEmpty) {
      l = l.where((a) => '${a['_search'] ?? ''}'.contains(_query)).toList();
    }
    if (_soloGuardados) {
      l = l.where((a) => HomeService.siNo(a['favorito'])).toList();
    }
    if (_soloPildoras) {
      l = l.where((a) => HomeService.siNo(a['pildora'])).toList();
    }
    return l;
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _cargarPrimera();
    // Como la web: precarga del buscador en segundo plano a los 1,5 s
    _precarga = Timer(const Duration(milliseconds: 1500), _cargarTodos);
    NewsService.guardarLog();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _precarga?.cancel();
    _scroll.dispose();
    _buscador.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- datos
  Future<void> _cargarPrimera() async {
    final l = await NewsService.getPagina(0, tipo: _tipo);
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
    if (_cargando || _cargandoMas || !_hayMas) return;
    setState(() => _cargandoMas = true);
    final l = await NewsService.getPagina(_lista.length, tipo: _tipo);
    if (!mounted) return;
    setState(() {
      _lista.addAll(l);
      _hayMas = l.length >= _porPagina;
      _cargandoMas = false;
    });
  }

  Future<void> _cargarTodos({bool forzar = false}) async {
    if (!mounted || _cargandoTodos || (_todos != null && !forzar)) return;
    setState(() => _cargandoTodos = true);
    final l = await NewsService.getTodas(tipo: _tipo);
    if (!mounted) return;
    setState(() {
      _todos = l.isEmpty ? null : l; // null = se puede reintentar
      _cargandoTodos = false;
    });
  }

  Future<void> _refrescar() async {
    setState(() {
      _visibles = _porPagina;
      _hayMas = true;
    });
    await Future.wait([_cargarPrimera(), _cargarTodos(forzar: true)]);
  }

  // ---------------------------------------------------------- interacción
  void _onScroll() {
    if (!_scroll.hasClients || _scroll.position.extentAfter > 300) return;
    if (_filtrando) {
      if (_visibles < _filtrados.length) {
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
      if (_filtrando) _cargarTodos();
    });
  }

  void _toggleGuardados() {
    setState(() {
      _soloGuardados = !_soloGuardados;
      _visibles = _porPagina;
    });
    if (_filtrando) _cargarTodos();
  }

  void _togglePildoras() {
    setState(() {
      _soloPildoras = !_soloPildoras;
      _visibles = _porPagina;
    });
    if (_filtrando) _cargarTodos();
  }

  Future<void> _abrir(Map<String, dynamic> c) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            NewsDetailPage(id: '${c['id']}', titulo: 'Comunicados'),
      ),
    );
    // Al volver, por si ha guardado o quitado de guardados
    if (mounted) _cargarTodos(forzar: true);
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

    if (!widget.conFlecha) {
      return MainLayout(currentRoute: 'comunicados', child: contenido);
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Comunicados'),
      ),
      body: contenido,
    );
  }

  Widget _barraFiltros() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
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
                  hintText: 'Buscar comunicados',
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
          IconButton(
            tooltip: 'Guardados',
            onPressed: _toggleGuardados,
            icon: Icon(
              _soloGuardados ? Icons.bookmark : Icons.bookmark_border,
              color: _soloGuardados ? _azulGuardado : Colors.grey,
              size: 30,
            ),
          ),
          IconButton(
            tooltip: 'Buenas prácticas',
            onPressed: _togglePildoras,
            icon: Icon(
              _soloPildoras ? Icons.lightbulb : Icons.lightbulb_outline,
              color: _soloPildoras ? _amarilloPildora : Colors.grey,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    final cargando =
        _filtrando ? (_todos == null && _cargandoTodos) : _cargando;
    if (cargando) {
      return _mensaje(
        const CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final items = _filtrando ? _filtrados.take(_visibles).toList() : _lista;

    if (items.isEmpty) {
      final String texto;
      if (_filtrando && _todos == null) {
        texto = 'No se han podido cargar los comunicados';
      } else if (_soloGuardados && _query.isEmpty && !_soloPildoras) {
        texto = 'No tienes comunicados guardados';
      } else if (_soloPildoras && _query.isEmpty && !_soloGuardados) {
        texto = 'No hay buenas prácticas';
      } else if (_filtrando) {
        texto = 'No hay resultados';
      } else {
        texto = 'No hay comunicados';
      }
      return _mensaje(
        Text(texto, style: TextStyle(color: Colors.grey[600], fontSize: 15)),
      );
    }

    final conPie = !_filtrando && _cargandoMas;

    // Todas las filas dentro de una misma tarjeta blanca (como la web)
    return ListView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
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
            children: [
              for (var i = 0; i < items.length; i++)
                _ComunicadoFila(
                  comunicado: items[i],
                  ultimo: i == items.length - 1,
                  onTap: () => _abrir(items[i]),
                ),
            ],
          ),
        ),
        if (conPie)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
      ],
    );
  }

  Widget _mensaje(Widget hijo) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 240, child: Center(child: hijo)),
        ],
      );
}

/// Una fila: fecha, título, resumen y "+" (notice.vue de la web)
class _ComunicadoFila extends StatelessWidget {
  const _ComunicadoFila({
    required this.comunicado,
    required this.ultimo,
    required this.onTap,
  });

  final Map<String, dynamic> comunicado;
  final bool ultimo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final idioma = HomeService.idioma(comunicado) ?? {};
    final fecha = HomeService.fecha(idioma['fecha_publi']);
    final titulo = '${idioma['titulo'] ?? ''}'.trim();
    final soloImagenes = HomeService.siNo(comunicado['solo_imagenes']);
    final pildora = HomeService.siNo(comunicado['pildora']);
    final resumen = soloImagenes
        ? ''
        : HomeService.textoPlano(idioma['texto']).replaceAll('\n', ' ');

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
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
                  Row(
                    children: [
                      Text(
                        fecha,
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      if (pildora) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.lightbulb,
                          size: 14,
                          color: Color(0xFFFAAD14),
                        ),
                      ],
                    ],
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
            const SizedBox(width: 8),
            const Icon(Icons.add, color: AppColors.primary, size: 26),
          ],
        ),
      ),
    );
  }
}
