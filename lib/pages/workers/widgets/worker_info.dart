import 'package:flutter/material.dart';

import 'package:im3_mobile_app/services/home_service.dart';
import 'package:im3_mobile_app/theme/theme.dart';

import 'worker_ui.dart';

/// Información general del trabajador (info.vue en la web, solo lectura):
/// empresa, divisiones, oficina, contacto y horario semanal.
/// El horario lo carga él solo; si falla, solo ese trozo muestra el error.
class WorkerInfo extends StatefulWidget {
  const WorkerInfo({super.key, required this.id, required this.info});

  final String id;
  final Map<String, dynamic> info;

  @override
  State<WorkerInfo> createState() => _WorkerInfoState();
}

class _WorkerInfoState extends State<WorkerInfo> {
  Map<String, dynamic>? _horario;
  bool _cargandoHorario = true;

  @override
  void initState() {
    super.initState();
    _cargarHorario();
  }

  Future<void> _cargarHorario() async {
    final h = await HomeService.getHorarioSemana(widget.id);
    if (!mounted) return;
    setState(() {
      _horario = h;
      _cargandoHorario = false;
    });
  }

  void _reintentar() {
    setState(() => _cargandoHorario = true);
    _cargarHorario();
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final t = WorkerUtils.texto;
    final sub = WorkerUtils.sub;

    final empresa = t(sub(info['empresa'], 'nombre'));
    final oficina = t(sub(info['oficina'], 'nombre'));
    final canal = t(info['canal']);
    final responsable = t(info['nombre_responsable']);
    final divisiones = (info['divisiones'] is List)
        ? (info['divisiones'] as List).whereType<Map>().toList()
        : <Map>[];

    final email = t(info['email']);
    final email2 = t(info['email2']);
    final linkedin = t(info['linkedin']);
    final twitter = t(info['twitter']);
    final telefono = t(info['telefono']);
    final telefono2 = t(info['telefono2']);
    final extension = t(info['extension']);
    final esEspana = t(sub(info['pais'], 'id')) == '1';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WorkerTitulo('Información general'),
        if (empresa.isNotEmpty) WorkerSubtitulo(empresa, arriba: false),
        for (final d in divisiones)
          _Linea(etiqueta: t(d['nombre']), valor: t(d['descripcion'])),
        if (oficina.isNotEmpty) _Linea(etiqueta: 'Oficina', valor: oficina),
        if (canal.isNotEmpty) _Linea(etiqueta: 'Canal', valor: canal),
        if (responsable.isNotEmpty)
          _Linea(etiqueta: 'Responsable', valor: responsable),

        // Emails
        if (email.isNotEmpty || email2.isNotEmpty) ...[
          const WorkerSubtitulo('Emails'),
          if (email.isNotEmpty)
            _Enlace(
              icono: Icons.mail_outline,
              texto: email,
              enlace: 'mailto:$email',
            ),
          if (email2.isNotEmpty)
            _Enlace(
              icono: Icons.mail_outline,
              texto: email2,
              enlace: 'mailto:$email2',
            ),
        ],

        // Redes sociales
        if (linkedin.isNotEmpty || twitter.isNotEmpty) ...[
          const WorkerSubtitulo('Redes sociales'),
          if (linkedin.isNotEmpty)
            _Enlace(
              icono: Icons.work_outline,
              texto: 'LinkedIn',
              enlace: linkedin,
            ),
          if (twitter.isNotEmpty)
            _Enlace(
              icono: Icons.alternate_email,
              texto: 'Twitter',
              enlace: twitter,
            ),
        ],

        // Teléfonos
        const WorkerSubtitulo('Teléfono'),
        if (telefono.isNotEmpty)
          _Enlace(
            icono: Icons.phone_outlined,
            texto: telefono,
            enlace: 'tel:$telefono',
          ),
        if (esEspana && extension.isNotEmpty)
          _Enlace(
            icono: Icons.phone_forwarded_outlined,
            texto: 'Ext: $extension',
            enlace: 'tel:$extension',
          ),
        if (telefono2.isNotEmpty)
          _Enlace(
            icono: Icons.phone_outlined,
            texto: telefono2,
            enlace: 'tel:$telefono2',
          ),
        if (telefono.isEmpty && telefono2.isEmpty)
          Text('Sin teléfono', style: TextStyle(color: Colors.grey[700])),

        // Horario
        const WorkerSubtitulo('Horario semanal'),
        if (_cargandoHorario)
          const WorkerCargando()
        else
          _Horario(horario: _horario, onReintentar: _reintentar),
      ],
    );
  }
}

/// "Etiqueta: valor"
class _Linea extends StatelessWidget {
  const _Linea({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 14, color: AppColors.text),
          children: [
            if (etiqueta.isNotEmpty)
              TextSpan(
                text: '$etiqueta: ',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            TextSpan(text: valor),
          ],
        ),
      ),
    );
  }
}

/// Email, teléfono o red social pulsable
class _Enlace extends StatelessWidget {
  const _Enlace({
    required this.icono,
    required this.texto,
    required this.enlace,
  });

  final IconData icono;
  final String texto;
  final String enlace;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => WorkerUtils.abrir(enlace),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icono, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                texto,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lunes a viernes con su tramo y el check de teletrabajo (como la web)
class _Horario extends StatelessWidget {
  const _Horario({required this.horario, required this.onReintentar});

  final Map<String, dynamic>? horario;
  final VoidCallback onReintentar;

  static const Map<String, String> _dias = {
    'lunes': 'Lunes',
    'martes': 'Martes',
    'miercoles': 'Miércoles',
    'jueves': 'Jueves',
    'viernes': 'Viernes',
  };

  static const _azul = Color(0xFF007BFF);

  /// "08:00:00" -> "08:00"
  static String _hora(dynamic v) {
    final t = WorkerUtils.texto(v);
    return RegExp(r'^\d{1,2}:\d{2}:\d{2}$').hasMatch(t)
        ? t.substring(0, t.length - 3)
        : t;
  }

  static String _tramo(Map<String, dynamic> h, String dia) {
    final inicio = _hora(h['hora_inicio_$dia']);
    final fin = _hora(h['hora_final_$dia']);
    if (inicio.isNotEmpty && fin.isNotEmpty) return '$inicio a $fin';
    if (inicio.isNotEmpty) return inicio;
    if (fin.isNotEmpty) return 'a $fin';
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final h = horario;

    // No ha llegado (timeout o error)
    if (h == null) {
      return WorkerFallo(
        texto: 'No se ha podido cargar el horario',
        onReintentar: onReintentar,
      );
    }

    final hay = _dias.keys.any((d) =>
        _hora(h['hora_inicio_$d']).isNotEmpty ||
        _hora(h['hora_final_$d']).isNotEmpty);

    if (!hay) {
      return Text(
        'Sin horario semanal',
        style: TextStyle(color: Colors.grey[700]),
      );
    }

    return Column(
      children: [
        for (final dia in _dias.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    dia.value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                ),
                Expanded(child: Text(_tramo(h, dia.key))),
                // Check de solo lectura, marcado o no
                Icon(
                  WorkerUtils.si(h['${dia.key}_teletrabajo'])
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 20,
                  color: WorkerUtils.si(h['${dia.key}_teletrabajo'])
                      ? _azul
                      : Colors.grey.shade400,
                ),
                const SizedBox(width: 4),
                const Text(
                  '(teletrabajo)',
                  style: TextStyle(fontSize: 12, color: _azul),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
