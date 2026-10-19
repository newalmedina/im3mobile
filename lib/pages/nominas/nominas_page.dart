import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../layouts/main_layout.dart';
import '../../services/descarga/descarga.dart';
import '../../services/nominas_service.dart';
import '../../theme/theme.dart';
import '../../widgets/snackbar_helper.dart';

/// Mis nóminas: filtro por año y descarga en PDF.
class NominasPage extends StatefulWidget {
  const NominasPage({super.key});

  @override
  State<NominasPage> createState() => _NominasPageState();
}

class _NominasPageState extends State<NominasPage> {
  static final _fmtDia = DateFormat('dd/MM/yyyy', 'es_ES');
  static final _fmtMes = DateFormat('MMMM yyyy', 'es_ES');

  List<Map<String, dynamic>> _todas = [];
  int? _ano; // año elegido
  bool _cargando = true;
  String? _error;

  /// id de la nómina que se está descargando (para el spinner)
  String? _descargando;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  // =========================================================
  // DATOS
  // =========================================================
  Future<void> _cargar() async {
    setState(() {
      _cargando = _todas.isEmpty;
      _error = null;
    });
    try {
      final lista = await NominasService.getMisNominas();
      // Más recientes primero
      lista.sort((a, b) {
        final fa = NominasService.fecha(a['fecha_nomina']) ?? DateTime(0);
        final fb = NominasService.fecha(b['fecha_nomina']) ?? DateTime(0);
        return fb.compareTo(fa);
      });
      if (!mounted) return;
      setState(() {
        _todas = lista;
        _cargando = false;
        final anos = _anosDisponibles;
        // Como la web: el año en curso; si no tiene nóminas, el más reciente
        if (_ano == null || !anos.contains(_ano)) {
          final actual = DateTime.now().year;
          _ano = anos.contains(actual)
              ? actual
              : (anos.isNotEmpty ? anos.first : null);
        }
      });
    } on NominasException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.mensaje;
      });
    }
  }

  /// Años con nóminas, del más reciente al más antiguo
  List<int> get _anosDisponibles {
    final s = <int>{};
    for (final n in _todas) {
      final f = NominasService.fecha(n['fecha_nomina']);
      if (f != null) s.add(f.year);
    }
    return s.toList()..sort((a, b) => b.compareTo(a));
  }

  List<Map<String, dynamic>> get _filtradas => _todas
      .where((n) => NominasService.fecha(n['fecha_nomina'])?.year == _ano)
      .toList();

  // =========================================================
  // ACCIONES
  // =========================================================
  Future<void> _descargar(Map<String, dynamic> n) async {
    if (_descargando != null) return;
    setState(() => _descargando = '${n['id']}');
    try {
      final bytes = await NominasService.descargar(n);
      final nombre = await NominasService.nombreArchivo(n);
      final aviso = await guardarYAbrirPdf(bytes, nombre);
      if (!mounted) return;
      if (aviso != null) {
        SnackbarHelper.show(
          context,
          message: aviso,
          backgroundColor: AppColors.danger,
        );
      }
    } on NominasException catch (e) {
      if (!mounted) return;
      SnackbarHelper.show(
        context,
        message: e.mensaje,
        backgroundColor: AppColors.danger,
      );
    } catch (_) {
      if (!mounted) return;
      SnackbarHelper.show(
        context,
        message: 'No se ha podido guardar la nómina.',
        backgroundColor: AppColors.danger,
      );
    } finally {
      if (mounted) setState(() => _descargando = null);
    }
  }

  // =========================================================
  // UI
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return MainLayout(
      currentRoute: 'nominas',
      child: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const Text(
              'Mis nóminas',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            ..._contenido(),
          ],
        ),
      ),
    );
  }

  List<Widget> _contenido() {
    if (_cargando) {
      return const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      ];
    }

    if (_error != null) {
      return [
        _banner(Icons.cloud_off, _error!, AppColors.danger),
        TextButton(onPressed: _cargar, child: const Text('Reintentar')),
      ];
    }

    if (_todas.isEmpty) {
      return [_vacio('Todavía no tienes nóminas.')];
    }

    final lista = _filtradas;
    return [
      _filtroAnos(),
      const SizedBox(height: 16),
      if (lista.isEmpty)
        _vacio('No tienes nóminas en $_ano.')
      else
        for (final n in lista) _tarjeta(n),
    ];
  }

  /// Un chip por año, en una fila que se desliza si hay muchos
  Widget _filtroAnos() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final a in _anosDisponibles) ...[
            ChoiceChip(
              label: Text('$a'),
              selected: _ano == a,
              showCheckmark: false,
              onSelected: (_) => setState(() => _ano = a),
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: _ano == a ? AppColors.primary : Colors.grey.shade300,
              ),
              labelStyle: TextStyle(
                color: _ano == a ? Colors.white : AppColors.text,
                fontWeight: _ano == a ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _tarjeta(Map<String, dynamic> n) {
    final fecha = NominasService.fecha(n['fecha_nomina']);
    final tipo = TipoNomina.nombre(n['tipo']);
    final descripcion = '${n['description'] ?? ''}'.trim();
    final bajando = _descargando == '${n['id']}';
    final esRenta = '${n['tipo']}' == '3';
    final color = esRenta ? AppColors.secondary : AppColors.primary;
    final mes = fecha == null ? null : _capitalizar(_fmtMes.format(fecha));

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _descargando != null ? null : () => _descargar(n),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  esRenta
                      ? Icons.account_balance_outlined
                      : Icons.receipt_long_outlined,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tipo,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (mes != null)
                      Text(mes, style: TextStyle(color: Colors.grey[800])),
                    if (descripcion.isNotEmpty)
                      Text(
                        descripcion,
                        style: TextStyle(color: Colors.grey[700]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (fecha != null)
                      Text(
                        _fmtDia.format(fecha),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 48,
                height: 48,
                child: bajando
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : IconButton(
                        tooltip: 'Descargar',
                        icon: const Icon(
                          Icons.download,
                          color: AppColors.primary,
                        ),
                        onPressed: _descargando != null
                            ? null
                            : () => _descargar(n),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _capitalizar(String t) =>
      t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);

  Widget _vacio(String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      children: [
        Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[400]),
        const SizedBox(height: 12),
        Text(
          t,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    ),
  );

  Widget _banner(IconData icono, String t, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(icono, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(t)),
      ],
    ),
  );
}
