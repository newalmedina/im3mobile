import 'package:flutter/material.dart';

import 'package:im3_mobile_app/config/api.dart';
import 'package:im3_mobile_app/services/api_service.dart';
import 'package:im3_mobile_app/theme/theme.dart';

/// Campana de notificaciones (NotificationsBell.vue en la web).
/// Botón redondo igual que el del reloj, con contador.
class HomeNotificacionesBoton extends StatefulWidget {
  const HomeNotificacionesBoton({super.key});

  @override
  State<HomeNotificacionesBoton> createState() =>
      _HomeNotificacionesBotonState();
}

// =========================================================
// DATOS
// =========================================================

class _Notificacion {
  const _Notificacion({
    required this.id,
    required this.tipo,
    required this.titulo,
    this.texto = '',
  });
  final String id;
  final String tipo;
  final String titulo;
  final String texto;
}

class _Tipo {
  const _Tipo(this.icono, this.color);
  final IconData icono;
  final Color color;
}

// Mismos colores que la web
const _tipos = {
  'festivo': _Tipo(Icons.calendar_today, Color(0xFF722ED1)), // morado
  'aviso': _Tipo(Icons.campaign_outlined, Color(0xFFFAAD14)), // naranja
  'cumpleanos': _Tipo(Icons.card_giftcard, Color(0xFFEB2F96)), // rosa
  'vacaciones': _Tipo(Icons.flight_takeoff, Color(0xFF13C2C2)), // turquesa
  'firma': _Tipo(Icons.edit_outlined, Color(0xFF1890FF)), // azul
  'curso': _Tipo(Icons.menu_book_outlined, Color(0xFF52C41A)), // verde
};

const _turquesa = Color(0xFF13C2C2);

/// GET a la intranet con el token (igual que axios + auth-token en la web)
Future<Map<String, dynamic>> _get(String ruta) =>
    ApiService.get(ApiConfig.intranetBaseUrl + ruta, auth: true);

/// Saca la lista de la respuesta. Si el servidor devuelve un array,
/// ApiService lo mete en 'data'; si es un objeto, se usa [clave].
List _lista(Map<String, dynamic> r, [String clave = 'data']) {
  if (r['ok'] != true) return const [];
  final v = r[clave];
  return v is List ? v : const [];
}

/// "Ana, Luis y Marta"
String _unirConY(List<String> nombres) {
  if (nombres.length < 2) return nombres.join();
  return '${nombres.sublist(0, nombres.length - 1).join(', ')} y ${nombres.last}';
}

// =========================================================
// BOTÓN
// =========================================================

class _HomeNotificacionesBotonState extends State<HomeNotificacionesBoton> {
  List<_Notificacion> _notificaciones = [];
  List<Map<String, dynamic>> _vacaciones = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final r = await Future.wait([
      _get('api/api_visores/v1/documentos_pendientes_firma'),
      _get('api/api_im_university/v1/cursos_pendientes'),
      _get('api/api_users/v1/avisos'),
      _get('api/api_calendarios/v1/oficinas'),
      _get('api/api_users/v1/cumpleanos'),
      _get('api/api_users/v1/vacaciones_hoy'),
    ]);

    // Se añaden ya en orden: firmas, cursos y luego el resto
    final lista = <_Notificacion>[];

    // Firmas pendientes
    for (final d in _lista(r[0], 'documentos')) {
      if (d is! Map) continue;
      final idioma = (d['idioma'] ?? '').toString().toUpperCase();
      lista.add(
        _Notificacion(
          id: 'firma-${d['documento_id']}',
          tipo: 'firma',
          titulo: 'Firmas pendientes',
          texto: '${d['nombre_documento'] ?? ''} ($idioma)',
        ),
      );
    }

    // Cursos pendientes
    for (final c in _lista(r[1], 'cursos')) {
      if (c is! Map) continue;
      var texto = '${c['nombre'] ?? ''} (${c['progreso'] ?? 0}%)';
      final limite = c['fecha_limite']?.toString() ?? '';
      if (limite.isNotEmpty && limite != 'null') {
        texto += ' - Fecha límite: $limite';
      }
      lista.add(
        _Notificacion(
          id: 'curso-${c['curso_id']}',
          tipo: 'curso',
          titulo: 'Cursos pendientes',
          texto: texto,
        ),
      );
    }

    // Avisos
    for (final a in _lista(r[2])) {
      if (a is! Map) continue;
      lista.add(
        _Notificacion(
          id: 'aviso-${a['id']}',
          tipo: 'aviso',
          titulo: 'Avisos',
          texto: '${a['texto'] ?? ''}',
        ),
      );
    }

    // Festivos
    final festivos = _lista(r[3]).map((e) => e.toString()).toList();
    if (festivos.isNotEmpty) {
      lista.add(
        _Notificacion(
          id: 'festivo',
          tipo: 'festivo',
          titulo: 'Festivos',
          texto:
              (festivos.length == 1
                  ? 'Hoy es festivo en la oficina de '
                  : 'Hoy es festivo en las oficinas de ') +
              festivos.join(', '),
        ),
      );
    }

    // Cumpleaños
    final cumples = _lista(r[4]).map((e) => e.toString()).toList();
    if (cumples.isNotEmpty) {
      lista.add(
        _Notificacion(
          id: 'cumpleanos',
          tipo: 'cumpleanos',
          titulo: 'Cumpleaños',
          texto: 'Hoy es el cumpleaños de ${_unirConY(cumples)}',
        ),
      );
    }

    // Vacaciones (la lista completa se guarda para el modal)
    final vacaciones = _lista(
      r[5],
    ).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (vacaciones.isNotEmpty) {
      lista.add(
        const _Notificacion(
          id: 'vacaciones',
          tipo: 'vacaciones',
          titulo: 'De vacaciones hoy',
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _notificaciones = lista;
      _vacaciones = vacaciones;
    });
  }

  void _abrirPanel() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => _PanelNotificaciones(
        notificaciones: _notificaciones,
        vacaciones: _vacaciones,
      ),
      // Entra desde la derecha, como el a-drawer de la web
      transitionBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = _notificaciones.length;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Tooltip(
        message: 'Notificaciones',
        child: Material(
          color: AppColors.primary,
          shape: const CircleBorder(),
          elevation: 4,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _abrirPanel,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Badge(
                  isLabelVisible: n > 0,
                  label: Text(n > 99 ? '99+' : '$n'),
                  backgroundColor: Colors.white,
                  textColor: Colors.red.shade600,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  child: const Icon(
                    Icons.notifications_none,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================
// PANEL LATERAL
// =========================================================

class _PanelNotificaciones extends StatelessWidget {
  const _PanelNotificaciones({
    required this.notificaciones,
    required this.vacaciones,
  });

  final List<_Notificacion> notificaciones;
  final List<Map<String, dynamic>> vacaciones;

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.white,
        child: SizedBox(
          width: ancho < 410 ? ancho * 0.88 : 360,
          height: double.infinity,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cabecera
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_none,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Notificaciones',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 20,
                          color: Colors.grey[500],
                        ),
                        splashRadius: 18,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade200),

                // Lista
                Expanded(
                  child: notificaciones.isEmpty
                      ? const _SinNotificaciones()
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: notificaciones.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) => _Tarjeta(
                            notificacion: notificaciones[i],
                            onVer: () => showDialog(
                              context: context,
                              builder: (_) =>
                                  _VacacionesDialog(lista: vacaciones),
                            ),
                          ),
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

class _SinNotificaciones extends StatelessWidget {
  const _SinNotificaciones();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text(
            'No tienes notificaciones',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta con la franja de color a la izquierda
class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.notificacion, required this.onVer});

  final _Notificacion notificacion;
  final VoidCallback onVer;

  @override
  Widget build(BuildContext context) {
    final t =
        _tipos[notificacion.tipo] ??
        const _Tipo(Icons.notifications_none, Colors.grey);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          border: Border(left: BorderSide(color: t.color, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(t.icono, size: 16, color: t.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    notificacion.titulo,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (notificacion.tipo == 'vacaciones')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: OutlinedButton.icon(
                  onPressed: onVer,
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Ver'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _turquesa,
                    side: const BorderSide(color: _turquesa),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              )
            else
              Text(
                notificacion.texto,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// MODAL DE VACACIONES (vacaciones_hoy.vue en la web)
// =========================================================

class _VacacionesDialog extends StatefulWidget {
  const _VacacionesDialog({required this.lista});
  final List<Map<String, dynamic>> lista;

  @override
  State<_VacacionesDialog> createState() => _VacacionesDialogState();
}

class _VacacionesDialogState extends State<_VacacionesDialog> {
  String _nombre = '';
  String _oficina = '';

  List<Map<String, dynamic>> get _filtrada {
    bool contiene(dynamic valor, String filtro) => (valor ?? '')
        .toString()
        .toLowerCase()
        .trim()
        .contains(filtro.toLowerCase().trim());

    return widget.lista
        .where(
          (e) =>
              contiene(e['nombre'], _nombre) &&
              contiene(e['oficina_nombre'], _oficina),
        )
        .toList();
  }

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint,
    isDense: true,
    prefixIcon: const Icon(Icons.search, size: 18),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
  );

  @override
  Widget build(BuildContext context) {
    final lista = _filtrada;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
              child: Row(
                children: [
                  const Icon(Icons.flight_takeoff, size: 16, color: _turquesa),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'De vacaciones hoy',
                      style: TextStyle(fontSize: 14, color: AppColors.text),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: Colors.grey[500]),
                    splashRadius: 18,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade200),

            // Filtros
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  TextField(
                    decoration: _deco('Filtrar por nombre'),
                    onChanged: (v) => setState(() => _nombre = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: _deco('Filtrar por oficina'),
                    onChanged: (v) => setState(() => _oficina = v),
                  ),
                ],
              ),
            ),

            // Lista
            Flexible(
              child: lista.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Sin resultados',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: lista.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: Colors.grey.shade200),
                      itemBuilder: (_, i) {
                        final p = lista[i];
                        return ListTile(
                          dense: true,
                          title: Text(
                            '${p['nombre'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            [p['email'], p['oficina_nombre']]
                                .where(
                                  (e) => e != null && e.toString().isNotEmpty,
                                )
                                .join(' · '),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
