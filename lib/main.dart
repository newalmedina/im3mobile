import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'pages/login/login_page.dart';
import 'theme/theme.dart';
import 'package:im3_mobile_app/services/accesos_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Nombres de meses y días en español (calendario y DateFormat)
  await initializeDateFormatting('es_ES');

  WidgetsFlutterBinding.ensureInitialized();
  AccesosService.iniciarObservador();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IM3',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Selector de hora y de fecha en español
      locale: const Locale('es', 'ES'),
      supportedLocales: const [Locale('es', 'ES')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const LoginPage(),
    );
  }
}
