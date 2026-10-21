import 'package:flutter/material.dart';

import '../config/api.dart';
import '../theme/theme.dart';
import 'api_service.dart';

/// Nombres de los permisos (roles) que usa la app.
/// Se llama "Accesos" para no confundirlo con PermisosService (solicitudes de permisos).
class Acceso {
  static const String noticias = 'front-comun-noti';
  static const String comunicados = 'front-comun-noti';
  static const String objetivos = 'front-objetivos';
  static const String vacaciones = 'front-calendario';
  static const String permisos = 'front-permisos-solicitar';
  static const String perfil = 'front-perfil'; // perfil y nóminas
  static const String nominas = 'front-perfil';
  static const String trabajadores = 'front-trabajadores';
}

/// Permisos del usuario logueado.
///
/// Se vuelven a pedir a la API:
///   - al hacer login o entrar con sesión guardada (cargar)
///   - cada vez que se abre una página protegida (PaginaProtegida)
///   - al volver a la app desde segundo plano (iniciarObservador)
///
/// Cuando cambian, el menú y los bloques ConAcceso se repintan solos.
class AccesosService {
  static final ValueNotifier<Set<String>> permisos = ValueNotifier({});
  static bool _cargados = false;
  static DateTime? _ultimaCarga;
  static Future<void>? _enCurso;

  /// Para no repetir la llamada si se abren varias páginas seguidas.
  /// Ponlo a Duration.zero si quieres que pregunte SIEMPRE.
  static const Duration margen = Duration(seconds: 10);

  static bool get cargados => _cargados;

  /// Carga obligatoria (login / sesión guardada).
  static Future<void> cargar() => refrescar(forzar: true);

  /// Vuelve a pedir los permisos. Si se pidieron hace menos de [margen],
  /// no repite la llamada (salvo forzar). Si la API falla, se mantienen
  /// los que ya había para no dejar al usuario sin menú por un fallo de red.
  static Future<void> refrescar({bool forzar = false}) {
    if (!forzar &&
        _ultimaCarga != null &&
        DateTime.now().difference(_ultimaCarga!) < margen) {
      return Future.value();
    }
    // Si ya hay una petición en marcha, se espera a esa
    return _enCurso ??= _pedir().whenComplete(() => _enCurso = null);
  }

  static Future<void> _pedir() async {
    try {
      final res = await ApiService.get(
        '${ApiConfig.intranetBaseUrl}api/api_roles/v1/get-permisos-by-user',
        auth: true,
      );
      final lista = _extraerLista(res);
      if (lista == null) return; // respuesta rara: no tocar lo que había
      final nuevos = lista.toSet();
      if (!_iguales(nuevos, permisos.value)) permisos.value = nuevos;
      _cargados = true;
      _ultimaCarga = DateTime.now();
    } catch (_) {
      // Fallo de red: se mantienen los permisos anteriores
    }
  }

  /// true si el usuario tiene ese permiso
  static bool tiene(String? permiso) {
    if (permiso == null || permiso.isEmpty) return true; // sin permiso = libre
    return permisos.value.contains(permiso);
  }

  /// Borrar al cerrar sesión
  static void limpiar() {
    permisos.value = {};
    _cargados = false;
    _ultimaCarga = null;
  }

  // ---------------------------------------------- volver desde segundo plano
  static _Observador? _observador;

  /// Llamar una vez en main.dart. Al volver a la app refresca los permisos.
  static void iniciarObservador() {
    if (_observador != null) return;
    _observador = _Observador();
    WidgetsBinding.instance.addObserver(_observador!);
  }

  // ------------------------------------------------------------- auxiliares
  /// La API devuelve un array de strings; según cómo lo envuelva ApiService
  /// puede venir directo o dentro de 'data'. null si no se reconoce.
  static List<String>? _extraerLista(dynamic res) {
    dynamic datos = res;
    if (datos is Map && datos['data'] != null) datos = datos['data'];
    if (datos is Map && datos['data'] != null) datos = datos['data'];
    if (datos is List) return datos.map((e) => e.toString()).toList();
    return null;
  }

  static bool _iguales(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}

class _Observador extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && AccesosService.cargados) {
      AccesosService.refrescar(forzar: true);
    }
  }
}

/// Muestra [child] solo si el usuario tiene [permiso].
/// Se actualiza solo si cambian los permisos (bloques de la Home, botones...).
class ConAcceso extends StatelessWidget {
  const ConAcceso({super.key, required this.permiso, required this.child});

  final String permiso;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: AccesosService.permisos,
      builder: (_, __, ___) =>
          AccesosService.tiene(permiso) ? child : const SizedBox.shrink(),
    );
  }
}

/// Envuelve una página entera. Al abrirla vuelve a comprobar los permisos
/// con la API; si el usuario ya no tiene acceso, no se muestra el contenido.
class PaginaProtegida extends StatefulWidget {
  const PaginaProtegida({
    super.key,
    required this.permiso,
    required this.child,
  });

  final String permiso;
  final Widget child;

  @override
  State<PaginaProtegida> createState() => _PaginaProtegidaState();
}

class _PaginaProtegidaState extends State<PaginaProtegida> {
  late bool _comprobando;

  @override
  void initState() {
    super.initState();
    // Si ya tenemos permisos, se muestra la página mientras se comprueba
    // por detrás; si no, se espera a la respuesta.
    _comprobando = !AccesosService.cargados;
    AccesosService.refrescar().whenComplete(() {
      if (mounted) setState(() => _comprobando = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_comprobando) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    return ValueListenableBuilder<Set<String>>(
      valueListenable: AccesosService.permisos,
      builder: (context, _, __) => AccesosService.tiene(widget.permiso)
          ? widget.child
          : const _SinAcceso(),
    );
  }
}

class _SinAcceso extends StatelessWidget {
  const _SinAcceso();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Si crees que deberías tenerlo, contacta con RRHH.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
