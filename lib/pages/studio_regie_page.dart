import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../services/api.dart';
import '../services/jitsi_view.dart';
import '../services/telechargement.dart';
import '../widgets/logo_ebooklive.dart';

/// ============================================================================
///  RÉGIE STUDIO LIVE (abonnés) — 3 onglets internes propres :
///   A. Préparer mon Live
///   B. Salle en direct & chat IA
///   C. Mon Livre Guide Live
/// ============================================================================
class StudioRegiePage extends StatefulWidget {
  const StudioRegiePage({super.key});

  @override
  State<StudioRegiePage> createState() => _StudioRegiePageState();
}

class _StudioRegiePageState extends State<StudioRegiePage> {
  final Random _alea = Random.secure();
  final JitsiController _jitsi = const JitsiController();

  final TextEditingController _titre = TextEditingController();
  final TextEditingController _produits = TextEditingController();
  final TextEditingController _lien = TextEditingController();
  final TextEditingController _arguments = TextEditingController();

  AbonnementStudio? _abonnement;
  AccesStudio? _acces;
  SessionLive? _session;
  GuideLive? _guide;

  bool _chargement = true;
  bool _sauvegarde = false;
  bool _guideEnCours = false;
  String? _erreur;
  Timer? _minuteurAcces;

  Set<String> _plateformes = <String>{'SALLE'};
  String _format = 'SOLO';
  String _mode = 'CAMERA';
  int _onglet = 0;

  String _nomAnimateur = 'Animateur';

  @override
  void initState() {
    super.initState();
    _charger();
    _minuteurAcces = Timer.periodic(const Duration(seconds: 45), (_) {
      final acces = _acces;
      if (!mounted || acces == null) return;
      final essai = acces.essai;
      final essaiVientDExpirer = !acces.estPaye && essai != null && !essai.estActif;
      final abonnementVientDExpirer = !acces.estPaye && acces.abonnement != null &&
          !acces.abonnement!.estEnAttente;
      if (essaiVientDExpirer || abonnementVientDExpirer) {
        _minuteurAcces?.cancel();
        _charger();
      }
    });
  }

  @override
  void dispose() {
    _minuteurAcces?.cancel();
    _titre.dispose();
    _produits.dispose();
    _lien.dispose();
    _arguments.dispose();
    super.dispose();
  }

  String _hex(int octets) {
    final tampon = StringBuffer();
    for (var i = 0; i < octets; i++) {
      tampon.write(_alea.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return tampon.toString();
  }

  String get _lienPublication =>
      '${AppConfig.siteUrl.replaceAll(RegExp(r'/+$'), '')}/live/${_session?.roomId ?? ''}';

  String get _lienInvitation {
    final session = _session;
    if (session == null) return '';
    return '${AppConfig.siteUrl.replaceAll(RegExp(r'/+$'), '')}/live/${session.roomId}'
        '?invite=${session.inviteToken}';
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final utilisateur = Supabase.instance.client.auth.currentUser;
      if (utilisateur == null) {
        setState(() {
          _chargement = false;
          _erreur = 'connectez-vous';
        });
        return;
      }
      _nomAnimateur = utilisateur.email?.split('@').first ?? 'Animateur';

      final acces = await ApiService.accesStudio();
      if (!acces.aAcces) {
        setState(() {
          _acces = acces;
          _abonnement = acces.abonnement;
          _chargement = false;
        });
        return;
      }

      final abonnement = acces.abonnement;
      final sessions = await ApiService.mesSessionsLive(abonnement?.id);
      SessionLive session;
      final reprise = sessions.where((s) => s.statut != 'TERMINE').toList();
      if (reprise.isNotEmpty) {
        session = reprise.first;
      } else {
        session = SessionLive(
          id: '',
          subscriptionId: abonnement?.id ?? '',
          userId: utilisateur.id,
          roomId: _hex(8),
          inviteToken: _hex(12),
          titre: '',
          plateformes: const <String>['SALLE'],
          format: 'SOLO',
          modeVisuel: 'CAMERA',
          ficheProduit: const <String, dynamic>{},
          statut: 'BROUILLON',
          createdAt: DateTime.now(),
        );
      }

      final guide = acces.guideAutorise && abonnement != null
          ? await ApiService.monGuide(abonnement.id)
          : null;

      if (!mounted) return;
      setState(() {
        _acces = acces;
        _abonnement = abonnement;
        _session = session;
        _guide = guide;
        _plateformes = session.plateformes.isEmpty
            ? <String>{'SALLE'}
            : session.plateformes.toSet();
        _format = session.format;
        _mode = session.modeVisuel;
        _chargement = false;
      });
      _remplirFormulaire(session);
    } catch (erreur) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = erreur is ApiException ? erreur.message : 'Chargement impossible.';
      });
    }
  }

  void _remplirFormulaire(SessionLive session) {
    final fiche = session.ficheProduit;
    _titre.text = session.titre.isNotEmpty
        ? session.titre
        : (fiche['titre'] as String? ?? '');
    _produits.text = fiche['produits'] as String? ?? '';
    _lien.text = fiche['lien'] as String? ?? '';
    _arguments.text = fiche['arguments'] as String? ?? '';
  }

  Map<String, dynamic> _fiche() => <String, dynamic>{
        'titre': _titre.text.trim(),
        'produits': _produits.text.trim(),
        'lien': _lien.text.trim(),
        'arguments': _arguments.text.trim(),
      };

  Future<bool> _sauvegarder({bool lancer = false}) async {    final session = _session;
    if (session == null) return false;
    if (_titre.text.trim().isEmpty) {
      _toast('Donnez un titre à votre live.', couleur: K.danger);
      return false;
    }
    if (_plateformes.isEmpty) _plateformes = <String>{'SALLE'};

    setState(() => _sauvegarde = true);
    try {
      final miseAJour = session.copieAvec(
        titre: _titre.text.trim(),
        plateformes: _plateformes.toList(),
        format: _format,
        modeVisuel: _mode,
        ficheProduit: _fiche(),
        statut: lancer ? 'EN_DIRECT' : (session.statut == 'BROUILLON' ? 'PRET' : session.statut),
      );
      final enregistree = await ApiService.enregistrerSessionLive(miseAJour);
      if (!mounted) return false;
      setState(() {
        _session = enregistree;
        _sauvegarde = false;
        if (lancer) _onglet = 1;
      });
      if (!lancer) _toast('Votre live est prêt. Vous pouvez lancer la salle.', couleur: K.emeraude);
      return true;
    } catch (erreur) {
      if (!mounted) return false;
      setState(() => _sauvegarde = false);
      _toast(erreur is ApiException ? erreur.message : 'Enregistrement impossible.', couleur: K.danger);
      return false;
    }
  }

  Future<void> _lancer() async {
    final ok = await _sauvegarder(lancer: true);
    if (!ok) return;
    final statutOk = await ApiService.changerStatutSession(_session?.id ?? '', 'EN_DIRECT');
    if (!statutOk) {
      _toast(
        'Le direct est lancé, mais le statut n\'a pas pu être enregistré. Actualisez la page.',
        couleur: K.danger,
      );
    }
  }

  Future<void> _terminer() async {
    final session = _session;
    if (session == null) return;
    final ok = await ApiService.changerStatutSession(session.id, 'TERMINE');
    if (!mounted) return;
    if (!ok) {
      _toast('Impossible de terminer le live. Réessayez.', couleur: K.danger);
      return;
    }
    setState(() => _session = session.copieAvec(statut: 'TERMINE'));
    _toast('Live terminé.', couleur: K.emeraude);
  }

  Future<void> _demarrerEssaiDepuisRegie() async {
    try {
      await ApiService.demarrerEssai();
      await _charger();
    } catch (erreur) {
      _toast(
        erreur is ApiException ? erreur.message : 'Impossible de démarrer l\'essai.',
        couleur: K.danger,
      );
    }
  }

  Future<void> _genererGuide() async {    final abonnement = _abonnement;
    if (abonnement == null || _acces?.guideAutorise != true) return;
    setState(() => _guideEnCours = true);
    try {
      final guide = await ApiService.genererGuide(abonnement.id);
      if (!mounted) return;
      setState(() {
        _guide = guide;
        _guideEnCours = false;
      });
      _toast('Votre Livre Guide est prêt.', couleur: K.emeraude);
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _guideEnCours = false);
      _toast(erreur is ApiException ? erreur.message : 'Génération impossible.', couleur: K.danger);
    }
  }

  void _toast(String message, {Color couleur = K.or}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: couleur == K.or ? null : couleur),
    );
  }

  Future<void> _copier(String texte, String libelle) async {
    if (texte.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: texte));
    _toast('$libelle copié.');
  }

  Future<void> _telechargerGuide() async {
    final guide = _guide;
    if (guide == null) return;
    final ok = await telechargerTexte(
      nomFichier: 'livre-guide-live-ebooklive.html',
      contenu: guide.contenuHtml,
    );
    if (!ok) _copier(guide.contenuMarkdown.isNotEmpty ? guide.contenuMarkdown : guide.contenuHtml, 'Guide');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PatternBackground(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _BarreHaute(
                acces: _acces,
                onAccueil: () => Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false),
                onGuide: () {
                  setState(() => _onglet = 2);
                },
              ),
              const Divider(height: 1, color: K.border),
              Expanded(child: _corps()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _corps() {
    if (_chargement) {
      return const Center(child: CircularProgressIndicator(color: K.or));
    }
    if (_erreur == 'connectez-vous') {
      return _Porte(
        icone: Icons.lock_person_rounded,
        titre: 'Connectez-vous à votre régie',
        texte:
            'Votre Studio Live est lié à votre compte e-booklive. Utilisez l\'email '
            'renseigné lors de l\'abonnement pour retrouver votre régie et votre guide.',
        bouton: 'Se connecter / créer un compte',
        onPressed: () => Navigator.pushNamed(context, '/mon-espace'),
      );
    }
    if (_erreur != null) {
      return _Porte(
        icone: Icons.cloud_off_rounded,
        titre: 'Impossible de charger la régie',
        texte: _erreur!,
        bouton: 'Réessayer',
        onPressed: _charger,
      );
    }
    final acces = _acces;
    if (acces == null || !acces.aAcces) {
      if (acces?.abonnementEnAttente == true) {
        return _Porte(
          icone: Icons.hourglass_top_rounded,
          titre: 'Activation de votre Studio Live en cours',
          texte:
              'Votre paiement est en cours de confirmation. Dès qu\'il est validé, votre régie et votre Livre Guide s\'ouvrent automatiquement.',
          bouton: 'Actualiser',
          onPressed: _charger,
          secondaire: 'Voir l\'offre',
          onSecondaire: () => Navigator.pushNamed(context, '/studio-live'),
        );
      }
      if (acces?.essaiExpire == true) {
        return _Porte(
          icone: Icons.timer_off_rounded,
          titre: 'Votre essai est terminé',
          texte:
              'Votre essai gratuit de 3 jours est terminé. Abonnez-vous pour retrouver la régie, '
              'le chat IA et votre Livre Guide personnalisé. Aucun prélèvement automatique n\'a eu lieu.',
          bouton: 'S\'abonner maintenant : 10 USD / 30 jours',
          onPressed: () => Navigator.pushNamed(context, '/studio-live'),
          secondaire: 'Voir l\'offre Studio Live',
          onSecondaire: () => Navigator.pushNamed(context, '/studio-live'),
        );
      }
      return _Porte(
        icone: Icons.card_giftcard_rounded,
        titre: 'Démarrez votre Studio Live',
        texte:
            'Essayez gratuitement pendant 3 jours, sans carte : régie, co-animateur et chat IA '
            '(20 messages par jour). Le Livre Guide s\'ouvre avec l\'abonnement.',
        bouton: 'Essayer gratuitement 3 jours',
        onPressed: _demarrerEssaiDepuisRegie,
        secondaire: 'S\'abonner maintenant : 10 USD / 30 jours',
        onSecondaire: () => Navigator.pushNamed(context, '/studio-live'),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: <Widget>[
              _Onglets(
                actif: _onglet,
                onChanged: (index) => setState(() => _onglet = index),
                statut: _session?.statut,
              ),
              const SizedBox(height: 14),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  child: switch (_onglet) {
                    0 => _OngletPreparer(
                        key: const ValueKey<int>(0),
                        titre: _titre,
                        produits: _produits,
                        lien: _lien,
                        arguments: _arguments,
                        plateformes: _plateformes,
                        format: _format,
                        mode: _mode,
                        session: _session,
                        lienInvitation: _lienInvitation,
                        sauvegarde: _sauvegarde,
                        onPlateforme: (valeur) => setState(() {
                          if (_plateformes.contains(valeur)) {
                            if (_plateformes.length > 1) _plateformes.remove(valeur);
                          } else {
                            _plateformes.add(valeur);
                          }
                        }),
                        onFormat: (valeur) => setState(() => _format = valeur),
                        onMode: (valeur) => setState(() => _mode = valeur),
                        onSauvegarder: () => _sauvegarder(),
                        onLancer: _lancer,
                        onCopierInvitation: () => _copier(_lienInvitation, 'Lien d\'invitation'),
                      ),
                    1 => _OngletDirect(
                        key: const ValueKey<int>(1),
                        session: _session,
                        jitsi: _jitsi,
                        nomAnimateur: _nomAnimateur,
                        lienPublication: _lienPublication,
                        lienInvitation: _lienInvitation,
                        onCopier: _copier,
                        onTerminer: _terminer,
                        onPreparer: () => setState(() => _onglet = 0),
                      ),
                    _ => _acces?.guideAutorise == true && _abonnement != null
                        ? _OngletGuide(
                            key: const ValueKey<int>(2),
                            guide: _guide,
                            abonnement: _abonnement!,
                            enCours: _guideEnCours,
                            onGenerer: _genererGuide,
                            onCopier: () => _copier(
                              _guide?.contenuMarkdown.isNotEmpty == true
                                  ? _guide!.contenuMarkdown
                                  : _guide!.contenuHtml,
                              'Livre Guide',
                            ),
                            onTelecharger: _telechargerGuide,
                            onRafraichir: () async {
                              final guide = await ApiService.monGuide(_abonnement!.id);
                              if (!mounted) return;
                              setState(() => _guide = guide);
                            },
                          )
                        : _GuideVerrouille(
                            key: const ValueKey<int>(2),
                            estEssai: _acces?.estEssai == true,
                            onSouscrire: () =>
                                Navigator.pushNamed(context, '/studio-live'),
                          ),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  BARRE HAUTE
// ============================================================================
class _BarreHaute extends StatelessWidget {
  const _BarreHaute({
    required this.acces,
    required this.onAccueil,
    required this.onGuide,
  });

  final AccesStudio? acces;
  final VoidCallback onAccueil;
  final VoidCallback onGuide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onAccueil,
            child: const Padding(
              padding: EdgeInsets.all(3),
              child: LogoLockup(tailleLogo: 32, tailleTexte: 17),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: K.emeraude.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: K.emeraude.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.sensors_rounded, size: 12, color: K.emeraude),
                SizedBox(width: 5),
                Text(
                  'RÉGIE',
                  style: TextStyle(
                    color: K.emeraude,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (acces != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: K.surface.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: K.border),
              ),
              child: Text(
                acces!.estPaye
                    ? '${acces!.abonnement!.joursRestants} j restants'
                    : acces!.estEssai
                        ? '${acces!.essai!.joursRestants} j d\'essai'
                        : acces!.essaiExpire
                            ? 'Essai terminé'
                            : acces!.libelleAcces,
                style: TextStyle(
                  color: acces!.estPaye || acces!.estEssai
                      ? K.emeraude
                      : (acces!.essaiExpire ? K.danger : K.faint),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Mon livre guide',
            onPressed: onGuide,
            icon: const Icon(Icons.menu_book_rounded, color: K.muted, size: 20),
          ),
          IconButton(
            tooltip: 'Quitter la régie',
            onPressed: onAccueil,
            icon: const Icon(Icons.close_rounded, color: K.muted, size: 21),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  ONGLETS
// ============================================================================
class _Onglets extends StatelessWidget {
  const _Onglets({required this.actif, required this.onChanged, this.statut});

  final int actif;
  final ValueChanged<int> onChanged;
  final String? statut;

  @override
  Widget build(BuildContext context) {
    final direct = statut == 'EN_DIRECT';
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: K.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: K.border),
      ),
      child: Row(
        children: <Widget>[
          _OngletBouton(
            actif: actif == 0,
            icone: Icons.tune_rounded,
            label: 'Préparer mon Live',
            onTap: () => onChanged(0),
          ),
          _OngletBouton(
            actif: actif == 1,
            icone: direct ? Icons.circle : Icons.sensors_rounded,
            label: 'Salle en direct',
            couleur: direct ? K.danger : K.emeraude,
            onTap: () => onChanged(1),
          ),
          _OngletBouton(
            actif: actif == 2,
            icone: Icons.menu_book_rounded,
            label: 'Mon Livre Guide',
            onTap: () => onChanged(2),
          ),
        ],
      ),
    );
  }
}

class _OngletBouton extends StatelessWidget {
  const _OngletBouton({
    required this.actif,
    required this.icone,
    required this.label,
    required this.onTap,
    this.couleur,
  });

  final bool actif;
  final IconData icone;
  final String label;
  final VoidCallback onTap;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final teinte = couleur ?? (actif ? K.or : K.faint);
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: actif ? K.bg.withValues(alpha: 0.55) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: actif ? teinte.withValues(alpha: 0.3) : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icone, size: 15, color: actif ? teinte : K.faint),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: actif ? K.text : K.faint,
                      fontSize: 11.5,
                      fontWeight: actif ? FontWeight.w800 : FontWeight.w600,
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
}

// ============================================================================
//  ONGLET A — PRÉPARER MON LIVE
// ============================================================================
class _OngletPreparer extends StatelessWidget {
  const _OngletPreparer({
    super.key,
    required this.titre,
    required this.produits,
    required this.lien,
    required this.arguments,
    required this.plateformes,
    required this.format,
    required this.mode,
    required this.session,
    required this.lienInvitation,
    required this.sauvegarde,
    required this.onPlateforme,
    required this.onFormat,
    required this.onMode,
    required this.onSauvegarder,
    required this.onLancer,
    required this.onCopierInvitation,
  });

  final TextEditingController titre;
  final TextEditingController produits;
  final TextEditingController lien;
  final TextEditingController arguments;
  final Set<String> plateformes;
  final String format;
  final String mode;
  final SessionLive? session;
  final String lienInvitation;
  final bool sauvegarde;
  final ValueChanged<String> onPlateforme;
  final ValueChanged<String> onFormat;
  final ValueChanged<String> onMode;
  final VoidCallback onSauvegarder;
  final VoidCallback onLancer;
  final VoidCallback onCopierInvitation;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Préparer mon Live',
            style: TextStyle(
              color: K.text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Cochez librement vos choix. Tout est modifiable jusqu\'au lancement.',
            style: TextStyle(color: K.muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          _Section(
            numero: '01',
            titre: 'Plateformes',
            sousTitre: 'Où vos spectateurs vous retrouvent.',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final plateforme in _plateformes)
                  _ChipPlateforme(
                    code: plateforme.$1,
                    label: plateforme.$2,
                    icone: plateforme.$3,
                    actif: plateformes.contains(plateforme.$1),
                    onTap: () => onPlateforme(plateforme.$1),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, contraintes) {
              final large = contraintes.maxWidth > 760;
              final blocFormat = _Section(
                numero: '02',
                titre: 'Format',
                sousTitre: 'Seul ou avec un co-animateur.',
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _CarteChoix(
                        icone: Icons.person_rounded,
                        titre: 'Animer seul',
                        detail: 'Vous êtes la seule caméra.',
                        actif: format == 'SOLO',
                        onTap: () => onFormat('SOLO'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CarteChoix(
                        icone: Icons.group_rounded,
                        titre: 'Co-animateur',
                        detail: 'Lien unique, n\'importe où.',
                        actif: format == 'DUO',
                        onTap: () => onFormat('DUO'),
                      ),
                    ),
                  ],
                ),
              );
              final blocMode = _Section(
                numero: '03',
                titre: 'Mode visuel',
                sousTitre: 'Ce que la caméra montre.',
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _CarteChoix(
                        icone: Icons.checkroom_rounded,
                        titre: 'Caméra produits',
                        detail: 'Vêtements, articles physiques.',
                        actif: mode == 'CAMERA',
                        onTap: () => onMode('CAMERA'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CarteChoix(
                        icone: Icons.screen_share_rounded,
                        titre: 'Partage d\'écran',
                        detail: 'Formation, logiciel, document.',
                        actif: mode == 'ECRAN',
                        onTap: () => onMode('ECRAN'),
                      ),
                    ),
                  ],
                ),
              );
              if (large) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: blocFormat),
                    const SizedBox(width: 12),
                    Expanded(child: blocMode),
                  ],
                );
              }
              return Column(
                children: <Widget>[
                  blocFormat,
                  const SizedBox(height: 12),
                  blocMode,
                ],
              );
            },
          ),
          if (format == 'DUO') ...<Widget>[
            const SizedBox(height: 14),
            _Section(
              numero: '04',
              titre: 'Lien du co-animateur',
              sousTitre:
                  'Envoyez ce lien à votre partenaire. Il monte dans la salle depuis n\'importe où.',
              child: _LienCopiable(
                valeur: lienInvitation,
                onCopier: onCopierInvitation,
                avertissement:
                    'À garder privé : ce lien donne accès à votre salle de direct.',
              ),
            ),
          ],
          const SizedBox(height: 14),
          _Section(
            numero: format == 'DUO' ? '05' : '04',
            titre: 'Fiche Produit IA',
            sousTitre:
                'Le chat IA utilise ces informations pour répondre aux spectateurs en votre nom.',
            child: Column(
              children: <Widget>[
                TextField(
                  controller: titre,
                  maxLength: 120,
                  style: const TextStyle(color: K.text),
                  decoration: champ(
                    label: 'Titre de votre live',
                    hint: 'Ex : Nouvelle collection wax — ventes privées',
                    icone: Icons.title_rounded,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: produits,
                  maxLines: 3,
                  maxLength: 1200,
                  style: const TextStyle(color: K.text),
                  decoration: champ(
                    label: 'Produits et prix',
                    hint: 'Ex : Robe wax 9 000 FCFA · Ensemble 15 000 FCFA · Livraison offerte',
                    icone: Icons.shopping_bag_rounded,
                    multiligne: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: lien,
                  maxLength: 300,
                  style: const TextStyle(color: K.text),
                  decoration: champ(
                    label: 'Lien de commande ou WhatsApp',
                    hint: 'https://wa.me/… ou votre lien de boutique',
                    icone: Icons.link_rounded,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: arguments,
                  maxLines: 3,
                  maxLength: 1200,
                  style: const TextStyle(color: K.text),
                  decoration: champ(
                    label: 'Arguments clés',
                    hint: 'Matière, taille, délai de livraison, garantie, offre du jour…',
                    icone: Icons.auto_awesome_rounded,
                    multiligne: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: OrButton(
                  label: 'Enregistrer',
                  icone: Icons.save_rounded,
                  plein: false,
                  chargement: sauvegarde,
                  onPressed: sauvegarde ? null : onSauvegarder,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: OrButton(
                  label: 'Lancer le direct',
                  icone: Icons.sensors_rounded,
                  chargement: sauvegarde,
                  onPressed: sauvegarde ? null : onLancer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              const Icon(Icons.info_outline_rounded, color: K.faint, size: 13),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  session?.statut == 'EN_DIRECT'
                      ? 'Cette session est déjà en direct. Terminez-la avant de relancer.'
                      : 'Vous pourrez revenir ici à tout moment : la fiche produit reste enregistrée.',
                  style: const TextStyle(color: K.faint, fontSize: 10, height: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static const List<(String, String, IconData)> _plateformes = <(String, String, IconData)>[
    ('SALLE', 'Salle e-booklive', Icons.computer_rounded),
    ('TIKTOK', 'TikTok Live', Icons.music_note_rounded),
    ('YOUTUBE', 'YouTube Live', Icons.play_circle_fill_rounded),
    ('INSTAGRAM', 'Instagram Live', Icons.camera_alt_rounded),
  ];
}

// ============================================================================
//  ONGLET B — SALLE EN DIRECT & CHAT IA
// ============================================================================
class _OngletDirect extends StatelessWidget {
  const _OngletDirect({
    super.key,
    required this.session,
    required this.jitsi,
    required this.nomAnimateur,
    required this.lienPublication,
    required this.lienInvitation,
    required this.onCopier,
    required this.onTerminer,
    required this.onPreparer,
  });

  final SessionLive? session;
  final JitsiController jitsi;
  final String nomAnimateur;
  final String lienPublication;
  final String lienInvitation;
  final Future<void> Function(String, String) onCopier;
  final Future<void> Function() onTerminer;
  final VoidCallback onPreparer;

  @override
  Widget build(BuildContext context) {
    final live = session;
    if (live == null || live.id.isEmpty) {
      return _Porte(
        icone: Icons.tune_rounded,
        titre: 'Préparez votre live d\'abord',
        texte: 'Enregistrez votre fiche produit et vos options dans l\'onglet '
            '« Préparer mon Live » pour ouvrir la salle.',
        bouton: 'Préparer mon Live',
        onPressed: onPreparer,
      );
    }

    return LayoutBuilder(
      builder: (context, contraintes) {
        final large = contraintes.maxWidth > 1000;
        final video = _ZoneVideo(
          session: live,
          jitsi: jitsi,
          nomAnimateur: nomAnimateur,
          lienPublication: lienPublication,
          lienInvitation: lienInvitation,
          onCopier: onCopier,
          onTerminer: onTerminer,
        );
        final chat = ChatLivePanel(
          roomId: live.roomId,
          statut: live.statut,
          nomAnimateur: nomAnimateur,
        );

        if (large) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: video),
              const SizedBox(width: 12),
              SizedBox(width: 370, child: chat),
            ],
          );
        }

        return Column(
          children: <Widget>[
            SizedBox(height: 260, child: video),
            const SizedBox(height: 10),
            Expanded(child: chat),
          ],
        );
      },
    );
  }
}

class _ZoneVideo extends StatelessWidget {
  const _ZoneVideo({
    required this.session,
    required this.jitsi,
    required this.nomAnimateur,
    required this.lienPublication,
    required this.lienInvitation,
    required this.onCopier,
    required this.onTerminer,
  });

  final SessionLive session;
  final JitsiController jitsi;
  final String nomAnimateur;
  final String lienPublication;
  final String lienInvitation;
  final Future<void> Function(String, String) onCopier;
  final Future<void> Function() onTerminer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: K.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: K.border),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 10, 9),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (session.statut == 'EN_DIRECT' ? K.danger : K.or)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (session.statut == 'EN_DIRECT' ? K.danger : K.or)
                          .withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.circle,
                        size: 6,
                        color: session.statut == 'EN_DIRECT' ? K.danger : K.or,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        session.statut == 'EN_DIRECT' ? 'EN DIRECT' : 'PRÊT',
                        style: TextStyle(
                          color: session.statut == 'EN_DIRECT' ? K.danger : K.or,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    session.titre.isEmpty ? 'Mon live' : session.titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: K.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copier le lien spectateur',
                  onPressed: () => onCopier(lienPublication, 'Lien spectateur'),
                  icon: const Icon(Icons.link_rounded, color: K.muted, size: 18),
                ),
                if (session.estDuo)
                  IconButton(
                    tooltip: 'Copier le lien co-animateur',
                    onPressed: () => onCopier(lienInvitation, 'Lien co-animateur'),
                    icon: const Icon(Icons.group_add_rounded, color: K.emeraude, size: 18),
                  ),
                TextButton(
                  onPressed: onTerminer,
                  child: const Text('Terminer', style: TextStyle(color: K.danger, fontSize: 11)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: K.border),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: construireJitsi(
                roomId: session.roomId,
                nomAffiche: nomAnimateur,
                controleur: jitsi,
                moderateur: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Row(
              children: <Widget>[
                _BoutonLive(
                  icone: Icons.mic_rounded,
                  label: 'Micro',
                  onTap: jitsi.basculerMicro,
                ),
                const SizedBox(width: 7),
                _BoutonLive(
                  icone: Icons.videocam_rounded,
                  label: 'Caméra',
                  onTap: jitsi.basculerCamera,
                ),
                const SizedBox(width: 7),
                _BoutonLive(
                  icone: Icons.screen_share_rounded,
                  label: 'Partage d\'écran',
                  onTap: jitsi.partagerEcran,
                  actif: session.partageEcran,
                ),
                const Spacer(),
                _BoutonLive(
                  icone: Icons.call_end_rounded,
                  label: 'Quitter',
                  couleur: K.danger,
                  onTap: jitsi.quitter,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BoutonLive extends StatelessWidget {
  const _BoutonLive({
    required this.icone,
    required this.label,
    required this.onTap,
    this.actif = false,
    this.couleur,
  });

  final IconData icone;
  final String label;
  final Future<void> Function() onTap;
  final bool actif;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final teinte = couleur ?? (actif ? K.emeraude : K.muted);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: (actif ? K.emeraude : K.bg).withValues(alpha: actif ? 0.14 : 0.45),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: actif ? K.emeraude.withValues(alpha: 0.4) : K.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icone, size: 15, color: teinte),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: teinte, fontSize: 10.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  CHAT LIVE IA
// ============================================================================
class ChatLivePanel extends StatefulWidget {
  const ChatLivePanel({
    super.key,
    required this.roomId,
    required this.statut,
    required this.nomAnimateur,
  });

  final String roomId;
  final String statut;
  final String nomAnimateur;

  @override
  State<ChatLivePanel> createState() => _ChatLiveState();
}

class _ChatLiveState extends State<ChatLivePanel> {
  final TextEditingController _saisie = TextEditingController();
  final ScrollController _defilement = ScrollController();
  StreamSubscription<List<Map<String, dynamic>>>? _flux;
  Timer? _secours;
  List<MessageLive> _messages = const <MessageLive>[];
  String _plateforme = 'SALLE';
  bool _chargement = true;
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  Future<void> _initialiser() async {
    await _charger();
    try {
      _flux = Supabase.instance.client
          .from('studio_live_messages')
          .stream(primaryKey: <String>['id'])
          .eq('room_id', widget.roomId)
          .order('created_at', ascending: true)
          .listen(
        (lignes) {
          if (!mounted) return;
          setState(() {
            _messages = lignes
                .map((ligne) => MessageLive.fromJson(Map<String, dynamic>.from(ligne)))
                .toList();
            _chargement = false;
          });
          _defiler();
        },
        onError: (_) {
          _demarrerSecours();
        },
      );
    } catch (_) {
      _demarrerSecours();
    }
  }

  void _demarrerSecours() {
    _secours ??= Timer.periodic(const Duration(seconds: 6), (_) => _charger());
  }

  Future<void> _charger() async {
    final messages = await ApiService.messagesLive(widget.roomId);
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _chargement = false;
    });
    _defiler();
  }

  @override
  void dispose() {
    _flux?.cancel();
    _secours?.cancel();
    _saisie.dispose();
    _defilement.dispose();
    super.dispose();
  }

  void _defiler() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_defilement.hasClients) return;
      _defilement.animateTo(
        _defilement.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _envoyer() async {
    final texte = _saisie.text.trim();
    if (texte.isEmpty || _envoi) return;
    setState(() => _envoi = true);
    _saisie.clear();
    try {
      await ApiService.chatLive(
        roomId: widget.roomId,
        message: texte,
        author: widget.nomAnimateur,
        platform: _plateforme,
      );
      await _charger();
    } catch (erreur) {
      if (mounted) {
        setState(() => _envoi = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              erreur is ApiException
                  ? erreur.message
                  : 'Le chat IA est momentanément indisponible.',
            ),
          ),
        );
      }
      return;
    }
    if (mounted) setState(() => _envoi = false);
  }

  Future<void> _copier(MessageLive message) async {
    await Clipboard.setData(ClipboardData(text: message.content));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Réponse copiée : collez-la sur TikTok ou Instagram.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: K.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: K.border),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 11, 10, 9),
            child: Row(
              children: <Widget>[
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: K.marque,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: K.bg, size: 16),
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Chat Live IA',
                        style: TextStyle(
                          color: K.text,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'DeepSeek · répond avec votre fiche produit',
                        style: TextStyle(color: K.faint, fontSize: 8.5),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(color: K.emeraude, shape: BoxShape.circle),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: K.border),
          Expanded(
            child: _chargement
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: K.or, strokeWidth: 2),
                    ),
                  )
                : _messages.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Text(
                            'Posez une question ou saisissez une question TikTok/Instagram : l\'IA répond et vous pouvez copier la réponse en 1 clic.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: K.faint, fontSize: 10, height: 1.5),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _defilement,
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return _BulletinChat(
                            message: message,
                            onCopier: () => _copier(message),
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _PlateformeChip(
                      actif: _plateforme == 'SALLE',
                      label: 'Salle',
                      onTap: () => setState(() => _plateforme = 'SALLE'),
                    ),
                    const SizedBox(width: 5),
                    _PlateformeChip(
                      actif: _plateforme == 'TIKTOK',
                      label: 'TikTok',
                      onTap: () => setState(() => _plateforme = 'TIKTOK'),
                    ),
                    const SizedBox(width: 5),
                    _PlateformeChip(
                      actif: _plateforme == 'INSTAGRAM',
                      label: 'Instagram',
                      onTap: () => setState(() => _plateforme = 'INSTAGRAM'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _saisie,
                        style: const TextStyle(color: K.text, fontSize: 12),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _envoyer(),
                        decoration: InputDecoration(
                          hintText: 'Question spectateur…',
                          hintStyle: const TextStyle(color: K.faint, fontSize: 11.5),
                          filled: true,
                          fillColor: K.bg.withValues(alpha: 0.5),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(11),
                            borderSide: const BorderSide(color: K.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(11),
                            borderSide: const BorderSide(color: K.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(11),
                            borderSide: const BorderSide(color: K.or, width: 1.2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _envoi ? null : _envoyer,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(gradient: K.orGradient, shape: BoxShape.circle),
                            child: Icon(Icons.arrow_upward_rounded, color: K.bg, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlateformeChip extends StatelessWidget {
  const _PlateformeChip({required this.actif, required this.label, required this.onTap});

  final bool actif;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: actif ? K.or.withValues(alpha: 0.13) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: actif ? K.or.withValues(alpha: 0.4) : K.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: actif ? K.or : K.faint,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _BulletinChat extends StatelessWidget {
  const _BulletinChat({required this.message, required this.onCopier});

  final MessageLive message;
  final VoidCallback onCopier;

  @override
  Widget build(BuildContext context) {
    final assistant = message.estAssistant;
    return Align(
      alignment: assistant ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        decoration: BoxDecoration(
          color: assistant ? K.emeraude.withValues(alpha: 0.07) : K.or.withValues(alpha: 0.08),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(11),
            topRight: const Radius.circular(11),
            bottomLeft: Radius.circular(assistant ? 3 : 11),
            bottomRight: Radius.circular(assistant ? 11 : 3),
          ),
          border: Border.all(
            color: assistant ? K.emeraude.withValues(alpha: 0.22) : K.or.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (assistant)
                  const Icon(Icons.auto_awesome_rounded, size: 10, color: K.emeraude)
                else
                  Icon(
                    message.platform == 'TIKTOK'
                        ? Icons.music_note_rounded
                        : message.platform == 'INSTAGRAM'
                            ? Icons.camera_alt_rounded
                            : Icons.person_rounded,
                    size: 10,
                    color: K.or,
                  ),
                const SizedBox(width: 4),
                Text(
                  assistant ? 'Awa IA' : (message.author.isEmpty ? 'Spectateur' : message.author),
                  style: TextStyle(
                    color: assistant ? K.emeraude : K.or,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!assistant && message.platform != 'SALLE') ...<Widget>[
                  const SizedBox(width: 4),
                  Text(
                    message.platform,
                    style: const TextStyle(color: K.faint, fontSize: 6.5),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 3),
            Text(
              message.content,
              style: const TextStyle(color: K.text, fontSize: 10.5, height: 1.45),
            ),
            if (assistant) ...<Widget>[
              const SizedBox(height: 4),
              InkWell(
                onTap: onCopier,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.copy_rounded, size: 10, color: K.emeraude),
                    SizedBox(width: 4),
                    Text(
                      'Copier en 1 clic',
                      style: TextStyle(color: K.emeraude, fontSize: 7.5),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
//  ONGLET C — MON LIVRE GUIDE LIVE
// ============================================================================
class _GuideVerrouille extends StatelessWidget {
  const _GuideVerrouille({
    super.key,
    required this.estEssai,
    required this.onSouscrire,
  });

  final bool estEssai;
  final VoidCallback onSouscrire;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: GlassCard(
            miseEnAvant: true,
            padding: const EdgeInsets.all(28),
            child: Column(
              children: <Widget>[
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: K.or.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: K.or.withValues(alpha: 0.25)),
                  ),
                  child: const Icon(Icons.lock_outline_rounded, color: K.or, size: 26),
                ),
                const SizedBox(height: 16),
                Text(
                  estEssai
                      ? 'Le Livre Guide s\'ouvre avec l\'abonnement'
                      : 'Le Livre Guide est réservé aux abonnés',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: K.text,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  estEssai
                      ? 'Votre essai gratuit inclut la régie, le co-animateur et le chat IA '
                          '(20 messages par jour). Le Livre Guide personnalisé est généré '
                          'dès votre passage à l\'abonnement payant.'
                      : 'Le Livre Guide personnalisé est inclus dans l\'abonnement Studio Live, '
                          'généré pour votre métier et envoyé par email.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: K.muted, fontSize: 12, height: 1.65),
                ),
                const SizedBox(height: 20),
                OrButton(
                  label: 'S\'abonner maintenant : 10 USD / 30 jours',
                  icone: Icons.workspace_premium_rounded,
                  onPressed: onSouscrire,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OngletGuide extends StatelessWidget {
  const _OngletGuide({
    super.key,
    required this.guide,
    required this.abonnement,
    required this.enCours,
    required this.onGenerer,
    required this.onCopier,
    required this.onTelecharger,
    required this.onRafraichir,
  });

  final GuideLive? guide;
  final AbonnementStudio abonnement;
  final bool enCours;
  final VoidCallback onGenerer;
  final VoidCallback onCopier;
  final VoidCallback onTelecharger;
  final Future<void> Function() onRafraichir;

  @override
  Widget build(BuildContext context) {
    final pret = guide?.estPret == true;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Mon Livre Guide Live',
                      style: TextStyle(
                        color: K.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Écrit pour votre métier, votre pays et votre offre. Offert avec l\'abonnement.',
                      style: TextStyle(color: K.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (pret) ...<Widget>[
                IconButton(
                  tooltip: 'Copier',
                  onPressed: onCopier,
                  icon: const Icon(Icons.copy_rounded, color: K.muted, size: 19),
                ),
                IconButton(
                  tooltip: 'Télécharger',
                  onPressed: onTelecharger,
                  icon: const Icon(Icons.download_rounded, color: K.or, size: 20),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          if (enCours)
            _EtatGuide(
              icone: Icons.auto_awesome_rounded,
              titre: 'Rédaction en cours…',
              texte:
                  'L\'IA rédige votre guide personnalisé (script d\'accroche, structure du live, '
                  'conseils caméra, techniques de vente). Cela prend quelques secondes.',
              chargement: true,
              onPressed: null,
              bouton: '',
            )
          else if (!pret)
            _EtatGuide(
              icone: Icons.menu_book_rounded,
              titre: 'Votre guide est en préparation',
              texte:
                  'Dès la validation de votre paiement, votre Livre Guide est généré et envoyé '
                  'par email. S\'il n\'apparaît pas encore, lancez la génération ci-dessous.',
              chargement: false,
              onPressed: onGenerer,
              bouton: 'Générer mon Livre Guide',
              secondaire: onRafraichir,
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.check_circle_rounded, color: K.emeraude, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      'Guide prêt · ${_date(guide!.createdAt)}',
                      style: const TextStyle(color: K.emeraude, fontSize: 10.5),
                    ),
                    const Spacer(),
                    Text(
                      abonnement.metierLabel,
                      style: const TextStyle(color: K.faint, fontSize: 9.5),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GlassCard(
                  padding: const EdgeInsets.all(22),
                  child: HtmlWidget(
                    guide!.contenuHtml,
                    textStyle: const TextStyle(color: K.text, fontSize: 12.5, height: 1.65),
                    onTapUrl: (_) async => true,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ce guide est aussi envoyé par email à ${abonnement.email}. Conservez-le : '
                  'il reste accessible pendant toute la durée de votre abonnement.',
                  style: const TextStyle(color: K.faint, fontSize: 9.5, height: 1.5),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _date(DateTime date) {
    final jour = date.day.toString().padLeft(2, '0');
    final mois = date.month.toString().padLeft(2, '0');
    return '$jour/$mois/${date.year}';
  }
}

class _EtatGuide extends StatelessWidget {
  const _EtatGuide({
    required this.icone,
    required this.titre,
    required this.texte,
    required this.chargement,
    required this.onPressed,
    required this.bouton,
    this.secondaire,
  });

  final IconData icone;
  final String titre;
  final String texte;
  final bool chargement;
  final VoidCallback? onPressed;
  final String bouton;
  final Future<void> Function()? secondaire;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      miseEnAvant: true,
      padding: const EdgeInsets.all(26),
      child: Column(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: K.or.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: K.or.withValues(alpha: 0.25)),
            ),
            child: Icon(icone, color: K.or, size: 24),
          ),
          const SizedBox(height: 14),
          Text(
            titre,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: K.text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            texte,
            textAlign: TextAlign.center,
            style: const TextStyle(color: K.muted, fontSize: 11.5, height: 1.6),
          ),
          const SizedBox(height: 18),
          if (chargement)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(color: K.or, strokeWidth: 2.4),
            )
          else ...<Widget>[
            SizedBox(
              width: 280,
              child: OrButton(
                label: bouton,
                icone: Icons.auto_awesome_rounded,
                onPressed: onPressed,
              ),
            ),
            if (secondaire != null) ...<Widget>[
              const SizedBox(height: 6),
              TextButton(
                onPressed: secondaire,
                child: const Text(
                  'Actualiser le statut',
                  style: TextStyle(color: K.muted, fontSize: 11),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ============================================================================
//  COMPOSANTS COMMUNS
// ============================================================================
class _Section extends StatelessWidget {
  const _Section({
    required this.numero,
    required this.titre,
    required this.sousTitre,
    required this.child,
  });

  final String numero;
  final String titre;
  final String sousTitre;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: K.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: K.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                numero,
                style: const TextStyle(
                  color: K.or,
                  fontSize: 10,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                titre,
                style: const TextStyle(
                  color: K.text,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Text(
              sousTitre,
              style: const TextStyle(color: K.faint, fontSize: 9.5, height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ChipPlateforme extends StatelessWidget {
  const _ChipPlateforme({
    required this.code,
    required this.label,
    required this.icone,
    required this.actif,
    required this.onTap,
  });

  final String code;
  final String label;
  final IconData icone;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: actif ? K.or.withValues(alpha: 0.12) : K.bg.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: actif ? K.or.withValues(alpha: 0.55) : K.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icone, size: 15, color: actif ? K.or : K.faint),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: actif ? K.text : K.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (actif) ...<Widget>[
                const SizedBox(width: 6),
                const Icon(Icons.check_rounded, size: 13, color: K.or),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CarteChoix extends StatelessWidget {
  const _CarteChoix({
    required this.icone,
    required this.titre,
    required this.detail,
    required this.actif,
    required this.onTap,
  });

  final IconData icone;
  final String titre;
  final String detail;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: actif ? K.or.withValues(alpha: 0.09) : K.bg.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: actif ? K.or.withValues(alpha: 0.5) : K.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icone, size: 17, color: actif ? K.or : K.muted),
                  const Spacer(),
                  Icon(
                    actif ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 14,
                    color: actif ? K.or : K.borderLight,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                titre,
                style: const TextStyle(
                  color: K.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: const TextStyle(color: K.faint, fontSize: 8.5, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LienCopiable extends StatelessWidget {
  const _LienCopiable({
    required this.valeur,
    required this.onCopier,
    this.avertissement,
  });

  final String valeur;
  final VoidCallback onCopier;
  final String? avertissement;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: K.bg.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: K.border),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.link_rounded, color: K.emeraude, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  valeur,
                  maxLines: 2,
                  style: const TextStyle(color: K.text, fontSize: 10.5, height: 1.4),
                ),
              ),
              IconButton(
                tooltip: 'Copier',
                onPressed: onCopier,
                icon: const Icon(Icons.copy_rounded, color: K.muted, size: 17),
              ),
            ],
          ),
        ),
        if (avertissement != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            avertissement!,
            style: const TextStyle(color: K.faint, fontSize: 9, height: 1.4),
          ),
        ],
      ],
    );
  }
}

class _Porte extends StatelessWidget {
  const _Porte({
    required this.icone,
    required this.titre,
    required this.texte,
    required this.bouton,
    required this.onPressed,
    this.secondaire,
    this.onSecondaire,
  });

  final IconData icone;
  final String titre;
  final String texte;
  final String bouton;
  final VoidCallback onPressed;
  final String? secondaire;
  final VoidCallback? onSecondaire;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: GlassCard(
            miseEnAvant: true,
            padding: const EdgeInsets.all(28),
            child: Column(
              children: <Widget>[
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: K.or.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: K.or.withValues(alpha: 0.25)),
                  ),
                  child: Icon(icone, color: K.or, size: 26),
                ),
                const SizedBox(height: 16),
                Text(
                  titre,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: K.text,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  texte,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: K.muted, fontSize: 12, height: 1.6),
                ),
                const SizedBox(height: 20),
                OrButton(label: bouton, icone: Icons.arrow_forward_rounded, onPressed: onPressed),
                if (secondaire != null && onSecondaire != null) ...<Widget>[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: onSecondaire,
                    child: Text(
                      secondaire!,
                      style: const TextStyle(color: K.muted, fontSize: 11.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
