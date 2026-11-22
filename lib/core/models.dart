// ============================================================================
//  Modèles de données partagés entre l'application et les Edge Functions.
// ============================================================================

class CheckoutCree {
  const CheckoutCree({
    required this.orderId,
    required this.sessionId,
    required this.checkoutUrl,
    required this.montant,
    required this.devise,
    required this.offre,
    required this.metier,
    required this.pays,
  });

  final String orderId;
  final String sessionId;
  final String checkoutUrl;
  final int montant;
  final String devise;
  final String offre;
  final String metier;
  final String pays;

  factory CheckoutCree.fromJson(Map<String, dynamic> json) {
    return CheckoutCree(
      orderId: '${json['order_id'] ?? ''}',
      sessionId: '${json['session_id'] ?? ''}',
      checkoutUrl: '${json['checkout_url'] ?? ''}',
      montant: (json['montant_fcfa'] as num?)?.toInt() ?? 0,
      devise: '${json['devise'] ?? 'XOF'}',
      offre: '${json['offre'] ?? ''}',
      metier: '${json['metier'] ?? ''}',
      pays: '${json['pays'] ?? ''}',
    );
  }
}

class LiensKit {
  const LiensKit({this.livre, this.prompts, this.sheet, this.principal});

  final String? livre;
  final String? prompts;
  final String? sheet;
  final String? principal;

  bool get aDesLiens =>
      (livre != null && livre!.isNotEmpty) ||
      (prompts != null && prompts!.isNotEmpty) ||
      (sheet != null && sheet!.isNotEmpty);

  factory LiensKit.fromJson(dynamic brut) {
    final json = brut is Map ? Map<String, dynamic>.from(brut) : <String, dynamic>{};
    String? lire(String cle) {
      final valeur = json[cle];
      if (valeur == null) return null;
      final texte = '$valeur';
      return texte.isEmpty || texte == 'null' ? null : texte;
    }

    return LiensKit(
      livre: lire('livre'),
      prompts: lire('prompts'),
      sheet: lire('sheet'),
      principal: lire('principal'),
    );
  }
}

class EtatLivraison {
  const EtatLivraison({required this.email, this.erreur});

  final bool email;
  final String? erreur;

  factory EtatLivraison.fromJson(dynamic brut) {
    final json = brut is Map ? Map<String, dynamic>.from(brut) : <String, dynamic>{};
    final email = json['email'];

    bool envoye(dynamic valeur) {
      if (valeur is Map) return valeur['envoye'] == true;
      return valeur == true;
    }

    String? message(dynamic valeur) {
      if (valeur is Map && valeur['error'] != null) return '${valeur['error']}';
      return null;
    }

    return EtatLivraison(
      email: envoye(email),
      erreur: message(email),
    );
  }
}

class ResultatCommande {
  const ResultatCommande({
    required this.orderId,
    required this.paid,
    required this.statut,
    required this.liens,
    required this.livraison,
    this.message,
    this.avertissements = const [],
    this.nomProjet,
    this.metier,
    this.produitType,
    this.montant,
    this.whatsapp,
  });

  final String orderId;
  final bool paid;
  final String statut;
  final LiensKit liens;
  final EtatLivraison livraison;
  final String? message;
  final List<String> avertissements;
  final String? nomProjet;
  final String? metier;
  final String? produitType;
  final int? montant;
  final String? whatsapp;

  factory ResultatCommande.fromJson(Map<String, dynamic> json) {
    final commande = json['commande'] is Map
        ? Map<String, dynamic>.from(json['commande'] as Map)
        : <String, dynamic>{};

    final avertissements = <String>[];
    final brutAvertissements = json['avertissements'];
    if (brutAvertissements is List) {
      for (final element in brutAvertissements) {
        avertissements.add('$element');
      }
    }

    return ResultatCommande(
      orderId: '${json['order_id'] ?? commande['id'] ?? ''}',
      paid: json['paid'] == true,
      statut: '${json['statut'] ?? commande['statut'] ?? ''}',
      liens: LiensKit.fromJson(json['liens']),
      livraison: EtatLivraison.fromJson(json['livraison']),
      message: json['message'] == null ? null : '${json['message']}',
      avertissements: avertissements,
      nomProjet: commande['nom_projet'] == null ? null : '${commande['nom_projet']}',
      metier: commande['metier_label'] == null ? null : '${commande['metier_label']}',
      produitType: commande['produit_type'] == null ? null : '${commande['produit_type']}',
      montant: (commande['montant_fcfa'] as num?)?.toInt(),
      whatsapp: commande['whatsapp'] == null ? null : '${commande['whatsapp']}',
    );
  }

  factory ResultatCommande.vide(String orderId) => ResultatCommande(
        orderId: orderId,
        paid: false,
        statut: 'EN_ATTENTE',
        liens: const LiensKit(),
        livraison: const EtatLivraison(email: false),
      );
}

// ============================================================================
//  Commande (historique du dashboard)
// ============================================================================
class CommandeResume {
  const CommandeResume({
    required this.id,
    required this.nomProjet,
    required this.metier,
    required this.produitType,
    required this.montant,
    required this.statut,
    required this.createdAt,
    this.kitId,
  });

  final String id;
  final String nomProjet;
  final String metier;
  final String produitType;
  final int montant;
  final String statut;
  final DateTime createdAt;
  final String? kitId;

  factory CommandeResume.fromJson(Map<String, dynamic> json) {
    return CommandeResume(
      id: '${json['id']}',
      nomProjet: '${json['nom_projet'] ?? ''}',
      metier: '${json['metier_label'] ?? json['metier_code'] ?? ''}',
      produitType: '${json['produit_type'] ?? ''}',
      montant: (json['montant_fcfa'] as num?)?.toInt() ?? 0,
      statut: '${json['statut'] ?? ''}',
      createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
      kitId: json['kit_id'] == null ? null : '${json['kit_id']}',
    );
  }
}

// ============================================================================
//  AGENCE VIDÉO IA
// ============================================================================
class ProjetVideo {
  const ProjetVideo({
    required this.id,
    required this.theme,
    required this.statut,
    this.decorticage,
    this.srt,
    this.hooks,
    this.copy,
    this.youtubeVideoId,
    this.tiktokPublishId,
    this.videoUrl,
    this.videoFilename,
  });

  final String id;
  final String theme;
  final String statut;
  final Map<String, dynamic>? decorticage;
  final String? srt;
  final Map<String, dynamic>? hooks;
  final Map<String, dynamic>? copy;
  final String? youtubeVideoId;
  final String? tiktokPublishId;
  final String? videoUrl;
  final String? videoFilename;

  factory ProjetVideo.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? mapping(dynamic valeur) {
      if (valeur is Map) return Map<String, dynamic>.from(valeur);
      return null;
    }

    return ProjetVideo(
      id: '${json['id']}',
      theme: '${json['theme'] ?? ''}',
      statut: '${json['statut'] ?? ''}',
      decorticage: mapping(json['decorticage']),
      srt: json['srt'] == null ? null : '${json['srt']}',
      hooks: mapping(json['hooks']),
      copy: mapping(json['copy']),
      youtubeVideoId: json['youtube_video_id'] == null ? null : '${json['youtube_video_id']}',
      tiktokPublishId: json['tiktok_publish_id'] == null ? null : '${json['tiktok_publish_id']}',
      videoUrl: json['video_url'] == null ? null : '${json['video_url']}',
      videoFilename: json['video_filename'] == null ? null : '${json['video_filename']}',
    );
  }

  /// Contenu copy d'un réseau : youtube, tiktok, instagram, facebook, pinterest.
  Map<String, dynamic> reseau(String nom) {
    final valeur = copy?[nom];
    if (valeur is Map) return Map<String, dynamic>.from(valeur);
    return <String, dynamic>{};
  }

  /// Idées de vidéos suites proposées par l'Agent Décortiqueur.
  List<Map<String, dynamic>> get ideesSuites {
    final brut = decorticage?['idees_suites'];
    if (brut is! List) return const [];
    return brut
        .whereType<Map>()
        .map((element) => Map<String, dynamic>.from(element))
        .toList();
  }

  List<Map<String, dynamic>> get argumentsChiffres {
    final brut = decorticage?['arguments_chiffres'];
    if (brut is! List) return const [];
    return brut
        .whereType<Map>()
        .map((element) => Map<String, dynamic>.from(element))
        .toList();
  }
}

// ============================================================================
//  AVIS CLIENTS DU SITE (note 1 à 5 étoiles)
// ============================================================================
class AvisSite {
  const AvisSite({
    required this.id,
    required this.note,
    required this.nom,
    this.pays,
    this.ville,
    required this.commentaire,
    required this.createdAt,
  });

  final String id;
  final int note;
  final String nom;
  final String? pays;
  final String? ville;
  final String commentaire;
  final DateTime createdAt;

  factory AvisSite.fromJson(Map<String, dynamic> json) {
    String? texteOuNull(dynamic valeur) {
      if (valeur == null) return null;
      final texte = '$valeur'.trim();
      return texte.isEmpty ? null : texte;
    }

    return AvisSite(
      id: '${json['id']}',
      note: (json['note'] as num?)?.toInt() ?? 0,
      nom: '${json['nom'] ?? ''}'.trim(),
      pays: texteOuNull(json['pays']),
      ville: texteOuNull(json['ville']),
      commentaire: '${json['commentaire'] ?? ''}'.trim(),
      createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
    );
  }

  /// « Abidjan · Côte d'Ivoire » (ou vide).
  String get localisation {
    final morceaux = <String>[?ville, ?pays];
    return morceaux.join(' · ');
  }

  String get initiale {
    final propre = nom.trim();
    return propre.isEmpty ? '?' : propre.substring(0, 1).toUpperCase();
  }
}
