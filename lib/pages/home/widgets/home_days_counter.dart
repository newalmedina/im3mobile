import 'package:flutter/material.dart';

import '../../../../services/home_service.dart';
import '../../../../theme/theme.dart';

/// Contador de días sin accidentes. Equivale a DaysCounter de la web.
/// Se carga solo; si no hay datos no ocupa espacio.
class HomeDaysCounter extends StatefulWidget {
  const HomeDaysCounter({super.key});

  @override
  State<HomeDaysCounter> createState() => _HomeDaysCounterState();
}

class _HomeDaysCounterState extends State<HomeDaysCounter> {
  int? _dias;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final d = await HomeService.getDiasSinAccidentes();
    if (!mounted) return;
    setState(() {
      _dias = d;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const _Hueco();

    final dias = _dias;
    if (dias == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icono en círculo
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.health_and_safety_outlined,
                color: AppColors.primary,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            // Número + texto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$dias',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      height: 1,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dias == 1 ? 'día sin accidentes' : 'días sin accidentes',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Recuadro gris mientras carga
class _Hueco extends StatelessWidget {
  const _Hueco();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        height: 92,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
