// ============================================================================
//  Modèles de données partagés entre l'application et les Edge Functions.
// ============================================================================

/// Prestataire de paiement utilisé pour une commande.
enum Fournisseur {
  sasPay,
  paddle;

  String get api => this == Fournisseur.sasPay ? 'saspay' : 'paddle';

  String get libelle => this == Fournisseur.sasPay ? 'SasPay' : 'Paddle';

  static Fournisseur depuis(String? valeur) {
    return (valeur ?? '').toLowerCase() == 'paddle'
        ? Fournisseur.paddle
        : Fournisseur.sasPay;
  }
}

/// Résultat de la création d'un checkout (kit ou Studio Live).
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
    this.subscriptionId = '',
    this.transactionId = '',
    this.clientToken = '',
    this.environment = 'production',
    this.fournisseur = Fournisseur.sasPay,
    this.kind = 'kit',
    this.montantIndicatif,
    this.deviseIndicative,
  });

  final String orderId;
  final String subscriptionId;
  final String sessionId;
  final String transactionId;
  final String checkoutUrl;
  final String clientToken;
  final String environment;
  final num montant;
  final String devise;
  final String offre;
  final String metier;
  final String pays;
  final Fournisseur fournisseur;
  final String kind;
  final num? montantIndicatif;
  final String? deviseIndicative;

  bool get estStudio => kind == 'studio';
  String get reference => orderId.isNotEmpty ? orderId : subscriptionId;
  String get montantAffiche => '$montant $devise';

  factory CheckoutCree.fromJson(Map<String, dynamic> json) {
    return CheckoutCree(
      orderId: '${json['order_id'] ?? ''}',
      subscriptionId: '${json['subscription_id'] ?? ''}',
      sessionId: '${json['session_id'] ?? ''}',
      transactionId: '${json['transaction_id'] ?? ''}',
      checkoutUrl: '${json['checkout_url'] ?? ''}',
      clientToken: '${json['client_token'] ?? ''}',
      environment: '${json['environment'] ?? 'production'}',
      montant: (json['montant'] as num?) ?? (json['montant_fcfa'] as num?) ?? 0,
      devise: '${json['devise'] ?? 'XOF'}',
      offre: '${json['offre'] ?? ''}',
      metier: '${json['metier'] ?? ''}',
      pays: '${json['pays'] ?? ''}',
      fournisseur: Fournisseur.depuis('${json['provider'] ?? ''}'),
      kind: '${json['kind'] ?? 'kit'}',
      montantIndicatif: json['montant_indicatif'] as num?,
      deviseIndicative:
          json['devise_indicative'] == null ? null : '${json['devise_indicative']}',
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
    this.abonnement,
    this.guide,
    this.montantLocal,
    this.devise,
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
  final AbonnementStudio? abonnement;
  final GuideLive? guide;
  final num? montantLocal;
  final String? devise;

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

    final abonnement = json['abonnement'];
    final guide = json['guide'];

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
      abonnement: abonnement is Map
          ? AbonnementStudio.fromJson(Map<String, dynamic>.from(abonnement))
          : null,
      guide: guide is Map
          ? GuideLive.fromJson(Map<String, dynamic>.from(guide))
          : null,
      montantLocal: (commande['montant_local'] as num?) ??
          (json['montant_local'] as num?),
      devise: commande['devise_locale'] == null && commande['devise'] == null
          ? null
          : '${commande['devise_locale'] ?? commande['devise']}',
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
    this.montantLocal,
    this.devise,
  });

  final String id;
  final String nomProjet;
  final String metier;
  final String produitType;
  final int montant;
  final String statut;
  final DateTime createdAt;
  final String? kitId;
  final num? montantLocal;
  final String? devise;

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
      montantLocal: json['montant_local'] as num?,
      devise: json['devise_locale'] == null ? null : '${json['devise_locale']}',
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

// ============================================================================
//  STUDIO LIVE — abonnement 10 USD, sessions, guide, chat temps réel
// ============================================================================

/// Essai gratuit Studio Live (3 jours), créé uniquement côté serveur.
class EssaiStudio {
  const EssaiStudio({
    required this.userId,
    required this.startedAt,
    required this.endsAt,
    required this.createdAt,
  });

  /// Durée fixe de l'essai : 3 jours, jamais prolongeable.
  static const int dureeJours = 3;

  final String userId;
  final DateTime startedAt;
  final DateTime endsAt;
  final DateTime createdAt;

  bool get estActif => endsAt.isAfter(DateTime.now());

  bool get estExpire => !estActif;

  int get joursRestants {
    final restant = endsAt.difference(DateTime.now());
    if (restant.isNegative) return 0;
    return (restant.inHours / 24).ceil().clamp(0, 3).toInt();
  }

  String get libelle => estActif
      ? 'Essai gratuit · $joursRestants j restants'
      : 'Votre essai est terminé';

  factory EssaiStudio.fromJson(Map<String, dynamic> json) {
    final debut = DateTime.tryParse('${json['started_at']}') ?? DateTime.now();
    final fin = DateTime.tryParse('${json['ends_at']}') ??
        debut.add(const Duration(days: EssaiStudio.dureeJours));
    return EssaiStudio(
      userId: '${json['user_id'] ?? ''}',
      startedAt: debut,
      endsAt: fin,
      createdAt: DateTime.tryParse('${json['created_at']}') ?? debut,
    );
  }
}

/// Accès effectif au Studio Live : abonnement payé actif OU essai non expiré.
class AccesStudio {
  const AccesStudio({this.abonnement, this.essai});

  final AbonnementStudio? abonnement;
  final EssaiStudio? essai;

  bool get estPaye => abonnement?.estActif == true;

  bool get estEssai => !estPaye && essai?.estActif == true;

  bool get essaiExpire => !estPaye && essai != null && essai!.estExpire;

  bool get aAcces => estPaye || estEssai;

  /// Le Livre Guide et les guides sont réservés aux abonnements payés.
  bool get guideAutorise => estPaye;

  bool get abonnementEnAttente => !estPaye && abonnement?.estEnAttente == true;

  String get libelleAcces {
    if (estPaye) return abonnement!.libelleStatut;
    if (estEssai) return essai!.libelle;
    if (essaiExpire) return 'Votre essai est terminé';
    if (abonnementEnAttente) return 'Paiement en attente';
    return 'Aucun accès actif';
  }
}

/// Abonnement Studio Live (30 jours).
class AbonnementStudio {
  const AbonnementStudio({
    required this.id,
    required this.email,
    required this.nomActivite,
    required this.metierCode,
    required this.metierLabel,
    required this.paysCode,
    required this.paysLabel,
    required this.devise,
    required this.montantLocal,
    required this.provider,
    required this.status,
    required this.guideStatus,
    required this.createdAt,
    this.montantUsd = 10,
    this.userId,
    this.expiresAt,
    this.paidAt,
    this.guideError,
  });

  final String id;
  final String? userId;
  final String email;
  final String nomActivite;
  final String metierCode;
  final String metierLabel;
  final String paysCode;
  final String paysLabel;
  final String devise;
  final num montantLocal;
  final num montantUsd;
  final String provider;
  final String status;
  final String guideStatus;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? paidAt;
  final String? guideError;

  bool get estActif =>
      status == 'ACTIF' &&
      expiresAt != null &&
      expiresAt!.isAfter(DateTime.now());

  bool get estEnAttente => status == 'EN_ATTENTE' || status == 'PAYE';

  int get joursRestants {
    if (expiresAt == null) return 0;
    final difference = expiresAt!.difference(DateTime.now()).inDays;
    return difference < 0 ? 0 : difference;
  }

  String get libelleStatut {
    switch (status) {
      case 'ACTIF':
        return estActif ? 'Actif · $joursRestants j restants' : 'Expiré';
      case 'PAYE':
        return 'Paiement reçu · activation';
      case 'EN_ATTENTE':
        return 'En attente de paiement';
      case 'EXPIRE':
        return 'Abonnement expiré';
      case 'ECHEC':
        return 'Paiement échoué';
      default:
        return status;
    }
  }

  factory AbonnementStudio.fromJson(Map<String, dynamic> json) {
    return AbonnementStudio(
      id: '${json['id'] ?? ''}',
      userId: json['user_id'] == null ? null : '${json['user_id']}',
      email: '${json['email'] ?? ''}',
      nomActivite: '${json['nom_activite'] ?? ''}',
      metierCode: '${json['metier_code'] ?? ''}',
      metierLabel: '${json['metier_label'] ?? json['metier_code'] ?? ''}',
      paysCode: '${json['pays_code'] ?? ''}',
      paysLabel: '${json['pays_label'] ?? ''}',
      devise: '${json['devise'] ?? 'USD'}',
      montantLocal: (json['montant_local'] as num?) ?? 0,
      montantUsd: (json['montant_usd'] as num?) ?? 10,
      provider: '${json['provider'] ?? 'saspay'}',
      status: '${json['status'] ?? 'EN_ATTENTE'}',
      guideStatus: '${json['guide_status'] ?? 'EN_ATTENTE'}',
      createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.tryParse('${json['expires_at']}'),
      paidAt: json['paid_at'] == null ? null : DateTime.tryParse('${json['paid_at']}'),
      guideError: json['guide_error'] == null ? null : '${json['guide_error']}',
    );
  }

  /// Insertion initiale côté client (jamais utilisée pour le statut).
  Map<String, dynamic> toInsertJson() => <String, dynamic>{
        'nom_activite': nomActivite,
        'metier_code': metierCode,
        'metier_label': metierLabel,
        'pays_code': paysCode,
      };
}

/// Livre Guide Live personnalisé.
class GuideLive {
  const GuideLive({
    required this.id,
    required this.subscriptionId,
    required this.titre,
    required this.contenuHtml,
    required this.contenuMarkdown,
    required this.statut,
    required this.createdAt,
  });

  final String id;
  final String subscriptionId;
  final String titre;
  final String contenuHtml;
  final String contenuMarkdown;
  final String statut;
  final DateTime createdAt;

  bool get estPret => statut == 'PRET' && contenuHtml.trim().isNotEmpty;

  factory GuideLive.fromJson(Map<String, dynamic> json) {
    return GuideLive(
      id: '${json['id'] ?? ''}',
      subscriptionId: '${json['subscription_id'] ?? ''}',
      titre: '${json['titre'] ?? 'Mon Livre Guide Live'}',
      contenuHtml: '${json['contenu_html'] ?? ''}',
      contenuMarkdown: '${json['contenu_markdown'] ?? ''}',
      statut: '${json['statut'] ?? 'EN_ATTENTE'}',
      createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
    );
  }
}

/// Une session de régie live (onglet A).
class SessionLive {
  const SessionLive({
    required this.id,
    required this.subscriptionId,
    required this.roomId,
    required this.inviteToken,
    required this.titre,
    required this.plateformes,
    required this.format,
    required this.modeVisuel,
    required this.ficheProduit,
    required this.statut,
    this.userId,
    this.createdAt,
  });

  final String id;
  final String subscriptionId;
  final String? userId;
  final String roomId;
  final String inviteToken;
  final String titre;
  final List<String> plateformes;
  final String format;
  final String modeVisuel;
  final Map<String, dynamic> ficheProduit;
  final String statut;
  final DateTime? createdAt;

  bool get estDuo => format == 'DUO';
  bool get partageEcran => modeVisuel == 'ECRAN';

  String get libelleFormat => format == 'DUO' ? 'Duo / co-animateur' : 'Solo';
  String get libelleMode =>
      modeVisuel == 'ECRAN' ? 'Partage d\'écran' : 'Caméra produits';

  factory SessionLive.fromJson(Map<String, dynamic> json) {
    final plateformes = <String>[];
    final brut = json['plateformes'];
    if (brut is List) {
      for (final element in brut) {
        plateformes.add('$element');
      }
    }
    return SessionLive(
      id: '${json['id'] ?? ''}',
      subscriptionId: '${json['subscription_id'] ?? ''}',
      userId: json['user_id'] == null ? null : '${json['user_id']}',
      roomId: '${json['room_id'] ?? ''}',
      inviteToken: '${json['invite_token'] ?? ''}',
      titre: '${json['titre'] ?? ''}',
      plateformes: plateformes,
      format: '${json['format'] ?? 'SOLO'}',
      modeVisuel: '${json['mode_visuel'] ?? 'CAMERA'}',
      ficheProduit: json['fiche_produit'] is Map
          ? Map<String, dynamic>.from(json['fiche_produit'] as Map)
          : <String, dynamic>{},
      statut: '${json['statut'] ?? 'BROUILLON'}',
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse('${json['created_at']}'),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (id.isNotEmpty) 'id': id,
        if (subscriptionId.isNotEmpty) 'subscription_id': subscriptionId,
        if (userId != null) 'user_id': userId,
        'room_id': roomId,
        'invite_token': inviteToken,
        'titre': titre,
        'plateformes': plateformes,
        'format': format,
        'mode_visuel': modeVisuel,
        'fiche_produit': ficheProduit,
        'statut': statut,
      };

  SessionLive copieAvec({
    String? titre,
    List<String>? plateformes,
    String? format,
    String? modeVisuel,
    Map<String, dynamic>? ficheProduit,
    String? statut,
  }) {
    return SessionLive(
      id: id,
      subscriptionId: subscriptionId,
      userId: userId,
      roomId: roomId,
      inviteToken: inviteToken,
      titre: titre ?? this.titre,
      plateformes: plateformes ?? this.plateformes,
      format: format ?? this.format,
      modeVisuel: modeVisuel ?? this.modeVisuel,
      ficheProduit: ficheProduit ?? this.ficheProduit,
      statut: statut ?? this.statut,
      createdAt: createdAt,
    );
  }
}

/// Message du chat live (salle ou réseau social importé).
class MessageLive {
  const MessageLive({
    required this.id,
    required this.roomId,
    required this.role,
    required this.author,
    required this.content,
    required this.platform,
    required this.createdAt,
  });

  final String id;
  final String roomId;
  final String role;
  final String author;
  final String content;
  final String platform;
  final DateTime createdAt;

  bool get estAssistant => role == 'assistant';

  factory MessageLive.fromJson(Map<String, dynamic> json) {
    return MessageLive(
      id: '${json['id'] ?? ''}',
      roomId: '${json['room_id'] ?? ''}',
      role: '${json['role'] ?? 'user'}',
      author: '${json['author'] ?? ''}',
      content: '${json['content'] ?? ''}',
      platform: '${json['platform'] ?? 'SALLE'}',
      createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
    );
  }
}

/// Réponse du chat IA live.
class ReponseChatLive {
  const ReponseChatLive({required this.reply, this.message});

  final String reply;
  final MessageLive? message;
}
