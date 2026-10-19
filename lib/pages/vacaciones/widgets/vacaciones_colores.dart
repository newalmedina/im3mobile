import 'package:flutter/material.dart';

/// Colores de la leyenda, el calendario y la tabla (los de la web)
class VacColores {
  static const propuesta = Color(0xFFFF7418); // naranja
  static const aprobada = Color(0xFF069A12); // verde
  static const denegada = Color(0xFFFF1311); // rojo
  static const pagada = Color(0xFF18AEFF); // azul (compensación)
  static const baja = Color(0xFF18AEFF); // azul_3

  static const festivoLocal = Color(0xFF1890FF); // tipo 2
  static const festivoAutonomico = Color(0xFF0050B3); // tipo 3
  static const festivoNacional = Color(0xFF722ED1); // tipo 4
  static const festivoConvenio = Color(0xFFFAAD14); // tipo 5

  static Color? festivo(String tipo) => switch (tipo) {
        '2' => festivoLocal,
        '3' => festivoAutonomico,
        '4' => festivoNacional,
        '5' => festivoConvenio,
        _ => null,
      };

  static String? nombreFestivo(String tipo) => switch (tipo) {
        '2' => 'Festivo local',
        '3' => 'Festivo autonómico',
        '4' => 'Festivo nacional',
        '5' => 'Festivo de convenio',
        _ => null,
      };

  static Color? vacaciones(String tipo) => switch (tipo) {
        '1' => aprobada,
        '2' => propuesta,
        '3' => denegada,
        '4' => pagada,
        _ => null,
      };

  static String? nombreVacaciones(String tipo) => switch (tipo) {
        '1' => 'Vacaciones aprobadas',
        '2' => 'Vacaciones propuestas',
        '3' => 'Vacaciones denegadas',
        '4' => 'Compensación descanso',
        _ => null,
      };
}

/// Punto de color con texto (leyenda)
class VacPunto extends StatelessWidget {
  const VacPunto({super.key, required this.color, required this.texto});

  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            texto,
            style: TextStyle(fontSize: 13, color: Colors.grey[800]),
          ),
        ),
      ],
    );
  }
}
