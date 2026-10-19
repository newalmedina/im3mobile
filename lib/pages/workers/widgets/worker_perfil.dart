import 'package:flutter/material.dart';

import 'package:im3_mobile_app/services/home_service.dart';
import 'package:im3_mobile_app/theme/theme.dart';

import 'worker_companeros.dart';
import 'worker_imagen.dart';
import 'worker_info.dart';
import 'worker_ui.dart';

/// Contenido del perfil de un trabajador: imagen, información general
/// y "Trabaja con". Lo usan:
///   - WorkerPage  -> perfil de otro trabajador (con flecha atrás)
///   - PerfilPage  -> mi perfil (punto de menú, usuario autenticado)
///
/// Solo carga la ficha (info_user); cada bloque carga lo suyo.
class WorkerPerfil extends StatefulWidget {
  const WorkerPerfil({super.key, required this.id, this.onNombre});

  final String id;

  /// Avisa del nombre cuando llega la ficha (para el título de la barra)
  final ValueChanged<String>? onNombre;

  @override
  State<WorkerPerfil> createState() => _WorkerPerfilState();
}

class _WorkerPerfilState extends State<WorkerPerfil> {
  Map<String, dynamic>? _info;
  bool _cargando = true;

  /// Al cambiar este número los bloques se vuelven a crear
  /// y recargan sus datos (tirar hacia abajo para refrescar).
  int _recarga = 0;

  @override
  void initState() {
    super.initState();
    _cargarInfo();
  }

  Future<void> _cargarInfo() async {
    final info = await HomeService.getTrabajador(widget.id);
    if (!mounted) return;
    setState(() {
      _info = info;
      _cargando = false;
    });
    if (info != null) widget.onNombre?.call(WorkerUtils.nombreCompleto(info));
  }

  void _reintentar() {
    setState(() => _cargando = true);
    _cargarInfo();
  }

  Future<void> _refrescar() async {
    setState(() => _recarga++);
    await _cargarInfo();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final info = _info;
    if (info == null) {
      return WorkerFallo(
        texto: 'No se ha podido cargar el perfil',
        onReintentar: _reintentar,
        centrado: true,
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refrescar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // 1. Imagen + nombre
          WorkerTarjeta(child: WorkerImagen(info: info)),

          // 2. Información general (+ horario)
          WorkerTarjeta(
            child: WorkerInfo(
              key: ValueKey('info$_recarga'),
              id: widget.id,
              info: info,
            ),
          ),

          // 3. Trabaja con
          WorkerTarjeta(
            child: WorkerCompaneros(
              key: ValueKey('companeros$_recarga'),
              id: widget.id,
            ),
          ),
        ],
      ),
    );
  }
}
