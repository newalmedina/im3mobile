import 'package:flutter/material.dart';
import 'package:im3_mobile_app/pages/news/news_page.dart';
import 'package:im3_mobile_app/pages/notices/notices_page.dart';
import 'package:im3_mobile_app/pages/password/password_page.dart';
import 'package:im3_mobile_app/pages/perfil/perfil_page.dart';
import 'package:im3_mobile_app/pages/vacaciones/vacaciones_page.dart';
import 'package:im3_mobile_app/pages/widgets/scroll_to_top.dart';

import '../pages/im3horas/im3horas_page.dart';
import '../pages/home/home_page.dart';
import '../pages/login/login_page.dart';
import '../pages/nominas/nominas_page.dart';
import '../pages/permisos/permisos_page.dart';
import '../services/accesos_service.dart';
import '../services/auth_service.dart';
import '../theme/theme.dart';

/// Layout compartido por todas las pantallas internas:
///   - Izquierda: botón del menú lateral
///   - Centro: logo de la empresa
///   - Derecha: cerrar sesión
///
/// Cada vez que se abre una pantalla con este layout, se valida el token
/// y se vuelven a pedir los permisos del usuario.
///
/// El menú solo muestra las opciones a las que el usuario tiene acceso, y si
/// abre una página sin permiso (por ejemplo, se lo han quitado en la
/// intranet) se muestra un aviso en lugar del contenido.
///
/// Uso en una página:
///   return MainLayout(currentRoute: 'inicio', child: ...);
class MainLayout extends StatefulWidget {
  final Widget child;

  /// Ruta actual, para marcar la opción del menú y saber qué permiso pide
  final String currentRoute;

  const MainLayout({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  /// Usuario tal cual está guardado (sin modelo)
  Map<String, dynamic>? _user;

  // =========================================================
  // MENÚ: para añadir una pantalla, añade una entrada aquí.
  // 'permiso': el permiso de la intranet que hace falta para verla.
  // Sin 'permiso' = la ven todos.
  // =========================================================
  static final List<Map<String, dynamic>> _menu = [
    // Trabajo
    {
      'route': 'inicio',
      'title': 'Inicio',
      'icon': Icons.home_outlined,
      'page': () => const HomePage(),
    },
    {
      'route': 'im3horas',
      'title': 'IM3 Horas',
      'icon': Icons.access_time,
      'page': () => Im3HorasPage(),
    },
    {
      'route': 'vacaciones',
      'title': 'Vacaciones',
      'icon': Icons.beach_access_outlined,
      'page': () => const VacacionesPage(),
      'permiso': Acceso.vacaciones,
    },
    {
      'route': 'permisos',
      'title': 'Permisos',
      'icon': Icons.event_note_outlined,
      'page': () => const PermisosPage(),
      'permiso': Acceso.permisos,
    },
    {
      'route': 'nominas',
      'title': 'Nóminas',
      'icon': Icons.receipt_long_outlined,
      'page': () => const NominasPage(),
      'permiso': Acceso.nominas,
    },

    // Información
    {
      'route': 'comunicados',
      'title': 'Comunicados',
      'icon': Icons.campaign_outlined,
      'page': () => const NoticesPage(),
      'permiso': Acceso.comunicados,
    },
    {
      'route': 'noticias',
      'title': 'Noticias',
      'icon': Icons.newspaper_outlined,
      'page': () => const NewsPage(),
      'permiso': Acceso.noticias,
    },

    // Cuenta
    {
      'route': 'perfil',
      'title': 'Mi perfil',
      'icon': Icons.person_outline,
      'page': () => const PerfilPage(),
      'permiso': Acceso.perfil,
    },
  ];

  /// Opción fija abajo del menú, encima de "Cerrar sesión"
  static final Map<String, dynamic> _passwordItem = {
    'route': 'password',
    'title': 'Cambiar contraseña',
    'icon': Icons.lock_reset,
    'page': () => const PasswordPage(),
  };

  /// Permiso que pide la página actual (según su currentRoute)
  String? get _permisoActual {
    for (final item in _menu) {
      if (item['route'] == widget.currentRoute) {
        return item['permiso'] as String?;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 1. Pintar con lo guardado (inmediato)
    final user = await AuthService.getUser();
    user?['id_user']; // id en la intranet
    user?['id_sign']; // id en sign
    user?['es_responsable'];
    user?['dias_vacaciones_pendientes'];

    if (mounted) setState(() => _user = user);

    // 2. Validar el token en cada pantalla
    final valid = await AuthService.validateToken();
    if (!mounted) return;
    if (!valid) {
      await _sessionExpired();
      return;
    }

    // 3. Volver a pedir los permisos en cada pantalla.
    //    Si han cambiado, el menú y la página se actualizan solos.
    await AccesosService.refrescar();
    if (!mounted) return;

    // 4. validateToken pudo actualizar los datos
    final fresh = await AuthService.getUser();
    if (mounted) setState(() => _user = fresh);
  }

  // =========================================================
  // NAVEGACIÓN
  // =========================================================
  void _navigate(Map<String, dynamic> item) {
    Navigator.pop(context); // cierra el menú
    if (item['route'] == widget.currentRoute) return;

    final builder = item['page'] as Widget Function();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => builder(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  void _goToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _goToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomePage(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
      (route) => false,
    );
  }

  // =========================================================
  // SESIÓN
  // =========================================================
  Future<void> _confirmLogout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (result != true) return;
    await AuthService.logout();
    AccesosService.limpiar();
    if (mounted) _goToLogin();
  }

  Future<void> _sessionExpired() async {
    AccesosService.limpiar();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Sesión cerrada'),
        content: const Text(
          'Tu sesión ha caducado o ya no tienes acceso. Inicia sesión de nuevo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    if (mounted) _goToLogin();
  }

  // =========================================================
  // UI
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: _drawer(),

      // HEADER
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black12,
        centerTitle: true,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            color: AppColors.primary,
            tooltip: 'Menú',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Image.asset(
          'assets/images/logo.png',
          height: 32,
          errorBuilder: (_, __, ___) => const Text(
            'IM3',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            color: AppColors.danger,
            tooltip: 'Cerrar sesión',
            onPressed: _confirmLogout,
          ),
        ],
      ),

      // CONTENIDO DE CADA PÁGINA (solo si tiene permiso)
      // ScrollToTop: botón abajo a la derecha para volver arriba
      body: SafeArea(
        child: ValueListenableBuilder<Set<String>>(
          valueListenable: AccesosService.permisos,
          builder: (context, _, __) => AccesosService.tiene(_permisoActual)
              ? ScrollToTop(child: widget.child)
              : _sinAcceso(),
        ),
      ),
    );
  }

  /// Se muestra en lugar de la página si el usuario no tiene el permiso
  Widget _sinAcceso() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 56, color: Colors.grey[500]),
            const SizedBox(height: 16),
            const Text(
              'No tienes acceso a esta sección',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Si crees que deberías tenerlo, contacta con RRHH.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: _goToHome,
              child: const Text('Volver al inicio'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- MENÚ LATERAL ----------------
  Widget _drawer() {
    final nombre =
        _user?['user_full_name'] ?? _user?['fullname'] ?? _user?['name'] ?? '';
    final email = _user?['email'] ?? '';

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: logo + usuario
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset('assets/images/logo.png', height: 44),
                  const SizedBox(height: 20),
                  Text(
                    nombre.toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email.toString(),
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              height: 3,
              width: 40,
              margin: const EdgeInsets.only(left: 24),
              color: AppColors.secondary,
            ),
            const SizedBox(height: 16),

            // Opciones (solo las que tiene permiso; se actualiza solo)
            Expanded(
              child: ValueListenableBuilder<Set<String>>(
                valueListenable: AccesosService.permisos,
                builder: (context, _, __) {
                  final menuVisible = _menu
                      .where(
                        (m) => AccesosService.tiene(m['permiso'] as String?),
                      )
                      .toList();
                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [for (final item in menuVisible) _item(item)],
                  );
                },
              ),
            ),

            // Abajo: cambiar contraseña + cerrar sesión
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: _item(_passwordItem),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: const Text(
                'Cerrar sesión',
                style: TextStyle(color: AppColors.danger),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmLogout();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(Map<String, dynamic> item) {
    final selected = item['route'] == widget.currentRoute;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        selected: selected,
        selectedTileColor: AppColors.primary,
        selectedColor: Colors.white,
        iconColor: AppColors.primary,
        textColor: AppColors.text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(item['icon'] as IconData),
        title: Text(
          item['title'] as String,
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () => _navigate(item),
      ),
    );
  }
}
