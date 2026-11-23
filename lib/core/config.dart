import 'package:flutter/material.dart';

/// ============================================================================
///  Configuration centrale — positionnement Afrique francophone, 100 % FCFA.
///  Un seul endroit à modifier pour les tarifs, les kits et les pays.
/// ============================================================================
class AppConfig {
  const AppConfig._();

  // --- Supabase (clé publishable : publique par nature) ----------------------
  static const String supabaseUrl = 'https://ynephuutnazdnjhsdlsy.supabase.co';
  static const String supabaseKey = 'sb_publishable_abG7DSxcPMPolOnLKPNcJw_Rod7G7S8';

  // --- Identité et contacts --------------------------------------------------
  static const String siteUrl = String.fromEnvironment(
    'SITE_URL',
    defaultValue: 'https://e-booklive.offboard-hub.com',
  );

  /// Numéro d'aide WhatsApp au format international, sans « + ».
  /// Utilisé pour le bouton « Aide WhatsApp » et le lien wa.me.
  /// ⚠️ Remplacez la valeur par défaut par votre vrai numéro.
  static const String whatsappAide = String.fromEnvironment(
    'WHATSAPP_AIDE_NUMBER',
    defaultValue: '22670123456',
  );

  static const String emailSupport = 'contact@e-booklive.offboard-hub.com';

  static String get lienWhatsAppAide {
    final message = Uri.encodeComponent(
      'Bonjour e-booklive 👋 Je souhaite des informations sur les kits métiers et le Studio Live.',
    );
    return 'https://wa.me/$whatsappAide?text=$message';
  }

  static String get lienCommande => '$siteUrl/boutique';

  static String get lienStudio => '$siteUrl/studio-live';

  static String get lienGuide => '$siteUrl/guide';

  /// Abonnement Studio Live : 10 USD pour 30 jours (source de vérité).
  static const int studioPrixUsd = 10;

  /// URL publique d'une Edge Function.
  static String fonction(String nom) => '$supabaseUrl/functions/v1/$nom';

  /// Formate un montant : 9000 -> « 9 000 FCFA ».
  static String fcfa(int montant) {
    final chiffres = montant.abs().toString();
    final tampon = StringBuffer();
    for (var i = 0; i < chiffres.length; i++) {
      if (i > 0 && (chiffres.length - i) % 3 == 0) tampon.write(' ');
      tampon.write(chiffres[i]);
    }
    return '$tampon FCFA';
  }

  /// Construit un lien de consultation protégé par jeton.
  static String lienKit({required String kitId, required String jeton, required String type}) {
    return '${fonction('view-kit')}?id=$kitId&token=$jeton&type=$type';
  }
}

/// ============================================================================
///  OFFRES (tarifs officiels en FCFA — plus aucun prix en dirham)
/// ============================================================================
enum TypeOffre { prompts, sheet, livre, pack }

class Offre {
  const Offre({
    required this.type,
    required this.apiType,
    required this.productId,
    required this.titre,
    required this.description,
    required this.prix,
    required this.credits,
    required this.icone,
    this.populaire = false,
  });

  final TypeOffre type;
  final String apiType;
  final String productId;
  final String titre;
  final String description;
  final int prix;
  final int credits;
  final IconData icone;
  final bool populaire;

  String get prixAffiche => AppConfig.fcfa(prix);
}

const List<Offre> offres = [
  Offre(
    type: TypeOffre.prompts,
    apiType: 'prompt',
    productId: '8cbddad5-7747-424e-8ed1-a1829ae46914',
    titre: 'Prompts IA',
    description: '10 prompts prêts à copier pour vendre, publier et gérer votre activité.',
    prix: 3000,
    credits: 1,
    icone: Icons.auto_awesome_rounded,
  ),
  Offre(
    type: TypeOffre.sheet,
    apiType: 'sheet',
    productId: 'd4b7a69e-1720-4038-8da8-cf782fed24e9',
    titre: 'Sheet Automatisé',
    description: 'Votre Google Sheet : ventes, stocks, marges et point mort calculés.',
    prix: 3500,
    credits: 1,
    icone: Icons.table_chart_rounded,
  ),
  Offre(
    type: TypeOffre.livre,
    apiType: 'livre',
    productId: 'f8a7dd07-d155-4b83-8289-286f2e44ee6b',
    titre: 'Livre Stratégique',
    description: 'Votre plan d\'action complet, écrit pour votre métier et votre pays.',
    prix: 5000,
    credits: 1,
    icone: Icons.menu_book_rounded,
  ),
  Offre(
    type: TypeOffre.pack,
    apiType: 'pack',
    productId: '54e2150a-1648-4119-a4df-208bcb121c27',
    titre: 'Pack Complet',
    description: 'Le livre, les prompts IA et le Google Sheet : tout votre kit en une fois.',
    prix: 9000,
    credits: 3,
    icone: Icons.workspace_premium_rounded,
    populaire: true,
  ),
];

Offre offreParApiType(String apiType) {
  return offres.firstWhere(
    (offre) => offre.apiType == apiType,
    orElse: () => offres.last,
  );
}

