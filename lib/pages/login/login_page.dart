import 'package:flutter/material.dart';

import '../../components/custom_button.dart';
import '../../components/custom_checkbox.dart';
import '../../components/custom_input.dart';
import '../../services/auth_service.dart';
import '../../theme/theme.dart';
import '../../widgets/snackbar_helper.dart';
import 'package:flutter/foundation.dart';
import '../home/home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _checkingSession = true; // mientras mira si ya hay sesión
  // final _emailController = TextEditingController();
  // final _passwordController = TextEditingController();
  final _emailController = TextEditingController(
    text: kDebugMode ? 'newal.medina@ingenieros-im3.com' : '',
  );
  final _passwordController = TextEditingController(
    text: kDebugMode ? 'cygnus' : '',
  );
  final _passwordFocus = FocusNode();

  bool _rememberUser = false;
  bool _loading = false;

  // Flags de error (pintan el borde en rojo)
  bool _emailError = false;
  bool _passwordError = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final user = await AuthService.getUser();
    final token = user?['token'];

    if (token != null && token.toString().isNotEmpty) {
      final valid = await AuthService.validateToken();
      if (!mounted) return;
      if (valid) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
        return;
      }
    }

    // No hay sesión (o no es válida): mostrar el formulario
    await _loadSavedCredentials();
    if (mounted) setState(() => _checkingSession = false);
  }

  // Si marcó "recordar", rellena los campos
  Future<void> _loadSavedCredentials() async {
    final saved = await AuthService.getCredentials();
    if (saved == null || !mounted) return;
    setState(() {
      _emailController.text = saved['email']!;
      _passwordController.text = saved['password']!;
      _rememberUser = true;
    });
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Bordes rojos en los campos vacíos
    setState(() {
      _emailError = email.isEmpty;
      _passwordError = password.isEmpty;
    });

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    // Toda la lógica está en el servicio
    final result = await AuthService.login(email, password);

    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success'] != true) {
      SnackbarHelper.show(
        context,
        message: result['error'].toString(),
        backgroundColor: AppColors.danger,
      );
      return;
    }

    // Recordar o borrar credenciales
    if (_rememberUser) {
      await AuthService.saveCredentials(email, password);
    } else {
      await AuthService.clearCredentials();
    }

    final user = await AuthService.getUser();
    if (!mounted) return;
    SnackbarHelper.show(
      context,
      message: 'Bienvenido, ${user?['name'] ?? ''}',
      backgroundColor: AppColors.success,
    );

    // TODO (siguiente paso): navegar a la Home con el menú lateral
    // Ir a la Home (sin poder volver atrás al login)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/logo.png', width: 200),
              const SizedBox(height: 30),
              const CircularProgressIndicator(color: AppColors.primary),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo (si aún no existe el archivo, muestra un icono)
                SizedBox(
                  height: 200,
                  width: 200,
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.business,
                      size: 120,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Email
                CustomInput(
                  controller: _emailController,
                  label: 'Email',
                  hasError: _emailError,
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _passwordFocus.requestFocus(),
                ),
                const SizedBox(height: 20),

                // Contraseña
                CustomInput(
                  controller: _passwordController,
                  label: 'Contraseña',
                  isPassword: true,
                  hasError: _passwordError,
                  focusNode: _passwordFocus,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 20),

                // Recordar email y contraseña
                Row(
                  children: [
                    CustomCheckbox(
                      value: _rememberUser,
                      onChanged: (v) =>
                          setState(() => _rememberUser = v ?? false),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _rememberUser = !_rememberUser),
                      child: const Text('Recordar email y contraseña'),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // Botón
                _loading
                    ? const CircularProgressIndicator(color: AppColors.primary)
                    : CustomButton(text: 'Ingresar', onPressed: _login),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
