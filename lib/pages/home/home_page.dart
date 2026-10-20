import 'package:flutter/material.dart';
import 'package:im3_mobile_app/pages/home/widgets/home_banner.dart';
import 'package:im3_mobile_app/pages/home/widgets/home_days_counter.dart';
import 'package:im3_mobile_app/pages/home/widgets/home_documents.dart';
import 'package:im3_mobile_app/pages/home/widgets/home_goals.dart';
import 'package:im3_mobile_app/pages/home/widgets/home_incorporaciones.dart';
import 'package:im3_mobile_app/pages/home/widgets/home_latest_news.dart';
import 'package:im3_mobile_app/pages/home/widgets/home_notices.dart';
import 'package:im3_mobile_app/pages/home/widgets/home_notificaciones.dart';
import 'package:im3_mobile_app/pages/home/widgets/home_pinned.dart';
import 'package:im3_mobile_app/pages/home/widgets/home_relojes.dart';

import '../../layouts/main_layout.dart';
import '../../theme/theme.dart';

/// Pantalla de inicio. Equivalente a pages/index.vue de la web.
///
/// Cada bloque es un widget independiente en `widgets/` que carga
/// sus propios datos. Esta página solo los ordena y los recarga.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// Al cambiar este número, todos los bloques se vuelven a crear
  /// y cargan de nuevo sus datos (tirar hacia abajo para refrescar).
  int _recarga = 0;

  Future<void> _refrescar() async {
    setState(() => _recarga++);
    // Pequeña espera para que se vea el indicador de recarga
    await Future.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      currentRoute: 'home',
      child: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _refrescar,
            child: ListView(
              // Para poder refrescar aunque el contenido sea corto
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // 1. Banner del concurso
                HomeBanner(key: ValueKey('banner$_recarga')),
                // 2. Destacado          -> Pinned
                HomePinned(key: ValueKey('pinned$_recarga')),

                // 4. Objetivos          -> Goals
                HomeGoals(key: ValueKey('goals$_recarga')),
                // 5. Días sin accidentes -> DaysCounter
                HomeDaysCounter(key: ValueKey('days$_recarga')),
                // 6. Nuevas incorporaciones -> Incorporaciones
                HomeIncorporaciones(key: ValueKey('incorporaciones$_recarga')),
                // 7. Documentación      -> Documents
                HomeDocuments(key: ValueKey('documents$_recarga')),
                // 3. Comunicados        -> Notices
                HomeNotices(key: ValueKey('notices$_recarga')),
                // 8. Noticias           -> LatestNews
                HomeLatestNews(key: ValueKey('news$_recarga')),
              ],
            ),
          ),

          // Reloj de los países: pestaña fija a la derecha, a media altura
          // Notificaciones + reloj de los países, fijos a la derecha
          Align(
            alignment: Alignment.centerRight, // deja la alineación que tengas
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HomeNotificacionesBoton(key: ValueKey('notif$_recarga')),
                const SizedBox(height: 10),
                const HomeRelojBoton(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
