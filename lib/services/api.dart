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
  //  PAIEMENT SASPAY
  // --------------------------------------------------------------------------
  static Future<CheckoutCree> creerPaiement({
    required String metierCode,
    required String nomProjet,
    required String paysCode,
    required String whatsapp,
    required String email,
    required String produitType,
    String? precisions,
  }) async {
    try {
      final reponse = await _client.functions.invoke(
        'saspay-checkout',
        body: {
          'metier_code': metierCode,
          'nom_projet': nomProjet,
          'pays_code': paysCode,
          'whatsapp': whatsapp,
          'email': email,
          'produit_type': produitType,
          'precisions': precisions ?? '',
        },
      );
      return CheckoutCree.fromJson(_map(reponse.data));
    } catch (erreur) {
      throw ApiException(_messageErreur(erreur));
    }
  }

  /// Vérifie le paiement auprès de SasPay et déclenche la livraison.
  static Future<ResultatCommande> verifierPaiement({required String orderId}) async {
    try {
      final reponse = await _client.functions.invoke(
        'verify-payment',
        body: {'order_id': orderId},
      );
      return ResultatCommande.fromJson(_map(reponse.data));
    } on FunctionException catch (erreur) {
      final details = _map(erreur.details);
      if (details['paid'] == true) {
        // Paiement encaissé mais génération en échec : on peut réessayer.
        return ResultatCommande(
          orderId: orderId,
          paid: true,
          statut: 'ERREUR',
          liens: LiensKit.fromJson(details['liens']),
          livraison: EtatLivraison.fromJson(details['livraison']),
          message: '${details['error'] ?? 'La génération a échoué. Réessayez dans un instant.'}',
        );
      }
      throw ApiException(_messageErreur(erreur));
    } catch (erreur) {
      throw ApiException(_messageErreur(erreur));
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

  static Future<bool> estAdmin() async {
    final utilisateur = _client.auth.currentUser;
    if (utilisateur == null) return false;
    try {
      final profil = await _client
          .from('profiles')
          .select('is_admin')
          .eq('id', utilisateur.id)
          .maybeSingle();
      return profil?['is_admin'] == true;
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
