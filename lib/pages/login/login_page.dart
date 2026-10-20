import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../components/custom_button.dart';
import '../../components/custom_checkbox.dart';
import '../../components/custom_input.dart';
import '../../services/auth_service.dart';
import '../../services/biometria_service.dart';
import '../../theme/theme.dart';
import '../../widgets/snackbar_helper.dart';
import '../home/home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _checkingSession = true; // mientras mira si ya hay sesión
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

  // Biometría
  Set<TipoBiometria> _tipos = {}; // lo que tiene el móvil
  bool _bioActivo = false; // el usuario la ha activado
  bool _bioEnCurso = false; // evita pedir la huella dos veces a la vez

  @override
  void initState() {
    super.initState();
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
    await _cargarBiometria();
    if (!mounted) return;
    setState(() => _checkingSession = false);

    // Si la biometría está activada, se pide la huella/cara nada más abrir
    if (_bioActivo) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loginBiometrico(_tipoPorDefecto());
      });
    }
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

  Future<void> _cargarBiometria() async {
    final tipos = await BiometriaService.tiposDisponibles();
    final activo = tipos.isNotEmpty && await BiometriaService.activado();
    if (!mounted) return;
    setState(() {
      _tipos = tipos;
      _bioActivo = activo;
    });
  }

  TipoBiometria _tipoPorDefecto() =>
      _tipos.contains(TipoBiometria.huella) || _tipos.isEmpty
          ? TipoBiometria.huella
          : TipoBiometria.cara;

  // ------------------------------------------------------------ login normal
  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Bordes rojos en los campos vacíos
    setState(() {
      _emailError = email.isEmpty;
      _passwordError = password.isEmpty;
    });
    if (email.isEmpty || password.isEmpty) return;

    FocusScope.of(context).unfocus();
    final ok = await _hacerLogin(email, password);
    if (!ok || !mounted) return;

    // Recordar o borrar credenciales
    if (_rememberUser) {
      await AuthService.saveCredentials(email, password);
    } else {
      await AuthService.clearCredentials();
    }

    // Biometría: si ya estaba activa, se REEMPLAZAN los datos guardados
    // por los de este login; si no, se ofrece activarla.
    if (_bioActivo) {
      await BiometriaService.activar(email, password);
    } else if (_tipos.isNotEmpty && !await BiometriaService.noPreguntar()) {
      await _ofrecerBiometria(email, password);
    }

    await _irAHome();
  }

  // -------------------------------------------------------- login biométrico
  Future<void> _loginBiometrico(TipoBiometria tipo) async {
    if (_loading || _bioEnCurso) return;
    _bioEnCurso = true;
    try {
      final ok = await BiometriaService.autenticar(tipo);
      if (!ok || !mounted) return; // canceló o falló: se queda en el login

      final cred = await BiometriaService.credenciales();
      if (cred == null) {
        await BiometriaService.desactivar();
        if (!mounted) return;
        setState(() => _bioActivo = false);
        SnackbarHelper.show(
          context,
          message: 'Entra con tu email y contraseña para activar de nuevo '
              'el acceso biométrico.',
          backgroundColor: AppColors.danger,
        );
        return;
      }

      final entrado = await _hacerLogin(cred['email']!, cred['password']!);
      if (!entrado) {
        // Lo más habitual: ha cambiado la contraseña en la intranet
        if (mounted) {
          SnackbarHelper.show(
            context,
            message: 'No se ha podido entrar. Si has cambiado la contraseña, '
                'entra con email y contraseña y se actualizará.',
            backgroundColor: AppColors.danger,
          );
        }
        return;
      }
      await _irAHome();
    } finally {
      _bioEnCurso = false;
    }
  }

  // ------------------------------------------------------------- comunes
  /// Login contra la API. true si ha ido bien.
  Future<bool> _hacerLogin(String email, String password) async {
    setState(() => _loading = true);
    final result = await AuthService.login(email, password);
    if (!mounted) return false;
    setState(() => _loading = false);

    if (result['success'] != true) {
      SnackbarHelper.show(
        context,
        message: result['error'].toString(),
        backgroundColor: AppColors.danger,
      );
      return false;
    }
    return true;
  }

  Future<void> _irAHome() async {
    final user = await AuthService.getUser();
    if (!mounted) return;
    SnackbarHelper.show(
      context,
      message: 'Bienvenido, ${user?['name'] ?? ''}',
      backgroundColor: AppColors.success,
    );
    // Ir a la Home (sin poder volver atrás al login)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  /// Después de un login normal: "¿Quieres entrar con huella / cara?"
  Future<void> _ofrecerBiometria(String email, String password) async {
    final nombre = _nombreBiometria();
    final respuesta = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(_iconoPrincipal(), size: 40, color: AppColors.primary),
        title: Text('Entrar con $nombre'),
        content: Text(
          'La próxima vez podrás entrar con $nombre sin escribir '
          'tu email ni tu contraseña.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('nunca'),
            child: const Text('No volver a preguntar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('ahora_no'),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.of(ctx).pop('si'),
            child: const Text('Activar'),
          ),
        ],
      ),
    );

    if (respuesta == 'nunca') {
      await BiometriaService.setNoPreguntar();
      return;
    }
    if (respuesta != 'si') return;

    // Confirmar con la biometría antes de guardar nada
    final ok = await BiometriaService.autenticar(_tipoPorDefecto());
    if (!ok) {
      // Antes fallaba en silencio y parecía activado sin estarlo
      if (mounted) {
        SnackbarHelper.show(
          context,
          message: 'No se ha podido verificar la $nombre. '
              'El acceso biométrico no se ha activado.',
          backgroundColor: AppColors.danger,
        );
      }
      return;
    }
    await BiometriaService.activar(email, password);
    _bioActivo = true;
  }

  Future<void> _desactivarBiometria() async {
    await BiometriaService.desactivar();
    if (!mounted) return;
    setState(() => _bioActivo = false);
    SnackbarHelper.show(
      context,
      message: 'Acceso biométrico desactivado.',
      backgroundColor: AppColors.success,
    );
  }

  String _nombreBiometria() {
    final huella = _tipos.contains(TipoBiometria.huella);
    final cara = _tipos.contains(TipoBiometria.cara);
    if (huella && cara) return 'huella o reconocimiento facial';
    if (cara) return 'reconocimiento facial';
    return 'huella';
  }

  IconData _iconoPrincipal() => _tipos.contains(TipoBiometria.huella)
      ? Icons.fingerprint
      : Icons.face_outlined;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- vista
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

                // Botón normal
                _loading
                    ? const CircularProgressIndicator(color: AppColors.primary)
                    : CustomButton(text: 'Ingresar', onPressed: _login),

                // Botones biométricos (por si cancela la ventana automática)
                if (_bioActivo && _tipos.isNotEmpty && !_loading) ...[
                  const SizedBox(height: 24),
                  _separador(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (_tipos.contains(TipoBiometria.huella))
                        Expanded(
                          child: _botonBio(
                            icono: Icons.fingerprint,
                            texto: 'Huella',
                            onTap: () =>
                                _loginBiometrico(TipoBiometria.huella),
                          ),
                        ),
                      if (_tipos.length > 1) const SizedBox(width: 12),
                      if (_tipos.contains(TipoBiometria.cara))
                        Expanded(
                          child: _botonBio(
                            icono: Icons.face_outlined,
                            texto: 'Facial',
                            onTap: () => _loginBiometrico(TipoBiometria.cara),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _desactivarBiometria,
                    child: Text(
                      'Desactivar acceso biométrico',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _separador() => Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'o entra con',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300)),
        ],
      );

  Widget _botonBio({
    required IconData icono,
    required String texto,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 36),
          const SizedBox(height: 4),
          Text(texto, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
