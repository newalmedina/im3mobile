import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:im3_mobile_app/services/home_service.dart';
import 'package:im3_mobile_app/theme/theme.dart';

import 'worker_ui.dart';

/// Foto del trabajador + nombre (parte izquierda de info.vue en la web).
/// Con [editable] sale el botón de la cámara para cambiar la foto.
/// Quien decide si es editable es WorkerPerfil (solo tu propio perfil).
class WorkerImagen extends StatefulWidget {
  const WorkerImagen({
    super.key,
    required this.info,
    this.id = '',
    this.editable = false,
    this.onCambiada,
  });

  final Map<String, dynamic> info;

  /// Id del usuario (si no llega, se usa info['id'])
  final String id;

  final bool editable;

  /// Se llama cuando la foto se ha subido bien (para recargar la ficha)
  final VoidCallback? onCambiada;

  @override
  State<WorkerImagen> createState() => _WorkerImagenState();
}

class _WorkerImagenState extends State<WorkerImagen> {
  bool _subiendo = false;

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  /// Cámara o galería
  Future<ImageSource?> _elegirOrigen() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_camera_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Hacer una foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _cambiarFoto() async {
    if (!widget.editable || _subiendo) return;

    final origen = await _elegirOrigen();
    if (origen == null || !mounted) return;

    XFile? foto;
    try {
      // Se reduce antes de enviarla para que no pese demasiado
      foto = await ImagePicker().pickImage(
        source: origen,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
    } catch (_) {
      if (mounted) {
        _aviso(
          origen == ImageSource.camera
              ? 'No se ha podido abrir la cámara'
              : 'No se ha podido abrir la galería',
        );
      }
      return;
    }
    if (foto == null || !mounted) return;

    // Máximo 3 MB, como en la web
    final bytes = await foto.length();
    if (!mounted) return;
    if (bytes / 1024 / 1024 > 3) {
      _aviso('La imagen no puede superar los 3 MB');
      return;
    }

    setState(() => _subiendo = true);

    // Igual que la web: el id de la ficha (info.id)
    final idInfo = WorkerUtils.texto(widget.info['id']);
    final id = idInfo.isNotEmpty ? idInfo : widget.id;
    final ok = await HomeService.subirFotoPerfil(id, foto);

    if (!mounted) return;
    setState(() => _subiendo = false);

    if (ok) {
      // Por si el servidor guarda la foto con el mismo nombre
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      _aviso('Foto actualizada');
      widget.onCambiada?.call();
    } else {
      _aviso('No se ha podido subir la foto');
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre = WorkerUtils.nombreCompleto(widget.info);

    return Column(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Foto (en tu perfil también se puede pulsar)
                  GestureDetector(
                    onTap: widget.editable ? _cambiarFoto : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        HomeService.fotoUsuario(widget.info['imagen']),
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

                  // Subiendo...
                  if (_subiendo)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        color: Colors.black45,
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                    ),

                  // Botón de la cámara (solo en tu propio perfil)
                  if (widget.editable && !_subiendo)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Tooltip(
                        message: 'Cambiar foto',
                        child: Material(
                          color: AppColors.primary,
                          shape: const CircleBorder(),
                          elevation: 3,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _cambiarFoto,
                            child: const SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(
                                Icons.photo_camera,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
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
