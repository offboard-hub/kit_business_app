import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/links.dart';
import '../core/theme.dart';

/// Bouton « Aide WhatsApp » — visible dans l'en-tête et sur la page d'accueil.
class AideWhatsApp extends StatelessWidget {
  const AideWhatsApp({super.key, this.compact = false, this.pleinLargeur = false});

  final bool compact;
  final bool pleinLargeur;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return IconButton(
        tooltip: 'Aide WhatsApp',
        onPressed: () => ouvrirLienAvecRetour(context, AppConfig.lienWhatsAppAide),
        icon: const Icon(Icons.support_agent_rounded, color: K.green, size: 26),
      );
    }

    final bouton = OutlinedButton.icon(
      onPressed: () => ouvrirLienAvecRetour(context, AppConfig.lienWhatsAppAide),
      icon: const Icon(Icons.chat_rounded, color: K.green, size: 18),
      label: const Text(
        'Aide WhatsApp',
        style: TextStyle(color: K.green, fontWeight: FontWeight.w800, fontSize: 13.5),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: K.green.withValues(alpha: 0.55)),
        backgroundColor: K.green.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );

    return pleinLargeur ? SizedBox(width: double.infinity, child: bouton) : bouton;
  }
}

/// Petite pastille flottante WhatsApp (au-dessus de la bulle de chat).
class WhatsAppFlottant extends StatelessWidget {
  const WhatsAppFlottant({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'whatsapp-aide',
      backgroundColor: K.green,
      foregroundColor: K.night,
      tooltip: 'Aide WhatsApp',
      onPressed: () => ouvrirLienAvecRetour(context, AppConfig.lienWhatsAppAide),
      child: const Icon(Icons.chat_rounded, size: 22),
    );
  }
}
