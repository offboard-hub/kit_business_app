import 'video_picker_model.dart';

/// Version non web : la sélection de fichier local n'est pas disponible.
/// L'écran /admin-videos propose alors une URL vidéo externe.
Future<VideoSelection?> choisirFichierVideo() async {
  throw UnsupportedError(
    'La sélection d\'un fichier vidéo local est disponible sur la version web '
    '(/admin-videos). Utilisez sinon une URL vidéo externe.',
  );
}
