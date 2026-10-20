import 'package:flutter/material.dart';

import 'package:im3_mobile_app/services/auth_service.dart';
import 'package:im3_mobile_app/services/home_service.dart';
import 'package:im3_mobile_app/theme/theme.dart';

import 'worker_companeros.dart';
import 'worker_imagen.dart';
import 'worker_info.dart';
import 'worker_ui.dart';

/// Contenido del perfil de un trabajador: imagen, información general
/// y "Trabaja con". Lo usan WorkerPage (otro trabajador) y PerfilPage
/// (Mi perfil).
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

  /// true si la ficha es la del usuario autenticado
  /// (isOwnProfile en la web). Solo entonces se puede cambiar la foto.
  bool _esMio = false;

  /// Al cambiar este número los bloques se vuelven a crear
  /// y recargan sus datos (tirar hacia abajo para refrescar).
  int _recarga = 0;

  @override
  void initState() {
    super.initState();
    _cargarInfo();
  }

  /// Compara los ids como número, igual que el parseInt de la web
  static bool _mismoId(String? a, String? b) {
    final x = (a ?? '').trim();
    final y = (b ?? '').trim();
    if (x.isEmpty || y.isEmpty) return false;
    final nx = int.tryParse(x);
    final ny = int.tryParse(y);
    return nx != null && ny != null ? nx == ny : x == y;
  }

  Future<void> _cargarInfo() async {
    // La ficha y el id del usuario autenticado, a la vez
    final r = await Future.wait([
      HomeService.getTrabajador(widget.id),
      AuthService.getUserId(),
    ]);
    if (!mounted) return;

    final info = r[0] as Map<String, dynamic>?;
    final miId = r[1] as String?;

    setState(() {
      _info = info;
      _esMio = _mismoId(widget.id, miId);
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
          // 1. Imagen + nombre (cámara solo si es tu propio perfil)
          WorkerTarjeta(
            child: WorkerImagen(
              id: widget.id,
              info: info,
              editable: _esMio,
              onCambiada: () => _refrescar(),
            ),
          ),

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
