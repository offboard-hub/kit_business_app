import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_state.dart';
import 'core/config.dart';
import 'core/theme.dart';
import 'core/url_strategy.dart';
import 'pages/admin_guard_page.dart';
import 'pages/assistant_page.dart';
import 'pages/boutique_page.dart';
import 'pages/confirmation_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/guide_page.dart';
import 'pages/home_page.dart';
import 'pages/legal_pages.dart';
import 'pages/live_room_page.dart';
import 'pages/splash_page.dart';
import 'pages/studio_live_page.dart';
import 'pages/studio_regie_page.dart';
import 'pages/tiktok_callback_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // URL propres sur le web : /boutique, /studio-live, /live/<room>…
  configurerUrl();

  runApp(const EbookliveApp());
}

/// Racine de l'application : initialise Supabase, charge le pays mémorisé,
/// puis laisse la place à l'interface. Le splash reste visible au-dessus de
/// la navigation tant que l'initialisation n'est pas terminée.
class EbookliveApp extends StatefulWidget {
  const EbookliveApp({super.key});

  @override
  State<EbookliveApp> createState() => _EbookliveAppState();
}

class _EbookliveAppState extends State<EbookliveApp> {
  static const Duration _dureeMinimale = Duration(milliseconds: 1400);

  double _progression = 0.06;
  String _message = 'Initialisation de la plateforme…';
  Object? _erreur;
  bool _pret = false;
  bool _commandeConsommee = false;
  bool _retourTiktokConsomme = false;

  @override
  void initState() {
    super.initState();
    _demarrer();
  }

  Future<void> _demarrer() async {
    setState(() {
      _erreur = null;
      _progression = 0.10;
      _message = 'Connexion sécurisée à vos services…';
    });

    final debut = DateTime.now();

    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseKey,
      );

      if (!mounted) return;
      setState(() {
        _progression = 0.52;
        _message = 'Chargement de vos préférences et de votre devise…';
      });

      await CountryStore.initialiser();

      if (!mounted) return;
      setState(() {
        _progression = 0.78;
        _message = 'Ouverture de La Boutique et du Studio Live…';
      });

      final ecoule = DateTime.now().difference(debut);
      if (ecoule < _dureeMinimale) {
        await Future<void>.delayed(_dureeMinimale - ecoule);
      }

      if (!mounted) return;
      setState(() {
        _progression = 1;
        _message = 'Bienvenue sur e-booklive.';
      });

      await Future<void>.delayed(const Duration(milliseconds: 460));
      if (!mounted) return;
      setState(() => _pret = true);
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _erreur = erreur);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'e-booklive — La Boutique & Studio Live',
      debugShowCheckedModeBanner: false,
      theme: _theme(),
      initialRoute: _routeInitiale(),
      onGenerateRoute: _genererRoute,
      // Une seule route initiale : évite les piles fantômes sur /live/x,
      // /studio/regie ou /assistant (le navigateur ne doit pas empiler /).
      onGenerateInitialRoutes: (initialRoute) => <Route<dynamic>>[
        _genererRoute(RouteSettings(name: initialRoute)),
      ],
      navigatorObservers: <NavigatorObserver>[_ObservateurUrl()],
      scrollBehavior: const _ComportementDefilement(),
      builder: (context, child) {
        final application = child ?? const SizedBox.shrink();
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            application,
            if (!_pret)
              SplashPage(
                progression: _progression,
                message: _message,
                erreur: _erreur,
                onReessayer: _demarrer,
                onContinuer: _erreur == null
                    ? null
                    : () => setState(() => _pret = true),
              ),
          ],
        );
      },
    );
  }

  ThemeData _theme() {
    const colorScheme = ColorScheme.dark(
      primary: K.or,
      onPrimary: K.bg,
      secondary: K.emeraude,
      onSecondary: K.bg,
      surface: K.surface,
      onSurface: K.text,
      error: K.danger,
      onError: K.bg,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: K.bg,
      canvasColor: K.bg,
      primaryColor: K.or,
      colorScheme: colorScheme,
      splashFactory: InkSparkle.splashFactory,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: K.text,
          fontSize: 46,
          height: 1.06,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.6,
        ),
        headlineMedium: TextStyle(
          color: K.text,
          fontSize: 28,
          height: 1.15,
          fontWeight: FontWeight.w900,
          letterSpacing: -1,
        ),
        titleMedium: TextStyle(
          color: K.text,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(color: K.muted, fontSize: 14, height: 1.6),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: K.surfaceAlt,
        contentTextStyle: const TextStyle(color: K.text, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: K.or,
        linearTrackColor: K.surfaceAlt,
      ),
      dividerTheme: const DividerThemeData(color: K.border, thickness: 1, space: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: K.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: K.border),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: K.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: K.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: K.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: K.border),
        ),
        textStyle: const TextStyle(color: K.text, fontSize: 11.5),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: K.or,
        unselectedLabelColor: K.muted,
        indicatorColor: K.or,
        dividerColor: K.border,
        labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: K.bg.withValues(alpha: 0.45),
        hintStyle: const TextStyle(color: K.faint, fontSize: 13),
        labelStyle: const TextStyle(color: K.muted, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: K.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: K.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: K.or, width: 1.5),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  String _routeInitiale() {
    final uri = Uri.base;
    var chemin = uri.path;
    final fragment = uri.fragment;
    if (fragment.isNotEmpty && fragment.startsWith('/')) {
      chemin = fragment;
    }
    if (chemin.isEmpty) return '/';
    return chemin.length > 1 && chemin.endsWith('/')
        ? chemin.substring(0, chemin.length - 1)
        : chemin;
  }

  Route<dynamic> _genererRoute(RouteSettings settings) {
    final nom = settings.name ?? '/';
    final arguments = settings.arguments;
    final uri = Uri.base;
    Widget page;

    // Retour OAuth TikTok : /?code=…&state=…
    final codeTiktok = uri.queryParameters['code'];
    final stateTiktok = uri.queryParameters['state'];
    final erreurTiktok =
        uri.queryParameters['error_description'] ?? uri.queryParameters['error'];
    final retourTiktok = (codeTiktok != null && codeTiktok.isNotEmpty) ||
        (erreurTiktok != null && stateTiktok != null);

    final commandeId = uri.queryParameters['commande'];

    if (nom == '/' && retourTiktok && !_retourTiktokConsomme) {
      _retourTiktokConsomme = true;
      page = TiktokCallbackPage(
        code: codeTiktok ?? '',
        state: stateTiktok,
        erreurTiktok:
            codeTiktok == null || codeTiktok.isEmpty ? erreurTiktok : null,
      );
    } else if (nom == '/' &&
        commandeId != null &&
        commandeId.isNotEmpty &&
        !_commandeConsommee) {
      _commandeConsommee = true;
      page = ConfirmationPage(orderId: commandeId);
    } else {
      switch (nom) {
        case '/boutique':
        case '/commande':
          String? metier;
          String? offre;
          if (arguments is Map) {
            metier = arguments['metier'] as String?;
            offre = arguments['offre'] as String?;
          }
          page = BoutiquePage(
            metierInitial: metier,
            offreInitiale: offre,
          );
          break;

        case '/studio-live':
          page = const StudioLivePage();
          break;

        case '/studio/regie':
          page = const StudioRegiePage();
          break;

        case '/guide':
          page = const GuidePage();
          break;

        case '/assistant':
          page = const AssistantPage();
          break;

        case '/mon-espace':
          page = const AuthGate();
          break;

        case '/admin-videos':
          page = const AdminGuardPage();
          break;

        case '/cgv':
        case '/terms':
          page = const CGVPage();
          break;

        case '/confidentialite':
        case '/privacy':
          page = const ConfidentialitePage();
          break;

        case '/remboursement':
        case '/refund':
          page = const RemboursementPage();
          break;

        case '/contact':
          page = const ContactPage();
          break;

        case '/mentions-legales':
        case '/legal':
          page = const MentionsLegalesPage();
          break;

        case '/faq':
          page = const FAQPage();
          break;

        default:
          final live = RegExp(r'^/live/([^/]+)$').firstMatch(nom);
          if (live != null) {
            page = LiveRoomPage(
              roomId: live.group(1)!,
              inviteToken: uri.queryParameters['invite'],
            );
          } else {
            page = const HomePage();
          }
      }
    }

    return PageRouteBuilder<dynamic>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final courbe = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: courbe,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.015),
              end: Offset.zero,
            ).animate(courbe),
            child: child,
          ),
        );
      },
    );
  }
}

/// Synchronise l'URL du navigateur avec la route Flutter (path strategy).
/// Les dialogues et menus ne modifient pas l'URL.
class _ObservateurUrl extends NavigatorObserver {
  void _mettreAJour(Route<dynamic>? route) {
    if (route is! PageRoute<dynamic>) return;
    final nom = route.settings.name;
    if (nom == null || nom.isEmpty) return;

    // Conserver les jetons présents dans l'URL initiale : un rafraîchissement
    // de /live/x?invite=… ou /studio-live?abonnement=… doit fonctionner.
    final actuel = Uri.base.queryParameters;
    final parametres = <String, String>{};
    if (nom.startsWith('/live/') && actuel['invite'] != null) {
      parametres['invite'] = actuel['invite']!;
    } else if (nom == '/studio-live' && actuel['abonnement'] != null) {
      parametres['abonnement'] = actuel['abonnement']!;
    }

    final uri = Uri(
      path: nom == '/' ? '/' : nom,
      queryParameters: parametres.isEmpty ? null : parametres,
    );
    SystemNavigator.routeInformationUpdated(uri: uri, replace: true);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _mettreAJour(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _mettreAJour(previousRoute);
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _mettreAJour(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

/// Autorise le glisser-déposer à la souris (utile sur le web) et supprime
/// l'effet « glow » des listes pour un rendu plus sobre.
class _ComportementDefilement extends MaterialScrollBehavior {
  const _ComportementDefilement();

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
