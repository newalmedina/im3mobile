import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Ajusta estas dos constantes a tu configuración (o usa las que ya tengas en tu proyecto)
const String baseBackUrl = 'https://dev.im3solutions.com';
const String baseFrontUrl = 'https://dev.im3solutions.com/';

/// Llama al mismo endpoint que la web.
/// Devuelve true si el backend aceptó la petición.
Future<bool> solicitarResetPassword(String email) async {
  try {
    final response = await http.post(
      Uri.parse('$baseBackUrl/intranet/api/api_users/v1/resetpass'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        // La web manda su propia URL; el enlace del correo abrirá la web
        'url': baseFrontUrl,
      }),
    );
    return response.statusCode >= 200 && response.statusCode < 300;
  } catch (_) {
    return false;
  }
}

/// Muestra el diálogo para pedir el email y enviar el correo de recuperación.
Future<void> mostrarRecuperarPassword(BuildContext context, {String? emailInicial}) {
  final controller = TextEditingController(text: emailInicial ?? '');
  bool cargando = false;
  String? error;
  bool enviado = false;

  return showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Recuperar contraseña'),
        content: enviado
            ? const Text(
                'Te hemos enviado un correo con un enlace para crear una nueva contraseña. '
                'Revisa también la carpeta de spam.',
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Escribe tu email y te enviaremos un enlace para cambiar la contraseña.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(
                      labelText: 'Email',
                      errorText: error,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
        actions: enviado
            ? [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cerrar'),
                ),
              ]
            : [
                TextButton(
                  onPressed: cargando ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: cargando
                      ? null
                      : () async {
                          final email = controller.text.trim();
                          if (email.isEmpty || !email.contains('@')) {
                            setState(() => error = 'Escribe un email válido');
                            return;
                          }
                          setState(() {
                            cargando = true;
                            error = null;
                          });
                          final ok = await solicitarResetPassword(email);
                          setState(() {
                            cargando = false;
                            if (ok) {
                              enviado = true;
                            } else {
                              error = 'No se pudo enviar el correo. Revisa el email e inténtalo de nuevo.';
                            }
                          });
                        },
                  child: cargando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enviar enlace'),
                ),
              ],
      ),
    ),
  );
}
