import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/links.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../services/api.dart';
import '../services/video_picker.dart';
import '../widgets/app_header.dart';

/// ============================================================================
///  /admin-videos — AGENCE VIDÉO IA (4 agents) + distribution en brouillon.
///  ⚠️ Zéro stockage Supabase : seuls les textes sont enregistrés. Le .mp4
///  part directement vers YouTube / TikTok depuis la mémoire du navigateur.
/// ============================================================================
class AdminVideosPage extends StatefulWidget {
  const AdminVideosPage({super.key});

  @override
  State<AdminVideosPage> createState() => _AdminVideosPageState();
}

class _AdminVideosPageState extends State<AdminVideosPage> {
  final TextEditingController _theme = TextEditingController();
  final TextEditingController _transcript = TextEditingController();
  final TextEditingController _urlSource = TextEditingController();

  final TextEditingController _srt = TextEditingController();
  final TextEditingController _titreYoutube = TextEditingController();
  final TextEditingController _descriptionYoutube = TextEditingController();
  final TextEditingController _hashtagsYoutube = TextEditingController();
  final TextEditingController _captionTiktok = TextEditingController();
  final TextEditingController _captionInstagram = TextEditingController();
  final TextEditingController _postFacebook = TextEditingController();
  final TextEditingController _titrePinterest = TextEditingController();
  final TextEditingController _descriptionPinterest = TextEditingController();

  bool _verification = true;
  bool _admin = false;
  bool _analyse = false;
  bool _enregistrement = false;
  bool _publication = false;
  ProjetVideo? _projet;
  VideoSelection? _fichier;
  List<Map<String, dynamic>> _historique = [];

  // --- Connexion TikTok (OAuth) ---
  bool _tiktokChargement = false;
  bool _tiktokConnecte = false;
  Map<String, dynamic> _tiktokEtat = const {};

  bool _versYoutube = true;
  bool _versTiktok = true;
  bool _versInstagram = false;
  bool _versFacebook = false;
  bool _versPinterest = false;

  @override
  void initState() {
    super.initState();
    _verifierAcces();
  }

  @override
  void dispose() {
    for (final controleur in [
      _theme,
      _transcript,
      _urlSource,
      _srt,
      _titreYoutube,
      _descriptionYoutube,
      _hashtagsYoutube,
      _captionTiktok,
      _captionInstagram,
      _postFacebook,
      _titrePinterest,
      _descriptionPinterest,
    ]) {
      controleur.dispose();
    }
    super.dispose();
  }

  Future<void> _verifierAcces() async {
    final admin = await ApiService.estAdmin();
    if (!mounted) return;
    setState(() {
      _admin = admin;
      _verification = false;
    });
    if (admin) {
      _chargerHistorique();
      _chargerStatutTiktok();
    }
  }

  // --------------------------------------------------------------------------
  //  CONNEXION TIKTOK
  // --------------------------------------------------------------------------
  Future<void> _chargerStatutTiktok() async {
    if (!mounted) return;
    setState(() => _tiktokChargement = true);
    try {
      final etat = await ApiService.statutTiktok();
      if (!mounted) return;
      setState(() {
        _tiktokEtat = etat;
        _tiktokConnecte = etat['connected'] == true;
        _tiktokChargement = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _tiktokChargement = false);
    }
  }

  Future<void> _connecterTiktok() async {
    setState(() => _tiktokChargement = true);
    try {
      final resultat = await ApiService.demarrerConnexionTiktok();
      final url = '${resultat['auth_url'] ?? ''}';
      if (!mounted) return;
      setState(() => _tiktokChargement = false);

      if (url.isEmpty) {
        _toast('TikTok n\'a pas renvoyé d\'URL d\'autorisation.', couleur: K.danger);
        return;
      }

      final ouvert = await ouvrirLien(url);
      if (!mounted) return;

      if (!ouvert) {
        await _afficherLienTiktok(url);
        return;
      }

      await _afficherAttenteTiktok('${resultat['redirect_uri'] ?? ''}');
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _tiktokChargement = false);
      _toast(
        erreur is ApiException ? erreur.message : 'Connexion TikTok impossible.',
        couleur: K.danger,
      );
    }
  }

  Future<void> _afficherLienTiktok(String url) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: K.night,
        title: const Text('Autorisation TikTok', style: TextStyle(color: K.sand, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Le navigateur a bloqué l\'ouverture. Copiez ce lien dans un nouvel onglet :',
              style: TextStyle(color: K.mist, fontSize: 12.5, height: 1.5),
            ),
            const SizedBox(height: 10),
            SelectableText(url, style: const TextStyle(color: K.gold, fontSize: 11)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer', style: TextStyle(color: K.mist)),
          ),
          ElevatedButton(
            onPressed: () => ouvrirLienAvecRetour(context, url),
            style: ElevatedButton.styleFrom(backgroundColor: K.gold),
            child: const Text('Ouvrir', style: TextStyle(color: K.night)),
          ),
        ],
      ),
    );
  }

  Future<void> _afficherAttenteTiktok(String redirectUri) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: K.night,
        title: const Text('Autorisez TikTok', style: TextStyle(color: K.sand, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Une page TikTok s\'est ouverte dans un nouvel onglet. Autorisez l\'application, '
              'puis revenez ici : la connexion se termine automatiquement sur le site.',
              style: TextStyle(color: K.mist, fontSize: 12.5, height: 1.55),
            ),
            if (redirectUri.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('URL de retour à déclarer chez TikTok :',
                  style: TextStyle(color: K.mist, fontSize: 11)),
              const SizedBox(height: 4),
              SelectableText(redirectUri, style: const TextStyle(color: K.gold, fontSize: 11)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer', style: TextStyle(color: K.mist)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _chargerStatutTiktok();
            },
            style: ElevatedButton.styleFrom(backgroundColor: K.gold),
            child: const Text('Actualiser l\'état', style: TextStyle(color: K.night)),
          ),
        ],
      ),
    );
  }

  Future<void> _deconnecterTiktok() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: K.night,
        title: const Text('Déconnecter TikTok ?', style: TextStyle(color: K.sand, fontSize: 17)),
        content: const Text(
          'Les jetons seront supprimés de Supabase. Vous devrez réautoriser l\'application '
          'pour envoyer de nouvelles vidéos en brouillon.',
          style: TextStyle(color: K.mist, fontSize: 12.5, height: 1.55),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: K.mist)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: K.danger),
            child: const Text('Déconnecter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirme != true) return;

    setState(() => _tiktokChargement = true);
    try {
      await ApiService.deconnecterTiktok();
      if (!mounted) return;
      await _chargerStatutTiktok();
      _toast('TikTok déconnecté.', couleur: K.success);
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _tiktokChargement = false);
      _toast(
        erreur is ApiException ? erreur.message : 'Déconnexion impossible.',
        couleur: K.danger,
      );
    }
  }

  String _dateTiktok(dynamic iso) {
    if (iso == null) return '—';
    final date = DateTime.tryParse('$iso');
    if (date == null) return '—';
    final locale = date.toLocal();
    final jour = locale.day.toString().padLeft(2, '0');
    final mois = locale.month.toString().padLeft(2, '0');
    final heure = locale.hour.toString().padLeft(2, '0');
    final minute = locale.minute.toString().padLeft(2, '0');
    return '$jour/$mois/${locale.year} à $heure:$minute';
  }

  Future<void> _chargerHistorique() async {
    try {
      final projets = await ApiService.listerVideos();
      if (!mounted) return;
      setState(() => _historique = projets);
    } catch (_) {
      // L'historique n'est pas bloquant.
    }
  }

  void _toast(String message, {Color couleur = K.clay}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: couleur, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _choisirFichier() async {
    try {
      final selection = await choisirFichierVideo();
      if (selection == null) return;
      if (selection.taille > 90 * 1024 * 1024) {
        _toast('Vidéo trop lourde (${selection.tailleLisible}). Limite : 90 Mo.');
        return;
      }
      setState(() => _fichier = selection);
    } on UnsupportedError catch (erreur) {
      _toast(erreur.message ?? 'Sélection de fichier indisponible sur cette plateforme.');
    } catch (erreur) {
      _toast('Sélection impossible : $erreur');
    }
  }

  Future<void> _lancerAnalyse() async {
    if (_theme.text.trim().length < 4) {
      _toast('Décrivez le thème de la vidéo.');
      return;
    }

    setState(() => _analyse = true);
    try {
      final projet = await ApiService.analyserVideo(
        theme: _theme.text.trim(),
        transcript: _transcript.text.trim(),
        projectId: _projet?.id,
        videoUrl: _urlSource.text.trim().isEmpty ? null : _urlSource.text.trim(),
        videoFilename: _fichier?.nom,
      );
      if (!mounted) return;
      setState(() {
        _projet = projet;
        _analyse = false;
        _appliquerContenu(projet);
      });
      _toast('Les 4 agents ont terminé.', couleur: K.success);
      _chargerHistorique();
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _analyse = false);
      _toast(erreur is ApiException ? erreur.message : 'Analyse impossible.', couleur: K.danger);
    }
  }

  void _appliquerContenu(ProjetVideo projet) {
    _srt.text = projet.srt ?? '';

    final youtube = projet.reseau('youtube');
    _titreYoutube.text = '${youtube['titre'] ?? ''}';
    _descriptionYoutube.text = '${youtube['description'] ?? ''}';
    _hashtagsYoutube.text = _listeTexte(youtube['hashtags'] ?? youtube['tags']);

    _captionTiktok.text = '${projet.reseau('tiktok')['caption'] ?? ''}';
    _captionInstagram.text = '${projet.reseau('instagram')['caption'] ?? ''}';
    _postFacebook.text = '${projet.reseau('facebook')['post'] ?? ''}';
    _titrePinterest.text = '${projet.reseau('pinterest')['titre'] ?? ''}';
    _descriptionPinterest.text = '${projet.reseau('pinterest')['description'] ?? ''}';
  }

  String _listeTexte(dynamic valeur) {
    if (valeur is List) return valeur.map((element) => '$element').join(' ');
    return '${valeur ?? ''}';
  }

  List<Map<String, dynamic>> _listeMaps(dynamic valeur) {
    if (valeur is! List) return const [];
    return valeur
        .whereType<Map>()
        .map((element) => Map<String, dynamic>.from(element))
        .toList();
  }

  List<String> _depuisTexte(String texte) {
    return texte
        .split(RegExp(r'[\s,]+'))
        .map((element) => element.trim())
        .where((element) => element.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _copyDepuisChamps() {
    final base = Map<String, dynamic>.from(_projet?.copy ?? {});
    Map<String, dynamic> fusion(String cle, Map<String, dynamic> valeurs) {
      final existant = base[cle] is Map ? Map<String, dynamic>.from(base[cle] as Map) : <String, dynamic>{};
      return {...existant, ...valeurs};
    }

    base['youtube'] = fusion('youtube', {
      'titre': _titreYoutube.text.trim(),
      'description': _descriptionYoutube.text.trim(),
      'hashtags': _depuisTexte(_hashtagsYoutube.text),
    });
    base['tiktok'] = fusion('tiktok', {'caption': _captionTiktok.text.trim()});
    base['instagram'] = fusion('instagram', {'caption': _captionInstagram.text.trim()});
    base['facebook'] = fusion('facebook', {'post': _postFacebook.text.trim()});
    base['pinterest'] = fusion('pinterest', {
      'titre': _titrePinterest.text.trim(),
      'description': _descriptionPinterest.text.trim(),
    });
    return base;
  }

  Future<void> _enregistrer() async {
    final projet = _projet;
    if (projet == null) return;

    setState(() => _enregistrement = true);
    try {
      final misAJour = await ApiService.mettreAJourVideo(
        projectId: projet.id,
        srt: _srt.text,
        copy: _copyDepuisChamps(),
      );
      if (!mounted) return;
      setState(() {
        _projet = misAJour;
        _enregistrement = false;
      });
      _toast('Modifications enregistrées.', couleur: K.success);
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _enregistrement = false);
      _toast(erreur is ApiException ? erreur.message : 'Enregistrement impossible.', couleur: K.danger);
    }
  }

  Future<void> _editerAnalyse() async {
    final projet = _projet;
    if (projet == null || projet.decorticage == null) return;

    final controleur = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(projet.decorticage),
    );

    final valide = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: K.night,
        title: const Text('Analyse de l\'Agent Décortiqueur (JSON)', style: TextStyle(color: K.sand, fontSize: 16)),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: controleur,
            maxLines: 16,
            style: const TextStyle(color: K.sand, fontSize: 12, fontFamily: 'monospace'),
            decoration: const InputDecoration(
              filled: true,
              fillColor: K.deep,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: K.mist)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: K.gold),
            child: const Text('Enregistrer', style: TextStyle(color: K.night)),
          ),
        ],
      ),
    );

    if (valide != true) return;

    try {
      final decorticage = Map<String, dynamic>.from(jsonDecode(controleur.text) as Map);
      final misAJour = await ApiService.mettreAJourVideo(
        projectId: projet.id,
        decorticage: decorticage,
      );
      if (!mounted) return;
      setState(() => _projet = misAJour);
      _toast('Analyse mise à jour.', couleur: K.success);
    } catch (erreur) {
      _toast('JSON invalide : $erreur', couleur: K.danger);
    }
  }

  Future<void> _publier() async {
    final projet = _projet;
    if (projet == null) {
      _toast('Lancez d\'abord l\'analyse des 4 agents.');
      return;
    }

    final plateformes = <String>[
      if (_versYoutube) 'youtube',
      if (_versTiktok) 'tiktok',
      if (_versInstagram) 'instagram',
      if (_versFacebook) 'facebook',
      if (_versPinterest) 'pinterest',
    ];
    if (plateformes.isEmpty) {
      _toast('Choisissez au moins un réseau.');
      return;
    }
    if (_fichier == null && _urlSource.text.trim().isEmpty) {
      _toast('Déposez une vidéo ou renseignez une URL source externe.');
      return;
    }

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: K.night,
        title: const Text('Envoyer en brouillon ?', style: TextStyle(color: K.sand, fontSize: 17)),
        content: Text(
          'YouTube : la vidéo sera envoyée en privé (validation manuelle).\n'
          'TikTok : la vidéo sera déposée dans votre boîte de réception (brouillon).\n'
          'Aucun fichier n\'est stocké sur Supabase.\n\n'
          'Réseaux : ${plateformes.join(', ')}',
          style: const TextStyle(color: K.mist, fontSize: 12.5, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: K.mist)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: K.gold),
            child: const Text('Envoyer', style: TextStyle(color: K.night, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirme != true) return;

    setState(() => _publication = true);
    try {
      Map<String, dynamic> resultat;
      if (_fichier != null) {
        resultat = await ApiService.publierVideoBinaire(
          projectId: projet.id,
          platforms: plateformes,
          octets: _fichier!.octets,
          filename: _fichier!.nom,
        );
      } else {
        resultat = await ApiService.publierVideo(
          projectId: projet.id,
          platforms: plateformes,
          sourceUrl: _urlSource.text.trim(),
        );
      }

      if (!mounted) return;
      setState(() {
        _publication = false;
        _fichier = null;
      });

      final misAJour = await ApiService.chargerVideo(projet.id);
      if (!mounted) return;
      setState(() => _projet = misAJour);
      _chargerHistorique();
      await _afficherResultatPublication(resultat);
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _publication = false);
      _toast(erreur is ApiException ? erreur.message : 'Publication impossible.', couleur: K.danger);
    }
  }

  Future<void> _afficherResultatPublication(Map<String, dynamic> resultat) async {
    final avertissements = resultat['warnings'];
    final lignes = <String>[];
    if (avertissements is List) {
      for (final element in avertissements) {
        lignes.add('• $element');
      }
    }
    final resultats = resultat['results'];
    if (resultats is Map) {
      resultats.forEach((cle, valeur) {
        final ok = valeur is Map && valeur['ok'] == true;
        lignes.add('${ok ? "✅" : "⚠️"} $cle');
      });
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: K.night,
        title: const Text('Envoi terminé', style: TextStyle(color: K.sand, fontSize: 17)),
        content: Text(
          lignes.isEmpty ? 'Traitement terminé.' : lignes.join('\n'),
          style: const TextStyle(color: K.mist, fontSize: 12.5, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer', style: TextStyle(color: K.gold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_verification) {
      return const Scaffold(
        backgroundColor: K.night,
        body: Center(child: CircularProgressIndicator(color: K.gold)),
      );
    }

    if (!_admin) {
      return Scaffold(
        body: PatternBackground(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: GlassCard(
                    padding: const EdgeInsets.all(26),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_rounded, color: K.gold, size: 40),
                        const SizedBox(height: 14),
                        const Text(
                          'Accès réservé',
                          style: TextStyle(color: K.sand, fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Cette page est réservée à l\'administrateur. Connectez-vous avec un compte '
                          'dont le profil a is_admin = true (ou ajoutez votre email dans ADMIN_EMAILS).',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: K.mist, fontSize: 12.5, height: 1.55),
                        ),
                        const SizedBox(height: 18),
                        OrButton(
                          label: 'Aller à mon espace',
                          icone: Icons.person_rounded,
                          onPressed: () => Navigator.pushReplacementNamed(context, '/mon-espace'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: PatternBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const AppHeader(afficherAide: false),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.maybePop(context),
                                icon: const Icon(Icons.arrow_back_rounded, color: K.mist),
                              ),
                              const Expanded(
                                child: Text(
                                  'Agence Vidéo IA',
                                  style: TextStyle(
                                    color: K.sand,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const Puce(texte: 'ZÉRO STOCKAGE SUPABASE', icone: Icons.cloud_off_rounded),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '4 agents : décortiqueur, sous-titres & hooks, copywriter multi-réseaux, distributeur. '
                            'Le fichier vidéo n\'est jamais écrit dans Supabase Storage.',
                            style: TextStyle(color: K.mist, fontSize: 12.5, height: 1.5),
                          ),
                          const SizedBox(height: 14),
                          _blocTiktok(),
                          const SizedBox(height: 18),
                          _blocBrief(),
                          if (_projet != null) ...[
                            const SizedBox(height: 18),
                            _blocAgent1(_projet!),
                            const SizedBox(height: 14),
                            _blocAgent2(_projet!),
                            const SizedBox(height: 14),
                            _blocAgent3(),
                            const SizedBox(height: 14),
                            _blocAgent4(),
                          ],
                          const SizedBox(height: 20),
                          _blocHistorique(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  Widget _blocTiktok() {
    final expire = _tiktokEtat['expires_at'];
    final openId = _tiktokEtat['open_id'];
    final redirect = '${_tiktokEtat['redirect_uri'] ?? ''}';
    final couleur = _tiktokConnecte ? K.success : K.clay;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.music_note_rounded, color: K.gold, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Connexion TikTok',
                  style: TextStyle(color: K.sand, fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: couleur.withValues(alpha: 0.4)),
                ),
                child: Text(
                  _tiktokConnecte ? 'Connecté' : 'Non connecté',
                  style: TextStyle(color: couleur, fontSize: 10.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'L\'Agent Distributeur dépose la vidéo dans votre boîte de réception TikTok (brouillon). '
            'La connexion se fait en un clic, sans curl ni jeton à copier.',
            style: TextStyle(color: K.mist, fontSize: 11.5, height: 1.5),
          ),
          if (_tiktokConnecte) ...[
            const SizedBox(height: 12),
            _ligneTiktok('Compte', '${openId ?? '—'}'),
            _ligneTiktok('Jeton valide jusqu\'au', _dateTiktok(expire)),
          ],
          if (redirect.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'URL de retour TikTok : $redirect',
              style: TextStyle(color: K.mist.withValues(alpha: 0.7), fontSize: 10, height: 1.4),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (_tiktokConnecte)
                OutlinedButton.icon(
                  onPressed: _tiktokChargement ? null : _deconnecterTiktok,
                  icon: const Icon(Icons.link_off_rounded, color: K.clay, size: 17),
                  label: const Text('Déconnecter', style: TextStyle(color: K.clay, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: K.clay.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )
              else
                OrButton(
                  label: _tiktokChargement ? 'Ouverture…' : 'Connecter TikTok',
                  icone: Icons.music_note_rounded,
                  hauteur: 44,
                  plein: false,
                  onPressed: _tiktokChargement ? null : _connecterTiktok,
                ),
              TextButton.icon(
                onPressed: _tiktokChargement ? null : _chargerStatutTiktok,
                icon: const Icon(Icons.refresh_rounded, color: K.mist, size: 16),
                label: const Text('Actualiser', style: TextStyle(color: K.mist, fontSize: 11.5)),
              ),
            ],
          ),
          if (_tiktokChargement)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(color: K.gold, minHeight: 2),
            ),
        ],
      ),
    );
  }

  Widget _ligneTiktok(String libelle, String valeur) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(libelle, style: const TextStyle(color: K.mist, fontSize: 11)),
          ),
          Expanded(
            child: Text(
              valeur,
              style: const TextStyle(color: K.sand, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  Widget _blocBrief() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Brief de la vidéo',
            style: TextStyle(color: K.sand, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _theme,
            style: const TextStyle(color: K.sand),
            decoration: champ(
              label: 'Thème / sujet de la vidéo',
              hint: 'Ex : comment un maquis augmente sa marge de 30 % en 3 semaines',
              icone: Icons.lightbulb_rounded,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _transcript,
            maxLines: 4,
            style: const TextStyle(color: K.sand),
            decoration: champ(
              label: 'Transcription ou script (optionnel)',
              hint: 'Collez ici le texte dit dans la vidéo pour un décorticage plus précis.',
              icone: Icons.subject_rounded,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlSource,
            style: const TextStyle(color: K.sand),
            decoration: champ(
              label: 'URL externe de la vidéo (optionnel, recommandé)',
              hint: 'Drive, Bunny, Cloudflare R2… aucun fichier n\'est copié sur Supabase.',
              icone: Icons.link_rounded,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _analyse ? null : _choisirFichier,
                  icon: const Icon(Icons.video_file_rounded, color: K.gold, size: 18),
                  label: Text(
                    _fichier == null ? 'Déposer la vidéo (.mp4)' : '${_fichier!.nom} · ${_fichier!.tailleLisible}',
                    style: const TextStyle(color: K.sand, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: K.gold.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              if (_fichier != null)
                IconButton(
                  onPressed: () => setState(() => _fichier = null),
                  icon: const Icon(Icons.delete_outline_rounded, color: K.clay),
                ),
            ],
          ),
          const SizedBox(height: 12),
          OrButton(
            label: _analyse ? 'Les 4 agents travaillent…' : 'Lancer les 4 agents',
            icone: Icons.auto_awesome_rounded,
            chargement: _analyse,
            onPressed: _lancerAnalyse,
          ),
          if (_analyse) ...[
            const SizedBox(height: 10),
            const Text(
              'Génération en cours (30 à 120 secondes) : décorticage, sous-titres, copy des 5 réseaux.',
              style: TextStyle(color: K.mist, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  Widget _blocAgent1(ProjetVideo projet) {
    final decorticage = projet.decorticage ?? {};
    final accroche = decorticage['accroche_3_secondes'];
    final arguments = projet.argumentsChiffres;
    final idees = projet.ideesSuites;

    String texteAccroche(dynamic valeur) {
      if (valeur is Map) {
        return '${valeur['texte'] ?? ''}\n\nPourquoi ça marche : ${valeur['pourquoi_ca_marche'] ?? ''}'
            '\nAlternative : ${valeur['alternative_plus_forte'] ?? ''}';
      }
      return '${valeur ?? ''}';
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'AGENT 1 · DÉCORTIQUEUR',
                  style: TextStyle(color: K.gold, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
              ),
              TextButton.icon(
                onPressed: _editerAnalyse,
                icon: const Icon(Icons.edit_rounded, size: 14, color: K.mist),
                label: const Text('Éditer le JSON', style: TextStyle(color: K.mist, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (decorticage['diagnostic_brutal'] != null)
            Text(
              '${decorticage['diagnostic_brutal']}',
              style: const TextStyle(color: K.sand, fontSize: 13.5, height: 1.55, fontWeight: FontWeight.w600),
            ),
          if (accroche != null) ...[
            const SizedBox(height: 14),
            _sousTitre('Accroche des 3 premières secondes'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: K.night.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: K.gold.withValues(alpha: 0.25)),
              ),
              child: Text(
                texteAccroche(accroche),
                style: const TextStyle(color: K.sand, fontSize: 12.5, height: 1.55),
              ),
            ),
          ],
          if (arguments.isNotEmpty) ...[
            const SizedBox(height: 14),
            _sousTitre('Arguments chiffrés (FCFA)'),
            for (final argument in arguments)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.trending_up_rounded, color: K.green, size: 15),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${argument['argument'] ?? ''}'
                        '${argument['chiffre_fcfa'] != null ? " — ${AppConfig.fcfa((argument['chiffre_fcfa'] as num).toInt())}" : ""}',
                        style: const TextStyle(color: K.mist, fontSize: 12, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (idees.isNotEmpty) ...[
            const SizedBox(height: 14),
            _sousTitre('3 idées de vidéos suites (Lives OBS)'),
            for (final idee in idees)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: K.deep.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${idee['titre'] ?? ''}',
                      style: const TextStyle(color: K.sand, fontSize: 12.5, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${idee['angle'] ?? ''}',
                      style: const TextStyle(color: K.mist, fontSize: 11.5, height: 1.4),
                    ),
                  ],
                ),
              ),
          ],
          if (decorticage['analyse_gemini'] != null && '${decorticage['analyse_gemini']}'.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _sousTitre('Analyse Gemini (mise en scène)'),
            Text(
              '${decorticage['analyse_gemini']}',
              style: const TextStyle(color: K.mist, fontSize: 12, height: 1.55),
            ),
          ],
        ],
      ),
    );
  }

  Widget _blocAgent2(ProjetVideo projet) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AGENT 2 · SOUS-TITRES & HOOKS',
            style: TextStyle(color: K.gold, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _srt,
            maxLines: 10,
            style: const TextStyle(color: K.sand, fontSize: 11.5, fontFamily: 'monospace'),
            decoration: champ(
              label: 'Fichier .srt (modifiable)',
              icone: Icons.subtitles_rounded,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ouvrirLienAvecRetour(
                    context,
                    ApiService.lienSrt(projet.id),
                  ),
                  icon: const Icon(Icons.download_rounded, color: K.gold, size: 17),
                  label: const Text(
                    'Télécharger le .srt',
                    style: TextStyle(color: K.sand, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: K.gold.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          if (projet.hooks != null) ...[
            const SizedBox(height: 12),
            _sousTitre('Textes à incruster'),
            for (final hook in _listeMaps(projet.hooks!['hooks_ecran']))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${hook['moment'] ?? ''} — ${hook['texte'] ?? ''}',
                  style: const TextStyle(color: K.mist, fontSize: 12, height: 1.4),
                ),
              ),
            if (projet.hooks!['conseils_incrustation'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${projet.hooks!['conseils_incrustation']}',
                  style: const TextStyle(color: K.mist, fontSize: 11.5, height: 1.45),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _blocAgent3() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AGENT 3 · COPYWRITER MULTI-RÉSEAUX',
            style: TextStyle(color: K.gold, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          _champReseau('YouTube · titre', _titreYoutube),
          const SizedBox(height: 8),
          _champReseau('YouTube · description', _descriptionYoutube, lignes: 4),
          const SizedBox(height: 8),
          _champReseau('YouTube · hashtags / tags', _hashtagsYoutube),
          const SizedBox(height: 14),
          _champReseau('TikTok · caption', _captionTiktok, lignes: 2),
          const SizedBox(height: 8),
          _champReseau('Instagram · caption', _captionInstagram, lignes: 3),
          const SizedBox(height: 8),
          _champReseau('Facebook · publication', _postFacebook, lignes: 3),
          const SizedBox(height: 8),
          _champReseau('Pinterest · titre', _titrePinterest),
          const SizedBox(height: 8),
          _champReseau('Pinterest · description', _descriptionPinterest, lignes: 2),
          const SizedBox(height: 14),
          OrButton(
            label: 'Enregistrer les modifications',
            icone: Icons.save_rounded,
            plein: false,
            chargement: _enregistrement,
            onPressed: _enregistrer,
          ),
        ],
      ),
    );
  }

  Widget _champReseau(String label, TextEditingController controleur, {int lignes = 1}) {
    return TextField(
      controller: controleur,
      maxLines: lignes,
      style: const TextStyle(color: K.sand, fontSize: 12.5),
      decoration: champ(label: label),
    );
  }

  Widget _blocAgent4() {
    final projet = _projet;

    return GlassCard(
      miseEnAvant: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AGENT 4 · DISTRIBUTEUR (BROUILLON)',
            style: TextStyle(color: K.gold, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2),
          ),
          const SizedBox(height: 6),
          const Text(
            'YouTube : privacyStatus "private". TikTok : dépôt en brouillon (boîte de réception TikTok). '
            'Facebook / Instagram / Pinterest : payload prêt, validation manuelle.',
            style: TextStyle(color: K.mist, fontSize: 11.5, height: 1.5),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _caseReseau('YouTube', _versYoutube, (valeur) => setState(() => _versYoutube = valeur)),
              _caseReseau('TikTok', _versTiktok, (valeur) => setState(() => _versTiktok = valeur)),
              _caseReseau('Instagram', _versInstagram, (valeur) => setState(() => _versInstagram = valeur)),
              _caseReseau('Facebook', _versFacebook, (valeur) => setState(() => _versFacebook = valeur)),
              _caseReseau('Pinterest', _versPinterest, (valeur) => setState(() => _versPinterest = valeur)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.video_file_rounded, color: K.mist, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _fichier == null
                      ? (_urlSource.text.trim().isEmpty ? 'Aucune vidéo sélectionnée' : 'Source : ${_urlSource.text.trim()}')
                      : '${_fichier!.nom} · ${_fichier!.tailleLisible}',
                  style: const TextStyle(color: K.mist, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (projet?.youtubeVideoId != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'YouTube : ${projet!.youtubeVideoId} (privé)',
                style: const TextStyle(color: K.green, fontSize: 11),
              ),
            ),
          if (projet?.tiktokPublishId != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'TikTok : ${projet!.tiktokPublishId} (brouillon)',
                style: const TextStyle(color: K.green, fontSize: 11),
              ),
            ),
          const SizedBox(height: 14),
          OrButton(
            label: 'Lancer l\'envoi en brouillon',
            icone: Icons.cloud_upload_rounded,
            chargement: _publication,
            onPressed: _publier,
          ),
        ],
      ),
    );
  }

  Widget _caseReseau(String label, bool valeur, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label, style: TextStyle(color: valeur ? K.night : K.mist, fontSize: 11.5)),
      selected: valeur,
      onSelected: onChanged,
      selectedColor: K.gold,
      backgroundColor: K.deep,
      checkmarkColor: K.night,
      side: BorderSide(color: K.gold.withValues(alpha: 0.35)),
    );
  }

  Widget _blocHistorique() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Historique des projets',
            style: TextStyle(color: K.sand, fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (_historique.isEmpty)
            const Text(
              'Aucun projet pour l\'instant.',
              style: TextStyle(color: K.mist, fontSize: 12),
            )
          else
            for (final projet in _historique)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.movie_creation_outlined, color: K.gold, size: 18),
                title: Text(
                  '${projet['theme'] ?? ''}',
                  style: const TextStyle(color: K.sand, fontSize: 12.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${projet['statut'] ?? ''}',
                  style: const TextStyle(color: K.mist, fontSize: 10.5),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: K.mist, size: 18),
                onTap: () async {
                  try {
                    final complet = await ApiService.chargerVideo('${projet['id']}');
                    if (!mounted) return;
                    setState(() {
                      _projet = complet;
                      _theme.text = complet.theme;
                      _appliquerContenu(complet);
                    });
                  } catch (erreur) {
                    _toast('Chargement impossible : $erreur');
                  }
                },
              ),
        ],
      ),
    );
  }

  Widget _sousTitre(String texte) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        texte,
        style: const TextStyle(color: K.sand, fontSize: 12.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}
