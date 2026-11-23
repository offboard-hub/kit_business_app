import 'package:flutter/material.dart';

import '../core/links.dart';
import '../core/theme.dart';

/// Contrôleur de la salle Jitsi (sans effet hors web).
class JitsiController {
  const JitsiController();

  Future<void> basculerMicro() async {}
  Future<void> basculerCamera() async {}
  Future<void> partagerEcran() async {}
  Future<void> quitter() async {}
}

/// Hors web, on propose d'ouvrir la salle dans le navigateur.
Widget construireJitsi({
  Key? key,
  required String roomId,
  required String nomAffiche,
  required JitsiController controleur,
  bool moderateur = false,
}) {
  return Container(
    key: key,
    decoration: BoxDecoration(
      color: K.bg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: K.border),
    ),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.videocam_off_rounded, color: K.faint, size: 34),
            const SizedBox(height: 10),
            const Text(
              'La salle vidéo est disponible sur le web.',
              textAlign: TextAlign.center,
              style: TextStyle(color: K.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ouvrirLien('https://meet.jit.si/ebooklive-$roomId'),
              child: const Text('Ouvrir la salle', style: TextStyle(color: K.or)),
            ),
          ],
        ),
      ),
    ),
  );
}
