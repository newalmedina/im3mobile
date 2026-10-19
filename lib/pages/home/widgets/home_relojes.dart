import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:im3_mobile_app/theme/theme.dart';

/// Botón redondo fijo a la derecha que abre el modal de Horarios.
/// Equivale a la franja de horas de index.vue en la web.
class HomeRelojBoton extends StatelessWidget {
  const HomeRelojBoton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Tooltip(
        message: 'Horarios',
        child: Material(
          color: AppColors.primary,
          shape: const CircleBorder(),
          elevation: 4,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => mostrarHorarios(context),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.access_time, color: Colors.white, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

/// Abre el modal de Horarios
Future<void> mostrarHorarios(BuildContext context) {
  _prepararZonas();
  return showDialog(
    context: context,
    barrierColor: Colors.black38,
    builder: (_) => const _HorariosDialog(),
  );
}

// =========================================================
// DATOS
// =========================================================

class _Pais {
  const _Pais(this.nombre, this.zona);
  final String nombre;
  final String zona;
}

// Mismos países y zonas horarias que la web
const _paises = [
  _Pais('España', 'Europe/Madrid'),
  _Pais('Chile', 'America/Santiago'),
  _Pais('Brasil', 'America/Sao_Paulo'),
  _Pais('Perú', 'America/Lima'),
  _Pais('Colombia', 'America/Bogota'),
];

/// Las zonas horarias se cargan una sola vez
bool _zonasListas = false;
void _prepararZonas() {
  if (_zonasListas) return;
  tzdata.initializeTimeZones();
  _zonasListas = true;
}

/// "4:09:58 am", igual que el formato 'h:mm:ss a' de la web
/// "4:09 am": hora y minutos, sin segundos
String _hora(String zona) {
  final t = tz.TZDateTime.now(tz.getLocation(zona));
  final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final min = t.minute.toString().padLeft(2, '0');
  return '$h12:$min ${t.hour < 12 ? 'am' : 'pm'}';
}
// =========================================================
// MODAL
// =========================================================

class _HorariosDialog extends StatefulWidget {
  const _HorariosDialog();

  @override
  State<_HorariosDialog> createState() => _HorariosDialogState();
}

class _HorariosDialogState extends State<_HorariosDialog> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    // Refresca las horas cada segundo
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      // Pegado a la derecha, a la altura del botón y sin taparlo
      alignment: Alignment.centerRight,
      insetPadding: const EdgeInsets.only(left: 24, right: 68),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera: icono + "Horarios" + X
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Horarios',
                      style: TextStyle(fontSize: 13, color: AppColors.text),
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

            // Lista de países
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Column(
                children: [for (final p in _paises) _Fila(pais: p)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una fila: país en azul a la izquierda, hora en gris a la derecha
class _Fila extends StatelessWidget {
  const _Fila({required this.pais});

  final _Pais pais;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              pais.nombre,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          Text(
            _hora(pais.zona),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              // Números del mismo ancho: la hora no "baila"
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
