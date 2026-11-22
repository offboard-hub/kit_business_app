import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'video_picker_model.dart';

/// Sélection d'un fichier vidéo local dans le navigateur.
/// Les octets restent en mémoire : ils partent directement vers YouTube/TikTok,
/// sans jamais transiter par Supabase Storage.
Future<VideoSelection?> choisirFichierVideo() {
  final completer = Completer<VideoSelection?>();

  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'video/mp4,video/quicktime,video/webm';
  input.style.display = 'none';

  final corps = web.document.body;
  if (corps == null) {
    return Future<VideoSelection?>.value(null);
  }
  corps.appendChild(input);

  void terminer(VideoSelection? valeur) {
    if (!completer.isCompleted) completer.complete(valeur);
    input.remove();
  }

  void surChangement(web.Event evenement) {
    final fichiers = input.files;
    if (fichiers == null || fichiers.length == 0) {
      terminer(null);
      return;
    }

    final fichier = fichiers.item(0);
    if (fichier == null) {
      terminer(null);
      return;
    }

    () async {
      try {
        final tampon = await fichier.arrayBuffer().toDart;
        final octets = tampon.toDart.asUint8List();
        terminer(VideoSelection(nom: fichier.name, octets: octets));
      } catch (erreur) {
        if (!completer.isCompleted) completer.completeError(erreur);
        input.remove();
      }
    }();
  }

  input.addEventListener('change', surChangement.toJS);
  input.click();

  return completer.future;
}
