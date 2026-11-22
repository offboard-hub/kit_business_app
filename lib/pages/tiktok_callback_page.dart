import 'package:flutter/material.dart';

import '../core/nettoyage_url.dart';
import '../core/theme.dart';
import '../services/api.dart';
import '../widgets/app_header.dart';

/// ============================================================================
///  Retour OAuth TikTok — SITE_URL/?code=...&state=...
///  L'application échange automatiquement le code contre un access_token,
///  qui est stocké côté serveur (jamais dans le navigateur), puis propose
///  d'ouvrir /admin-videos.
/// ============================================================================
class TiktokCallbackPage extends StatefulWidget {
  const TiktokCallbackPage({
    super.key,
    required this.code,
    this.state,
    this.erreurTiktok,
  });

  final String code;
  final String? state;
  final String? erreurTiktok;

  @override
  State<TiktokCallbackPage> createState() => _TiktokCallbackPageState();
}

class _TiktokCallbackPageState extends State<TiktokCallbackPage> {
  bool _chargement = true;
  bool _succes = false;
  String? _message;
  Map<String, dynamic> _details = const {};

  @override
  void initState() {
    super.initState();
    if (widget.erreurTiktok != null && widget.erreurTiktok!.isNotEmpty) {
      _chargement = false;
      _message = 'Autorisation TikTok refusée ou interrompue : ${widget.erreurTiktok}';
      _nettoyerUrl();
    } else {
      _finaliser();
    }
  }

  void _nettoyerUrl() {
    nettoyerParametresUrl([
      'code',
      'state',
      'scopes',
      'error',
      'error_description',
      'lang',
    ]);
  }

  Future<void> _finaliser() async {
    try {
      final resultat = await ApiService.finaliserConnexionTiktok(
        code: widget.code,
        state: widget.state,
      );
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _succes = resultat['connected'] == true;
        _details = resultat;
        if (!_succes) {
          _message = 'La connexion TikTok n\'a pas abouti. Relancez-la depuis /admin-videos.';
        }
      });
    } catch (erreur) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _succes = false;
        _message = erreur is ApiException
            ? erreur.message
            : 'Connexion TikTok impossible pour le moment.';
      });
    } finally {
      _nettoyerUrl();
    }
  }

  String _dateLisible(dynamic iso) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PatternBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const AppHeader(afficherAide: false),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 40),
                      child: GlassCard(
                        miseEnAvant: true,
                        padding: const EdgeInsets.all(26),
                        child: Column(
                          children: [
                            _iconeEtat(),
                            const SizedBox(height: 18),
                            Text(
                              _titre(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: K.sand,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _contenu(),
                            const SizedBox(height: 22),
                            _actions(),
                          ],
                        ),
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

  String _titre() {
    if (_chargement) return 'Connexion à TikTok…';
    if (_succes) return 'TikTok est connecté 🎉';
    return 'Connexion TikTok impossible';
  }

  Widget _iconeEtat() {
    final succes = !_chargement && _succes;
    final couleur = _chargement ? K.gold : (succes ? K.success : K.danger);

    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: couleur.withValues(alpha: 0.5)),
      ),
      child: Center(
        child: _chargement
            ? const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(color: K.gold, strokeWidth: 3),
              )
            : Icon(
                succes ? Icons.check_rounded : Icons.error_outline_rounded,
                color: couleur,
                size: 34,
              ),
      ),
    );
  }

  Widget _contenu() {
    if (_chargement) {
      return const Text(
        'Nous échangeons le code d\'autorisation contre un jeton sécurisé. '
        'Ne fermez pas cette page.',
        textAlign: TextAlign.center,
        style: TextStyle(color: K.mist, fontSize: 13, height: 1.55),
      );
    }

    if (!_succes) {
      return Column(
        children: [
          Text(
            _message ?? 'Une erreur est survenue pendant la connexion.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: K.sand, fontSize: 13, height: 1.55),
          ),
          const SizedBox(height: 10),
          const Text(
            'Vérifiez que vous êtes connecté avec le compte administrateur, '
            'puis relancez la connexion depuis /admin-videos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: K.mist, fontSize: 11.5, height: 1.5),
          ),
        ],
      );
    }

    return Column(
      children: [
        const Text(
          'Votre compte TikTok est autorisé. Les jetons sont enregistrés côté serveur : '
          'vous pouvez maintenant envoyer vos vidéos en brouillon.',
          textAlign: TextAlign.center,
          style: TextStyle(color: K.mist, fontSize: 12.5, height: 1.55),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: K.night.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: K.gold.withValues(alpha: 0.22)),
          ),
          child: Column(
            children: [
              _ligne('Compte', '${_details['open_id'] ?? '—'}', petit: true),
              _ligne('Portées', '${_details['scope'] ?? 'video.upload'}'),
              _ligne('Valide jusqu\'au', _dateLisible(_details['expires_at'])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ligne(String libelle, String valeur, {bool petit = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(libelle, style: const TextStyle(color: K.mist, fontSize: 11.5)),
          ),
          Expanded(
            child: Text(
              valeur,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: K.sand,
                fontSize: petit ? 10.5 : 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    return Column(
      children: [
        OrButton(
          label: 'Ouvrir /admin-videos',
          icone: Icons.movie_filter_rounded,
          onPressed: () => Navigator.pushReplacementNamed(context, '/admin-videos'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
          child: const Text('Retour à l\'accueil', style: TextStyle(color: K.mist, fontSize: 12.5)),
        ),
        const SizedBox(height: 4),
        Text(
          _succes
              ? 'Revenez sur l\'onglet /admin-videos déjà ouvert et actualisez l\'état TikTok.'
              : 'Astuce : la connexion doit être lancée depuis /admin-videos avec le compte administrateur.',
          textAlign: TextAlign.center,
          style: TextStyle(color: K.mist.withValues(alpha: 0.75), fontSize: 10.5, height: 1.4),
        ),
      ],
    );
  }
}
