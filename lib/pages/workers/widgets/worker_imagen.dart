import 'package:flutter/material.dart';

import 'package:im3_mobile_app/services/home_service.dart';
import 'package:im3_mobile_app/theme/theme.dart';

import 'worker_ui.dart';

/// Foto del trabajador + nombre (parte izquierda de info.vue en la web)
class WorkerImagen extends StatelessWidget {
  const WorkerImagen({super.key, required this.info});

  final Map<String, dynamic> info;

  @override
  Widget build(BuildContext context) {
    final nombre = WorkerUtils.nombreCompleto(info);

    return Column(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  HomeService.fotoUsuario(info['imagen']),
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progreso) =>
                      progreso == null
                          ? child
                          : Container(color: Colors.grey.shade200),
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    child: Icon(
                      Icons.person,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          nombre,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            height: 1.2,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}
