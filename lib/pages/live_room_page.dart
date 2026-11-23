import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../services/api.dart';
import '../services/jitsi_view.dart';
import '../widgets/logo_ebooklive.dart';
import '../widgets/whatsapp.dart';
import 'studio_regie_page.dart' show ChatLivePanel;

/// ============================================================================
///  SALLE LIVE PUBLIQUE — `/live/:roomId?invite=token`
///  • Sans token : lien spectateur (chat + vidéo).
///  • Avec token : lien unique de co-animateur, où qu'il soit dans le monde.
/// ============================================================================
class LiveRoomPage extends StatefulWidget {
  const LiveRoomPage({super.key, required this.roomId, this.inviteToken});

  final String roomId;
  final String? inviteToken;

  @override
  State<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _LiveRoomPageState extends State<LiveRoomPage> {
  final TextEditingController _nom = TextEditingController();
  final JitsiController _jitsi = const JitsiController();

  SessionLive? _session;
  bool _chargement = true;
  bool _rejoint = false;

  bool get _estInvite => widget.inviteToken != null && widget.inviteToken!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _nom.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    final session = await ApiService.sessionPublique(
      widget.roomId,
      inviteToken: widget.inviteToken,
    );
    if (!mounted) return;
    setState(() {
      _session = session;
      _chargement = false;
    });
  }

  void _rejoindre() {
    final nom = _nom.text.trim();
    setState(() {
      _rejoint = true;
      if (nom.isNotEmpty) _nom.text = nom;
    });
  }

  Future<void> _copierLien() async {
    final lien =
        '${AppConfig.siteUrl.replaceAll(RegExp(r'/+$'), '')}/live/${widget.roomId}';
    await Clipboard.setData(ClipboardData(text: lien));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lien spectateur copié.')),
    );
  }

  void _quitter() {
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PatternBackground(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _enTete(),
              const Divider(height: 1, color: K.border),
              Expanded(child: _corps()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _enTete() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: <Widget>[
          const LogoLockup(tailleLogo: 30, tailleTexte: 16),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: K.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: K.danger.withValues(alpha: 0.3)),
            ),
            child: const Text(
              'SALLE LIVE',
              style: TextStyle(
                color: K.danger,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Copier le lien spectateur',
            onPressed: _copierLien,
            icon: const Icon(Icons.share_rounded, color: K.muted, size: 19),
          ),
          IconButton(
            tooltip: 'Quitter',
            onPressed: _quitter,
            icon: const Icon(Icons.close_rounded, color: K.muted, size: 21),
          ),
        ],
      ),
    );
  }

  Widget _corps() {
    if (_chargement) {
      return const Center(child: CircularProgressIndicator(color: K.or));
    }
    final session = _session;
    if (session == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: GlassCard(
              padding: const EdgeInsets.all(26),
              child: Column(
                children: <Widget>[
                  const Icon(Icons.link_off_rounded, color: K.faint, size: 34),
                  const SizedBox(height: 14),
                  const Text(
                    'Cette salle n\'est pas accessible',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: K.text,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Le lien a peut-être expiré, ou le live n\'a pas encore commencé. '
                    'Demandez un nouveau lien à l\'animateur.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: K.muted, fontSize: 12, height: 1.6),
                  ),
                  const SizedBox(height: 18),
                  OrButton(
                    label: 'Retour à l\'accueil',
                    plein: false,
                    onPressed: _quitter,
                  ),
                  const SizedBox(height: 10),
                  const AideWhatsApp(pleinLargeur: true),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_rejoint) {
      return _Lobby(
        session: session,
        estInvite: _estInvite,
        nom: _nom,
        onRejoindre: _rejoindre,
      );
    }

    return LayoutBuilder(
      builder: (context, contraintes) {
        final large = contraintes.maxWidth > 980;
        final video = _VideoInvite(
          session: session,
          jitsi: _jitsi,
          nom: _nom.text.trim().isEmpty ? 'Invité e-booklive' : _nom.text.trim(),
          onQuitter: _quitter,
        );
        final chat = ChatLivePanel(
          roomId: session.roomId,
          statut: session.statut,
          nomAnimateur: _nom.text.trim().isEmpty ? 'Spectateur' : _nom.text.trim(),
        );

        if (large) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: video),
                const SizedBox(width: 12),
                SizedBox(width: 360, child: chat),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: <Widget>[
              SizedBox(height: 250, child: video),
              const SizedBox(height: 10),
              Expanded(child: chat),
            ],
          ),
        );
      },
    );
  }
}

class _Lobby extends StatelessWidget {
  const _Lobby({
    required this.session,
    required this.estInvite,
    required this.nom,
    required this.onRejoindre,
  });

  final SessionLive session;
  final bool estInvite;
  final TextEditingController nom;
  final VoidCallback onRejoindre;

  @override
  Widget build(BuildContext context) {
    final fiche = session.ficheProduit;
    final titre = session.titre.isNotEmpty ? session.titre : (fiche['titre'] as String? ?? '');

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: GlassCard(
            miseEnAvant: true,
            padding: const EdgeInsets.all(26),
            child: Column(
              children: <Widget>[
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: estInvite ? K.marque : K.direct,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    estInvite ? Icons.group_add_rounded : Icons.sensors_rounded,
                    color: K.bg,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  estInvite ? 'Vous êtes invité à co-animer' : 'Rejoindre le live',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: K.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  estInvite
                      ? 'Vous allez monter dans la salle de l\'animateur, où que vous soyez. '
                          'Autorisez la caméra et le micro pour apparaître à l\'écran.'
                      : 'Le live est en cours. Entrez votre nom pour participer au chat et '
                          'suivre la diffusion.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: K.muted, fontSize: 12, height: 1.6),
                ),
                const SizedBox(height: 16),
                if (titre.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: K.bg.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: K.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          titre,
                          style: const TextStyle(
                            color: K.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${session.libelleFormat} · ${session.libelleMode}',
                          style: const TextStyle(color: K.faint, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                TextField(
                  controller: nom,
                  maxLength: 40,
                  style: const TextStyle(color: K.text),
                  decoration: champ(
                    label: 'Votre nom',
                    hint: estInvite ? 'Ex : Mariam, co-animatrice' : 'Ex : Awa',
                    icone: Icons.person_rounded,
                  ),
                ),
                const SizedBox(height: 8),
                OrButton(
                  label: estInvite ? 'Monter dans la salle' : 'Rejoindre le live',
                  icone: Icons.video_call_rounded,
                  onPressed: onRejoindre,
                ),
                const SizedBox(height: 10),
                const Text(
                  'En rejoignant, vous acceptez que votre caméra et votre micro soient '
                  'visibles par les autres participants. Vous pouvez les couper à tout moment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: K.faint, fontSize: 9, height: 1.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoInvite extends StatelessWidget {
  const _VideoInvite({
    required this.session,
    required this.jitsi,
    required this.nom,
    required this.onQuitter,
  });

  final SessionLive session;
  final JitsiController jitsi;
  final String nom;
  final VoidCallback onQuitter;

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
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 9),
            child: Row(
              children: <Widget>[
                const Icon(Icons.circle, size: 7, color: K.danger),
                const SizedBox(width: 6),
                const Text(
                  'EN DIRECT',
                  style: TextStyle(
                    color: K.danger,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    session.titre.isEmpty ? 'Live e-booklive' : session.titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: K.text,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onQuitter,
                  child: const Text('Quitter', style: TextStyle(color: K.muted, fontSize: 10.5)),
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
                nomAffiche: nom,
                controleur: jitsi,
                moderateur: false,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Row(
              children: <Widget>[
                _BoutonInvite(icone: Icons.mic_rounded, label: 'Micro', onTap: jitsi.basculerMicro),
                const SizedBox(width: 7),
                _BoutonInvite(icone: Icons.videocam_rounded, label: 'Caméra', onTap: jitsi.basculerCamera),
                const SizedBox(width: 7),
                _BoutonInvite(
                  icone: Icons.screen_share_rounded,
                  label: 'Écran',
                  onTap: jitsi.partagerEcran,
                ),
                const Spacer(),
                _BoutonInvite(
                  icone: Icons.call_end_rounded,
                  label: 'Quitter',
                  couleur: K.danger,
                  onTap: () async => onQuitter(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BoutonInvite extends StatelessWidget {
  const _BoutonInvite({
    required this.icone,
    required this.label,
    required this.onTap,
    this.couleur,
  });

  final IconData icone;
  final String label;
  final Future<void> Function() onTap;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final teinte = couleur ?? K.muted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: K.bg.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: K.border),
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
