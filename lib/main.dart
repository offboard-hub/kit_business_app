import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'pages/admin_videos_page.dart';
import 'pages/commande_page.dart';
import 'pages/confirmation_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/landing_page.dart';
import 'pages/legal_pages.dart';
import 'pages/tiktok_callback_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseKey,
  );

  runApp(const KitBusinessApp());
}

class KitBusinessApp extends StatelessWidget {
  const KitBusinessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kit Business — Kits métiers clés en main en FCFA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: K.night,
        primaryColor: K.gold,
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: K.gold,
          secondary: K.goldSoft,
          surface: K.night,
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          contentTextStyle: TextStyle(color: K.sand),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(color: K.gold),
      ),
      initialRoute: '/',
      onGenerateRoute: _genererRoute,
    );
  }

  Route<dynamic> _genererRoute(RouteSettings settings) {
    final nom = settings.name ?? '/';
    final arguments = settings.arguments;

    Widget page;

    switch (nom) {
      case '/commande':
        String? metier;
        String? offre;
        if (arguments is Map) {
          metier = arguments['metier'] as String?;
          offre = arguments['offre'] as String?;
        }
        page = CommandePage(metierInitial: metier, offreInitiale: offre);
        break;

      case '/mon-espace':
        page = const AuthGate();
        break;

      case '/admin-videos':
        page = const AdminVideosPage();
        break;

      case '/cgv':
        page = const CGVPage();
        break;

      case '/mentions-legales':
        page = const MentionsLegalesPage();
        break;

      case '/faq':
        page = const FAQPage();
        break;

      case '/':
        final parametres = Uri.base.queryParameters;
        final codeTiktok = parametres['code'];
        final stateTiktok = parametres['state'];
        final erreurTiktok = parametres['error_description'] ?? parametres['error'];
        final commandeId = parametres['commande'];

        // Retour OAuth TikTok : SITE_URL/?code=...&state=...
        final retourTiktok =
            (codeTiktok != null && codeTiktok.isNotEmpty) ||
            (erreurTiktok != null && stateTiktok != null);

        if (retourTiktok) {
          page = TiktokCallbackPage(
            code: codeTiktok ?? '',
            state: stateTiktok,
            erreurTiktok: codeTiktok == null || codeTiktok.isEmpty ? erreurTiktok : null,
          );
        } else if (commandeId != null && commandeId.isNotEmpty) {
          page = ConfirmationPage(orderId: commandeId);
        } else {
          page = const LandingPage();
        }
        break;

      default:
        page = const LandingPage();
    }

    return PageRouteBuilder<dynamic>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }
}
