import 'package:web/web.dart' as web;

/// Retire de l'URL les paramètres OAuth (code, state, error…) après traitement.
/// Évite qu'un rafraîchissement ne rejoue un code TikTok déjà consommé.
void nettoyerParametresUrl(List<String> cles) {
  final uri = Uri.tryParse(web.window.location.href);
  if (uri == null || uri.queryParameters.isEmpty) return;

  final restants = Map<String, String>.from(uri.queryParameters);
  for (final cle in cles) {
    restants.remove(cle);
  }

  final nouvelle = uri.replace(queryParameters: restants.isEmpty ? null : restants).toString();
  web.window.history.replaceState(null, '', nouvelle);
}
