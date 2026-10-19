import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:im3_mobile_app/services/home_service.dart';
import 'package:im3_mobile_app/theme/theme.dart';

/// Pantalla de Objetivos. Equivale a pages/objetivos.vue de la web.
/// Se abre desde el bloque de la Home y tiene flecha para volver.
class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  List<Map<String, dynamic>> _objetivos = [];
  Map<String, dynamic>? _datos; // titulo, responsable, mes, ano, documento...
  bool _cargando = true;

  static const _meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final r = await Future.wait([
      HomeService.getObjetivos(),
      HomeService.getObjetivosData(),
    ]);
    if (!mounted) return;
    setState(() {
      _objetivos = r[0] as List<Map<String, dynamic>>;
      _datos = r[1] as Map<String, dynamic>?;
      _cargando = false;
    });
  }

  String _txt(String campo) {
    final s = '${_datos?[campo] ?? ''}'.trim();
    return s == 'null' ? '' : s;
  }

  /// "Fmd: Responsable marzo 2026"
  String get _firma {
    final mesNum = int.tryParse(_txt('mes'));
    final mes = (mesNum != null && mesNum >= 1 && mesNum <= 12)
        ? _meses[mesNum - 1]
        : _txt('mes');
    final partes = [
      _txt('responsable'),
      mes,
      _txt('ano'),
    ].where((e) => e.isNotEmpty).join(' ');
    return partes.isEmpty ? '' : 'Fmd: $partes';
  }

  Future<void> _abrirDocumento() async {
    final url = HomeService.urlDocumentoObjetivos(_txt('documento'));
    if (url == null) return;
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el documento.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        // Flecha de volver: Flutter la pone sola al abrir con Navigator.push
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text('Objetivos'),
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                setState(() => _cargando = true);
                await _cargar();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: _contenido(),
              ),
            ),
    );
  }

  List<Widget> _contenido() {
    if (_objetivos.isEmpty) {
      return [
        const SizedBox(height: 48),
        Center(
          child: Text(
            'Todavía no hay objetivos publicados.',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      ];
    }

    final titulo = _txt('titulo');
    final documento = _txt('documento');
    final nombreDoc = _txt('nombre_documento');

    return [
      if (titulo.isNotEmpty) ...[
        Text(
          titulo,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
      ],

      // Lista de objetivos
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            for (var i = 0; i < _objetivos.length; i++)
              _fila(_objetivos[i], ultimo: i == _objetivos.length - 1),
          ],
        ),
      ),

      if (_firma.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(
          _firma,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
      ],

      // Documento adjunto
      if (documento.isNotEmpty) ...[
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: _abrirDocumento,
            icon: const Icon(Icons.attach_file, color: AppColors.primary),
            label: Text(
              nombreDoc.isNotEmpty ? nombreDoc : 'Ver documento',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    ];
  }

  Widget _fila(Map<String, dynamic> o, {required bool ultimo}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        border: ultimo
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            // Mismo verde que .intranet_icon en la web
            child: Icon(Icons.add, color: Color(0xFF79B51C), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              HomeService.textoPlano(o['texto_objetivo']),
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
