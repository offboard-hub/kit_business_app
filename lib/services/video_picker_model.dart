import 'dart:typed_data';

/// Fichier vidéo choisi localement (jamais stocké sur Supabase).
class VideoSelection {
  const VideoSelection({
    required this.nom,
    required this.octets,
  });

  final String nom;
  final Uint8List octets;

  int get taille => octets.lengthInBytes;

  String get tailleLisible {
    if (taille >= 1024 * 1024) {
      return '${(taille / (1024 * 1024)).toStringAsFixed(1)} Mo';
    }
    return '${(taille / 1024).toStringAsFixed(0)} Ko';
  }
}
