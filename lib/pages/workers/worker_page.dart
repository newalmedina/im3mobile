import 'package:flutter/material.dart';

import 'package:im3_mobile_app/theme/theme.dart';

import 'widgets/worker_perfil.dart';

/// Perfil de OTRO trabajador (solo lectura). Equivale a pages/workers/_id.vue.
/// Se abre encima (desde incorporaciones o "Trabaja con") con flecha atrás.
/// El contenido es WorkerPerfil, el mismo que usa "Mi perfil".
class WorkerPage extends StatefulWidget {
  const WorkerPage({super.key, required this.id});

  final String id;

  @override
  State<WorkerPage> createState() => _WorkerPageState();
}

class _WorkerPageState extends State<WorkerPage> {
  String _nombre = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        // Flecha atrás: vuelve a la página anterior (home u otro perfil)
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_nombre.isEmpty ? 'Trabajadores' : _nombre),
      ),
      body: WorkerPerfil(
        id: widget.id,
        onNombre: (n) {
          if (mounted) setState(() => _nombre = n);
        },
      ),
    );
  }
}
