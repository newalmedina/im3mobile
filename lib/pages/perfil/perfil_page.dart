import 'package:flutter/material.dart';

import 'package:im3_mobile_app/layouts/main_layout.dart';
import 'package:im3_mobile_app/pages/workers/widgets/worker_perfil.dart';
import 'package:im3_mobile_app/services/auth_service.dart';
import 'package:im3_mobile_app/theme/theme.dart';

/// Mi perfil (punto de menú). Muestra lo mismo que el perfil de
/// cualquier trabajador, pero con el usuario autenticado.
class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  String? _id;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarId();
  }

  /// Id del usuario de la intranet guardado en la sesión
  Future<void> _cargarId() async {
    final id = await AuthService.getUserId();
    if (!mounted) return;
    setState(() {
      final texto = id == null ? '' : '$id'.trim();
      _id = texto.isEmpty ? null : texto;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget contenido;
    if (_cargando) {
      contenido = const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    } else if (_id == null) {
      contenido = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No se ha podido identificar tu usuario. '
            'Cierra sesión y vuelve a entrar.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      contenido = WorkerPerfil(id: _id!);
    }

    return MainLayout(
      currentRoute: 'perfil',
      child: contenido,
    );
  }
}
