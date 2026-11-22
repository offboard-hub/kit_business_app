import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ouvre un lien externe (nouvel onglet sur le web).
Future<bool> ouvrirLien(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Ouvre un lien et prévient l'utilisateur en cas d'échec.
Future<void> ouvrirLienAvecRetour(BuildContext context, String url) async {
  final ouvert = await ouvrirLien(url);
  if (!ouvert && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Impossible d\'ouvrir ce lien. Copiez-le dans votre navigateur.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
