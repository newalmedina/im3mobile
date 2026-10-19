import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// Estados de un permiso (los mismos que permisos.vue).
class EstadoPermiso {
  final String clave;
  final String nombre;
  final Color color;
  const EstadoPermiso(this.clave, this.nombre, this.color);

  static const presentado = '1';

  static const List<EstadoPermiso> todos = [
    EstadoPermiso('1', 'Presentado', Color(0xFF8C8C8C)),
    EstadoPermiso('2', 'En proceso', Color(0xFFFA8C16)),
    EstadoPermiso('3', 'Aprobado', AppColors.secondary),
    EstadoPermiso('4', 'Denegado', AppColors.danger),
    EstadoPermiso('5', 'Descartado', Color(0xFF595959)),
  ];

  /// Los que salen en el filtro (la web oculta "En proceso" y "Descartado")
  static List<EstadoPermiso> get filtro =>
      todos.where((e) => ['1', '3', '4'].contains(e.clave)).toList();

  static EstadoPermiso de(dynamic clave) =>
      todos.where((e) => e.clave == '$clave').firstOrNull ??
      EstadoPermiso('$clave', 'Desconocido', Colors.grey);
}

/// Tipos de permiso
class TipoPermiso {
  static const permiso = 'permiso';
  static const recuperable = 'permiso_recuperable';

  static String nombre(dynamic tipo) =>
      '$tipo' == recuperable ? 'Permiso recuperable' : 'Permiso';
}

/// Categorías del permiso normal (categoria_retribuido), en el orden de la web
const Map<String, String> categoriasPermiso = {
  '1': 'Lactancia',
  '2': 'Enfermedad sin baja',
  '3': 'Excedencia',
  '4': 'Permiso matrimonial',
  '5': 'Traslado de domicilio',
  '6': 'Visita médica',
  '8': 'Vacaciones becario',
  '7': 'Otros',
};
