import 'dart:math';

import 'package:flutter/material.dart';

import 'package:im3_mobile_app/pages/goals/goals_page.dart';
import 'package:im3_mobile_app/services/home_service.dart';
import 'package:im3_mobile_app/theme/theme.dart';

/// Bloque "Objetivos" de la Home. Equivale a goals.vue.
/// Muestra un objetivo al azar; al pulsar abre la pantalla de objetivos.
class HomeGoals extends StatefulWidget {
  const HomeGoals({super.key});

  @override
  State<HomeGoals> createState() => _HomeGoalsState();
}

class _HomeGoalsState extends State<HomeGoals> {
  String? _objetivo;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final lista = await HomeService.getObjetivos();
    if (!mounted) return;

    // Se elige una sola vez, para que no cambie en cada repintado
    String? elegido;
    if (lista.isNotEmpty) {
      final o = lista[Random().nextInt(lista.length)];
      elegido = HomeService.textoPlano(o['texto_objetivo']);
    }

    setState(() {
      _objetivo = elegido;
      _cargando = false;
    });
  }

  void _abrirDetalle() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const GoalsPage()));
  }

  @override
  Widget build(BuildContext context) {
    // Como en la web: si no hay objetivos, el bloque no se muestra
    if (!_cargando && (_objetivo == null || _objetivo!.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _cargando ? null : _abrirDetalle,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Objetivos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey[500]),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_cargando)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.rocket_launch_outlined,
                          color: AppColors.primary,
                          size: 36,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _objetivo!,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.4,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Ver todos los objetivos',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
