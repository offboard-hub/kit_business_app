import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../core/models.dart';

/// Erreur métier lisible par l'interface.
class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ReponseAssistant {
  const ReponseAssistant({
    required this.reply,
    required this.ctaUrl,
    required this.suggestions,
  });

  final String reply;
  final String ctaUrl;
  final List<String> suggestions;
}

/// ============================================================================
///  Point d'entrée unique vers Supabase (Edge Functions + base).
/// ============================================================================
class ApiService {
  const ApiService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Map<String, dynamic> _map(dynamic donnees) {
    if (donnees is Map) return Map<String, dynamic>.from(donnees);
    return <String, dynamic>{};
  }

  static String _messageErreur(Object erreur) {
    if (erreur is FunctionException) {
      final details = erreur.details;
      if (details is Map && details['error'] != null) return '${details['error']}';
      if (details is String && details.trim().isNotEmpty) return details;
      return 'Erreur serveur (${erreur.status}).';
    }
    if (erreur is PostgrestException) return erreur.message;
    if (erreur is AuthException) return erreur.message;
    if (erreur is ApiException) return erreur.message;
    return erreur.toString().replaceFirst('Exception: ', '');
  }

  // --------------------------------------------------------------------------
  //  CHECKOUT — routage SasPay / Paddle (kits & Studio Live)
  // --------------------------------------------------------------------------
  static String _fonctionCheckout(Fournisseur fournisseur) {
    return fournisseur == Fournisseur.sasPay
        ? 'saspay-checkout'
        : 'create-paddle-checkout';
  }

  static Map<String, dynamic> _corpsCheckout({
    required String kind,
    required String metierCode,
    required String metierLabel,
    required String nomProjet,
    required String paysCode,
    required String whatsapp,
    required String email,
    required String produitType,
    String? precisions,
  }) {
    return <String, dynamic>{
      'kind': kind,
      'metier_code': metierCode,
      'metier_label': metierLabel,
      'nom_projet': nomProjet,
      'pays_code': paysCode,
      'whatsapp': whatsapp,
      'email': email,
      'produit_type': produitType,
      'precisions': precisions ?? '',
    };
  }

  /// Crée un checkout pour un kit métier (La Boutique).
  static Future<CheckoutCree> creerCheckoutKit({
    required String metierCode,
    required String metierLabel,
    required String nomProjet,
    required String paysCode,
    required String whatsapp,
    required String email,
    required String produitType,
    required Fournisseur fournisseur,
    String? precisions,
  }) async {
    try {
      final reponse = await _client.functions.invoke(
        _fonctionCheckout(fournisseur),
        body: _corpsCheckout(
          kind: 'kit',
          metierCode: metierCode,
          metierLabel: metierLabel,
          nomProjet: nomProjet,
          paysCode: paysCode,
          whatsapp: whatsapp,
          email: email,
          produitType: produitType,
          precisions: precisions,
        ),
      );
      return CheckoutCree.fromJson(_map(reponse.data));
    } catch (erreur) {
      throw ApiException(_messageErreur(erreur));
    }
  }

  /// Crée un checkout pour l'abonnement Studio Live (10 USD / 30 jours).
  static Future<CheckoutCree> creerCheckoutStudio({
    required String nomActivite,
    required String metierCode,
    required String metierLabel,
    required String paysCode,
    required String whatsapp,
    required String email,
    required Fournisseur fournisseur,
  }) async {
    try {
      final reponse = await _client.functions.invoke(
        _fonctionCheckout(fournisseur),
        body: _corpsCheckout(
          kind: 'studio',
          metierCode: metierCode,
          metierLabel: metierLabel,
          nomProjet: nomActivite,
          paysCode: paysCode,
          whatsapp: whatsapp,
          email: email,
          produitType: 'studio',
        ),
      );
      return CheckoutCree.fromJson(_map(reponse.data));
    } catch (erreur) {
      throw ApiException(_messageErreur(erreur));
    }
  }

  /// Vérifie le paiement SasPay ou Paddle et déclenche la livraison.
  static Future<ResultatCommande> verifierPaiement({
    String? orderId,
    String? subscriptionId,
    String? provider,
  }) async {
    try {
      final corps = <String, dynamic>{};
      if (orderId != null && orderId.isNotEmpty) corps['order_id'] = orderId;
      if (subscriptionId != null && subscriptionId.isNotEmpty) {
        corps['subscription_id'] = subscriptionId;
      }
      if (provider != null) corps['provider'] = provider;

      final reponse = await _client.functions.invoke(
        'verify-payment',
        body: corps,
      );
      return ResultatCommande.fromJson(_map(reponse.data));
    } on FunctionException catch (erreur) {
      final details = _map(erreur.details);
      if (details['paid'] == true) {
        return ResultatCommande.fromJson(details);
      }
      throw ApiException(_messageErreur(erreur));
    } catch (erreur) {
      throw ApiException(_messageErreur(erreur));
    }
  }

  // --------------------------------------------------------------------------
  //  STUDIO LIVE — abonnement, guide, sessions, chat temps réel
  // --------------------------------------------------------------------------
  static Future<AbonnementStudio?> monAbonnement() async {
    try {
      final utilisateur = _client.auth.currentUser;
      if (utilisateur == null) return null;

      // 1. Chercher d'abord un abonnement réellement actif, quel que soit son
      //    ancienneté (un utilisateur peut avoir plusieurs commandes).
      final actif = await _client
          .from('studio_subscriptions')
          .select()
          .eq('status', 'ACTIF')
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('expires_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (actif != null) {
        return AbonnementStudio.fromJson(Map<String, dynamic>.from(actif));
      }

      // 2. Sinon, le dernier abonnement (pour afficher « en attente » / expiré).
      final dernier = await _client
          .from('studio_subscriptions')
          .select()
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (dernier == null) return null;
      return AbonnementStudio.fromJson(Map<String, dynamic>.from(dernier));
    } catch (_) {
      return null;
    }
  }

  /// Essai gratuit de 3 jours déjà consommé (ou en cours) par l'utilisateur.
  static Future<EssaiStudio?> monEssai() async {
    try {
      final utilisateur = _client.auth.currentUser;
      if (utilisateur == null) return null;
      final ligne = await _client
          .from('live_subscriptions')
          .select()
          .eq('user_id', utilisateur.id)
          .maybeSingle();
      if (ligne == null) return null;
      return EssaiStudio.fromJson(Map<String, dynamic>.from(ligne));
    } catch (_) {
      return null;
    }
  }

  /// Démarre l'essai gratuit côté serveur (RPC security definer).
  /// Un seul essai par utilisateur, email confirmé requis, jamais prolongeable.
  static Future<EssaiStudio> demarrerEssai() async {
    try {
      final reponse = await _client.rpc('demarrer_essai_studio');
      final donnees = _map(reponse);
      if (donnees.isEmpty) {
        final essai = await monEssai();
        if (essai != null) return essai;
        throw ApiException('Impossible de démarrer l\'essai gratuit.');
      }
      return EssaiStudio.fromJson(donnees);
    } catch (erreur) {
      throw ApiException(_messageErreur(erreur));
    }
  }

  /// Accès effectif : abonnement actif OU essai gratuit non expiré.
  static Future<AccesStudio> accesStudio() async {
    try {
      final utilisateur = _client.auth.currentUser;
      if (utilisateur == null) return const AccesStudio();
      final abonnement = await monAbonnement();
      final essai = await monEssai();
      return AccesStudio(abonnement: abonnement, essai: essai);
    } catch (_) {
      return const AccesStudio();
    }
  }

  static Future<GuideLive?> monGuide(String subscriptionId) async {    if (subscriptionId.isEmpty) return null;
    try {
      final ligne = await _client
          .from('studio_guides')
          .select()
          .eq('subscription_id', subscriptionId)
          .maybeSingle();
      if (ligne == null) return null;
      return GuideLive.fromJson(Map<String, dynamic>.from(ligne));
    } catch (_) {
      return null;
    }
  }

  static Future<GuideLive> genererGuide(String subscriptionId) async {
    try {
      final reponse = await _client.functions.invoke(
        'generate-live-guide',
        body: <String, dynamic>{'subscription_id': subscriptionId},
      );
      final donnees = _map(_map(reponse.data)['guide']);
      return GuideLive.fromJson(donnees);
    } catch (erreur) {
      throw ApiException(_messageErreur(erreur));
    }
  }

  static Future<SessionLive> enregistrerSessionLive(SessionLive session) async {
    try {
      final utilisateur = _client.auth.currentUser;
      final donnees = session.toJson()
        ..['user_id'] = session.userId ?? utilisateur?.id;
      Map<String, dynamic> ligne;
      if (session.id.isEmpty) {
        ligne = await _client
            .from('studio_live_sessions')
            .insert(donnees)
            .select()
            .single();
      } else {
        ligne = await _client
            .from('studio_live_sessions')
            .update(donnees)
            .eq('id', session.id)
            .select()
            .single();
      }
      return SessionLive.fromJson(Map<String, dynamic>.from(ligne));
    } catch (erreur) {
      throw ApiException(_messageErreur(erreur));
    }
  }

  static Future<bool> changerStatutSession(String sessionId, String statut) async {
    if (sessionId.isEmpty) return false;
    try {
      await _client
          .from('studio_live_sessions')
          .update(<String, dynamic>{'statut': statut})
          .eq('id', sessionId);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<SessionLive>> mesSessionsLive(String? subscriptionId) async {
    if (subscriptionId == null || subscriptionId.isEmpty) {
      final utilisateur = _client.auth.currentUser;
      if (utilisateur == null) return const <SessionLive>[];
      try {
        final lignes = await _client
            .from('studio_live_sessions')
            .select()
            .eq('user_id', utilisateur.id)
            .order('created_at', ascending: false)
            .limit(10);
        return lignes
            .map((ligne) => SessionLive.fromJson(Map<String, dynamic>.from(ligne)))
            .toList();
      } catch (_) {
        return const <SessionLive>[];
      }
    }
    try {
      final lignes = await _client
          .from('studio_live_sessions')
          .select()
          .eq('subscription_id', subscriptionId)
          .order('created_at', ascending: false)
          .limit(10);
      return lignes
          .map((ligne) => SessionLive.fromJson(Map<String, dynamic>.from(ligne)))
          .toList();
    } catch (_) {
      return const <SessionLive>[];
    }
  }

  static Future<SessionLive?> sessionPublique(
    String roomId, {
    String? inviteToken,
  }) async {
    try {
      final reponse = await _client.functions.invoke(
        'studio-room',
        body: <String, dynamic>{
          'action': 'get',
          'room_id': roomId,
          'invite_token': ?inviteToken,
        },
      );
      final donnees = _map(_map(reponse.data)['session']);
      if (donnees.isEmpty) return null;
      return SessionLive.fromJson(donnees);
    } catch (_) {
      return null;
    }
  }

  static Future<ReponseChatLive> chatLive({
    required String roomId,
    required String message,
    required String author,
    required String platform,
    String? inviteToken,
  }) async {
    try {
      final reponse = await _client.functions.invoke(
        'live-auto-chat',
        body: <String, dynamic>{
          'action': 'ask',
          'room_id': roomId,
          'message': message,
          'author': author,
          'platform': platform,
          'invite_token': ?inviteToken,
        },
      );
      final donnees = _map(reponse.data);
      final messageBrut = donnees['message'];
      return ReponseChatLive(
        reply: '${donnees['reply'] ?? ''}',
        message: messageBrut is Map
            ? MessageLive.fromJson(Map<String, dynamic>.from(messageBrut))
            : null,
      );
    } catch (erreur) {
      throw ApiException(_messageErreur(erreur));
    }
  }

  static Future<List<MessageLive>> messagesLive(String roomId) async {
    try {
      final lignes = await _client
          .from('studio_live_messages')
          .select()
          .eq('room_id', roomId)
          .order('created_at', ascending: true)
          .limit(80);
      return lignes
          .map((ligne) => MessageLive.fromJson(Map<String, dynamic>.from(ligne)))
          .toList();
    } catch (_) {
      return const <MessageLive>[];
    }
  }

  // --------------------------------------------------------------------------
  //  EMAIL D'ACCUEIL (Resend) — simple information, sans confirmation
  // --------------------------------------------------------------------------
  static Future<void> envoyerEmailAccueil(String email, {String? prenom, String source = 'site'}) async {
    try {
      await _client.functions.invoke(
        'welcome-email',
        body: {'email': email, 'prenom': prenom ?? '', 'source': source},
      );
    } catch (_) {
      // Un email d'accueil manqué ne doit jamais bloquer le tunnel d'achat.
    }
  }

  /// Crée un compte confirmé côté serveur (sans SMTP Supabase), puis le client
  /// peut se connecter normalement. L'email d'accueil est envoyé via Resend.
  static Future<void> creerCompte({
    required String email,
    required String motDePasse,
    required String nom,
  }) async {
    try {
      final reponse = await _client.functions.invoke(
        'auth-signup',
        body: <String, dynamic>{
          'email': email,
          'password': motDePasse,
          'nom': nom,
        },
      );
      final donnees = _map(reponse.data);
      if (donnees['success'] != true) {
        throw ApiException('${donnees['error'] ?? 'Création du compte impossible.'}');
      }
    } catch (erreur) {
      if (erreur is ApiException) rethrow;
      throw ApiException(_messageErreur(erreur));
    }
  }

  // --------------------------------------------------------------------------
  //  ASSISTANT IA (bulle de chat)
  // --------------------------------------------------------------------------
  static Future<ReponseAssistant> assistant({
    required String message,
    required String conversationId,
  }) async {
    try {
      final reponse = await _client.functions.invoke(
        'site-assistant',
        body: {'message': message, 'conversation_id': conversationId, 'channel': 'web'},
      );
      final donnees = _map(reponse.data);
      final suggestions = <String>[];
      if (donnees['suggestions'] is List) {
        for (final element in donnees['suggestions'] as List) {
          suggestions.add('$element');
        }
      }
      return ReponseAssistant(
        reply: '${donnees['reply'] ?? 'Je n\'ai pas compris. Pouvez-vous reformuler ?'}',
        ctaUrl: '${donnees['cta_url'] ?? AppConfig.lienCommande}',
        suggestions: suggestions,
      );
    } catch (erreur) {
      throw ApiException(_messageErreur(erreur));
    }
  }

  // --------------------------------------------------------------------------
  //  AVIS CLIENTS DU SITE
  // --------------------------------------------------------------------------
  static Future<List<AvisSite>> listerAvis({int limite = 12}) async {
    try {
      final lignes = await _client
          .from('avis_site')
          .select()
          .eq('est_publie', true)
          .order('created_at', ascending: false)
          .limit(limite);
      return lignes
          .map((ligne) => AvisSite.fromJson(Map<String, dynamic>.from(ligne)))
          .toList();
    } catch (_) {
      // La page d'accueil doit rester fonctionnelle même si la table n'est pas
      // encore migrée ou si le réseau est indisponible.
      return const [];
    }
  }

  static Future<void> publierAvis({
    required int note,
    required String nom,
    String? pays,
    String? ville,
    required String commentaire,
  }) async {
    try {
      await _client.from('avis_site').insert({
        'note': note,
        'nom': nom.trim(),
        'pays': (pays ?? '').trim().isEmpty ? null : pays!.trim(),
        'ville': (ville ?? '').trim().isEmpty ? null : ville!.trim(),
        'commentaire': commentaire.trim(),
        'est_publie': true,
      });
    } catch (erreur) {
      throw ApiException(_messageErreur(erreur));
    }
  }

  // --------------------------------------------------------------------------
  //  ESPACE CLIENT
  // --------------------------------------------------------------------------
  static Future<int> credits() async {
    final utilisateur = _client.auth.currentUser;
    if (utilisateur == null) return 0;
    try {
      final profil = await _client
          .from('profiles')
          .select('credits')
          .eq('id', utilisateur.id)
          .maybeSingle();
      return (profil?['credits'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Compteur global des essais gratuits (RPC réservée aux administrateurs).
  static Future<Map<String, int>> compterEssaisAdmin() async {
    try {
      final reponse = await _client.rpc('admin_compter_essais_gratuits');
      final brut = reponse is List && reponse.isNotEmpty ? reponse.first : reponse;
      final donnees = _map(brut);
      int lire(String cle) => (donnees[cle] as num?)?.toInt() ?? 0;
      return <String, int>{
        'total': lire('total'),
        'actifs': lire('actifs'),
        'aujourdhui': lire('aujourdhui'),
        'sept_derniers_jours': lire('sept_derniers_jours'),
      };
    } catch (_) {
      return const <String, int>{};
    }
  }

  static Future<bool> estAdmin() async {
    final utilisateur = _client.auth.currentUser;
    if (utilisateur == null) return false;

    // 1. Rôle explicite en base (profiles.is_admin).
    try {
      final profil = await _client
          .from('profiles')
          .select('is_admin')
          .eq('id', utilisateur.id)
          .maybeSingle();
      if (profil?['is_admin'] == true) return true;
    } catch (_) {}

    // 2. Liste ADMIN_EMAILS côté serveur (jamais exposée au client).
    try {
      final reponse = await _client.functions.invoke('admin-check');
      return _map(reponse.data)['is_admin'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> mesKits() async {
    final utilisateur = _client.auth.currentUser;
    if (utilisateur == null) return [];
    final lignes = await _client
        .from('kits')
        .select()
        .eq('user_id', utilisateur.id)
        .order('created_at', ascending: false)
        .limit(50);
    return lignes.map((ligne) => Map<String, dynamic>.from(ligne)).toList();
  }

  static Future<List<CommandeResume>> mesCommandes() async {
    final utilisateur = _client.auth.currentUser;
    if (utilisateur == null) return [];
    try {
      final lignes = await _client
          .from('orders')
          .select()
          .eq('user_id', utilisateur.id)
          .order('created_at', ascending: false)
          .limit(30);
      return lignes
          .map((ligne) => CommandeResume.fromJson(Map<String, dynamic>.from(ligne)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Régénération manuelle d'un kit (consomme des crédits).
  static Future<Map<String, dynamic>> regenererKit({
    required String metierCode,
    required String nomProjet,
    required String paysCode,
    required String produitType,
    String? precisions,
  }) async {
    try {
      final reponse = await _client.functions.invoke(
        'generate-kit',
        body: {
          'metierCode': metierCode,
          'nomProjet': nomProjet,
          'paysCode': paysCode,
          'typeProduit': produitType,
          'precisions': precisions ?? '',
          'emailClient': _client.auth.currentUser?.email ?? '',
        },
      );
      return _map(reponse.data);
    } catch (erreur) {
      throw ApiException(_messageErreur(erreur));
    }
  }

  // --------------------------------------------------------------------------
  //  AGENCE VIDÉO IA (admin)
  // --------------------------------------------------------------------------
  static Future<ProjetVideo> analyserVideo({
    required String theme,
    String? transcript,
    String? projectId,
    String? videoUrl,
    String? videoFilename,
  }) async {
    try {
      final reponse = await _client.functions.invoke(
        'video-agency-pipeline',
        body: {
          'action': 'analyze',
          'theme': theme,
          'transcript': transcript ?? '',
          'project_id': ?projectId,
          'video_url': ?videoUrl,
          'video_filename': ?videoFilename,
        },
      );
      return ProjetVideo.fromJson(_map(_map(reponse.data)['project']));
    } catch (erreur) {
      throw ApiException(_messageErreur(erreur));
    }
  }

  static Future<ProjetVideo> mettreAJourVideo({
    required String projectId,
    String? theme,
    String? srt,
    Map<String, dynamic>? decorticage,
    Map<String, dynamic>? hooks,
    Map<String, dynamic>? copy,
  }) async {
    try {
      final reponse = await _client.functions.invoke(
        'video-agency-pipeline',
        body: {
          'action': 'update',
          'project_id': projectId,
          'theme': ?theme,
          'srt': ?srt,
          'decorticage': ?decorticage,
          'hooks': ?hooks,
          'copy': ?copy,
        },
      );
      return ProjetVideo.fromJson(_map(_map(reponse.data)['project']));
    } catch (erreur) {
      throw ApiException(_messageErreur(erreur));
    }
  }

  static Future<ProjetVideo> chargerVideo(String projectId) async {
    try {
      final reponse = await _client.functions.invoke(
        'video-agency-pipeline',
        body: {'action': 'status', 'project_id': projectId},
      );
      return ProjetVideo.fromJson(_map(_map(reponse.data)['project']));
    } catch (erreur) {
      throw ApiException(_messageErreur(erreur));
    }
  }

  static Future<List<Map<String, dynamic>>> listerVideos() async {    try {
      final reponse = await _client.functions.invoke(
        'video-agency-pipeline',
        body: {'action': 'list'},
      );
      final projets = _map(reponse.data)['projects'];
      if (projets is List) {
        return projets.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (erreur) {
      throw ApiException(_messageErreur(erreur));
    }
  }

  /// Envoi en brouillon à partir d'une URL externe (Drive, Bunny, Cloudflare…).
  static Future<Map<String, dynamic>> publierVideo({
    required String projectId,
    required List<String> platforms,
    String? sourceUrl,
  }) async {
    try {
      final reponse = await _client.functions.invoke(
        'video-agency-pipeline',
        body: {
          'action': 'publish',
          'project_id': projectId,
          'platforms': platforms.join(','),
          'source_url': ?sourceUrl,
        },
      );
      return _map(reponse.data);
    } catch (erreur) {
      throw ApiException(_messageErreur(erreur));
    }
  }

  /// Envoi en brouillon à partir du fichier choisi dans /admin-videos.
  /// Le binaire part directement vers YouTube/TikTok : aucun stockage Supabase.
  static Future<Map<String, dynamic>> publierVideoBinaire({
    required String projectId,
    required List<String> platforms,
    required Uint8List octets,
    required String filename,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null) throw ApiException('Votre session a expiré. Reconnectez-vous.');

    final reponse = await http.post(
      Uri.parse(AppConfig.fonction('video-agency-pipeline')),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'apikey': AppConfig.supabaseKey,
        'Content-Type': 'video/mp4',
        'x-project-id': projectId,
        'x-platforms': platforms.join(','),
        'x-video-filename': filename,
      },
      body: octets,
    );

    Map<String, dynamic> donnees = {};
    try {
      donnees = _map(jsonDecode(reponse.body));
    } catch (_) {}

    if (reponse.statusCode >= 400) {
      throw ApiException('${donnees['error'] ?? 'Envoi vidéo impossible (${reponse.statusCode}).'}');
    }
    return donnees;
  }

  /// Lien de téléchargement du fichier .srt (jeton en paramètre).
  static String lienSrt(String projectId) {
    final jeton = _client.auth.currentSession?.accessToken ?? '';
    return '${AppConfig.fonction('video-agency-pipeline')}?action=srt&id=$projectId&token=$jeton';
  }

  // --------------------------------------------------------------------------
  //  CONNEXION TIKTOK (OAuth 2.0, jetons stockés côté serveur)
  // --------------------------------------------------------------------------
  static Future<Map<String, dynamic>> demarrerConnexionTiktok() async {
    try {
      final reponse = await _client.functions.invoke(
        'tiktok-auth',
        body: {'action': 'start'},
      );
      return _map(reponse.data);
    } catch (erreur) {
      throw ApiException(_messageErreur(erreur));
    }
  }

  static Future<Map<String, dynamic>> finaliserConnexionTiktok({
    required String code,
    String? state,
  }) async {
    try {
      final reponse = await _client.functions.invoke(
        'tiktok-auth',
        body: {'action': 'callback', 'code': code, 'state': state ?? ''},
      );
      return _map(reponse.data);
    } catch (erreur) {
      throw ApiException(_messageErreur(erreur));
    }
  }

  static Future<Map<String, dynamic>> statutTiktok() async {
    try {
      final reponse = await _client.functions.invoke(
        'tiktok-auth',
        body: {'action': 'status'},
      );
      return _map(reponse.data);
    } catch (erreur) {
      throw ApiException(_messageErreur(erreur));
    }
  }

  static Future<void> deconnecterTiktok() async {
    try {
      await _client.functions.invoke(
        'tiktok-auth',
        body: {'action': 'disconnect'},
      );
    } catch (erreur) {
      throw ApiException(_messageErreur(erreur));
    }
  }
}
