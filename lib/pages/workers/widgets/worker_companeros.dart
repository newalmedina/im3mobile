import 'package:flutter/material.dart';

import 'package:im3_mobile_app/services/home_service.dart';
import 'package:im3_mobile_app/theme/theme.dart';

import '../worker_page.dart';
import 'worker_ui.dart';

/// "Trabaja con" (coworkers.vue en la web).
/// Carga sus propios datos. Muestra solo los primeros para no lanzar
/// decenas de fotos a la vez; el resto con "Ver todos".
/// Al pulsar un compañero abre su perfil en otra página encima.
class WorkerCompaneros extends StatefulWidget {
  const WorkerCompaneros({super.key, required this.id});

  final String id;

  /// Cuántos se ven antes de pulsar "Ver todos"
  static const int maximo = 8;

  /// Cuántos por fila
  static const int porFila = 4;

  @override
  State<WorkerCompaneros> createState() => _WorkerCompanerosState();
}

class _WorkerCompanerosState extends State<WorkerCompaneros> {
  List<Map<String, dynamic>> _lista = [];
  bool _cargando = true;
  bool _verTodos = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final l = await HomeService.getCompaneros(widget.id);
    if (!mounted) return;
    setState(() {
      _lista = l;
      _cargando = false;
    });
  }

  void _reintentar() {
    setState(() => _cargando = true);
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final visibles = (_verTodos || _lista.length <= WorkerCompaneros.maximo)
        ? _lista
        : _lista.take(WorkerCompaneros.maximo).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WorkerTitulo('Trabaja con'),
        if (_cargando)
          const WorkerCargando()
        else if (_lista.isEmpty)
          WorkerFallo(
            texto: 'No hay compañeros o no se han podido cargar',
            onReintentar: _reintentar,
          )
        else ...[
          LayoutBuilder(
            builder: (context, c) {
              const porFila = WorkerCompaneros.porFila;
              const hueco = 12.0;
              final ancho = (c.maxWidth - hueco * (porFila - 1)) / porFila;
              return Wrap(
                spacing: hueco,
                runSpacing: 16,
                children: [
                  for (final p in visibles)
                    SizedBox(width: ancho, child: _Companero(persona: p)),
                ],
              );
            },
          ),
          if (_lista.length > WorkerCompaneros.maximo)
            Center(
              child: TextButton(
                onPressed: () => setState(() => _verTodos = !_verTodos),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
                child: Text(
                  _verTodos ? 'Ver menos' : 'Ver todos (${_lista.length})',
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Un compañero: foto redonda y nombre.
/// Al pulsar abre SU perfil en otra página encima (con flecha atrás).
class _Companero extends StatelessWidget {
  const _Companero({required this.persona});

  final Map<String, dynamic> persona;

  @override
  Widget build(BuildContext context) {
    final id = WorkerUtils.idUsuario(persona);
    final nombre = WorkerUtils.nombreCompleto(persona);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: id.isEmpty
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => WorkerPage(id: id)),
              ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipOval(
              child: Image.network(
                HomeService.fotoUsuario(persona['imagen']),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade200,
                  child: Icon(Icons.person, color: Colors.grey.shade400),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            nombre,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
