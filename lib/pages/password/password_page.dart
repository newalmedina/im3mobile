import 'package:flutter/material.dart';

import '../../components/custom_button.dart';
import '../../components/custom_input.dart';
import '../../layouts/main_layout.dart';
import '../../services/auth_service.dart';
import '../../theme/theme.dart';
import '../../widgets/snackbar_helper.dart';

class PasswordPage extends StatefulWidget {
  const PasswordPage({super.key});

  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  /// Longitud mínima exigida en la app (cámbiala si el backend pide otra)
  static const int _minLength = 8;

  final _passController = TextEditingController();
  final _confirmController = TextEditingController();
  final _confirmFocus = FocusNode();

  bool _loading = false;
  bool _passError = false;
  bool _confirmError = false;

  Future<void> _save() async {
    final pass = _passController.text;
    final confirm = _confirmController.text;

    // Validaciones en la app
    String? error;
    if (pass.isEmpty || confirm.isEmpty) {
      error = 'Rellena los dos campos.';
    } else if (pass.length < _minLength) {
      error = 'La contraseña debe tener al menos $_minLength caracteres.';
    } else if (pass != confirm) {
      error = 'Las contraseñas no coinciden.';
    }

    setState(() {
      _passError = pass.isEmpty || (error != null && pass.length < _minLength);
      _confirmError = confirm.isEmpty || (pass.isNotEmpty && pass != confirm);
    });

    if (error != null) {
      SnackbarHelper.show(context, message: error, backgroundColor: AppColors.danger);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    final result = await AuthService.updatePassword(pass);

    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success'] != true) {
      SnackbarHelper.show(
        context,
        message: result['error'].toString(),
        backgroundColor: AppColors.danger,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    _passController.clear();
    _confirmController.clear();
    setState(() {
      _passError = false;
      _confirmError = false;
    });
    SnackbarHelper.show(
      context,
      message: 'Contraseña actualizada.',
      backgroundColor: AppColors.success,
    );
  }

  @override
  void dispose() {
    _passController.dispose();
    _confirmController.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      currentRoute: 'password',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cambiar contraseña',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mínimo $_minLength caracteres. No puede ser igual a la anterior.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 28),

                CustomInput(
                  controller: _passController,
                  label: 'Nueva contraseña',
                  isPassword: true,
                  hasError: _passError,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _confirmFocus.requestFocus(),
                ),
                const SizedBox(height: 20),

                CustomInput(
                  controller: _confirmController,
                  label: 'Repite la nueva contraseña',
                  isPassword: true,
                  hasError: _confirmError,
                  focusNode: _confirmFocus,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 30),

                Center(
                  child: _loading
                      ? const CircularProgressIndicator(color: AppColors.primary)
                      : CustomButton(
                          text: 'Guardar contraseña',
                          icon: Icons.lock_reset,
                          onPressed: _save,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
