import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Crée un Blob et déclenche le téléchargement dans le navigateur.
Future<bool> telechargerTexte({
  required String nomFichier,
  required String contenu,
  String mime = 'text/html;charset=utf-8',
}) async {
  try {
    final blob = web.Blob(
      <JSAny>[contenu.toJS].toJS,
      web.BlobPropertyBag(type: mime),
    );
    final url = web.URL.createObjectURL(blob);
    final lien = web.document.createElement('a') as web.HTMLAnchorElement;
    lien.href = url;
    lien.download = nomFichier;
    lien.style.display = 'none';
    web.document.body!.append(lien);
    lien.click();
    lien.remove();
    web.URL.revokeObjectURL(url);
    return true;
  } catch (_) {
    return false;
  }
}
