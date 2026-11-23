import 'package:flutter_web_plugins/url_strategy.dart';

/// Sur le web, on utilise de vraies URL (`/boutique`) et non `/#/boutique`.
/// Le serveur (Netlify) doit réécrire toutes les routes vers `index.html`.
void configurerUrl() => usePathUrlStrategy();
