import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../core/links.dart';
import '../core/theme.dart';
import '../services/api.dart';
import 'country_picker.dart';
import 'logo_ebooklive.dart';
import 'whatsapp.dart';

/// ============================================================================
///  BARRE DE NAVIGATION MINIMALISTE
///  Logo e-booklive · 3 accès (La Boutique, Studio Live, Guide & Tutoriel) ·
///  Aide WhatsApp discrète · menu Compte.
///  ⚠️ /admin-videos n'apparaît que si l'utilisateur est réellement admin.
/// ============================================================================
class AppHeader extends StatefulWidget {
  const AppHeader({super.key, this.afficherAide = true});

  final bool afficherAide;

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> {
  bool _admin = false;
  bool _connecte = false;
  bool _verificationAdmin = false;
  StreamSubscription<AuthState>? _abonnementAuth;

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  @override
  void dispose() {
    _abonnementAuth?.cancel();
    super.dispose();
  }

  void _initialiser() {
    try {
      final client = Supabase.instance.client;
      _connecte = client.auth.currentUser != null;
      _abonnementAuth = client.auth.onAuthStateChange.listen((_) {
        if (!mounted) return;
        setState(() => _connecte = client.auth.currentUser != null);
        _verifierAdmin();
      });
      _verifierAdmin();
    } catch (_) {
      // Supabase indisponible : la navigation publique reste utilisable.
    }
  }

  Future<void> _verifierAdmin() async {
    if (_verificationAdmin) return;
    _verificationAdmin = true;
    try {
      final admin = await ApiService.estAdmin();
      if (!mounted) return;
      setState(() => _admin = admin);
    } catch (_) {
      if (!mounted) return;
      setState(() => _admin = false);
    } finally {
      _verificationAdmin = false;
    }
  }

  void _aller(String route) {
    final actuel = ModalRoute.of(context)?.settings.name;
    if (actuel == route) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      route,
      (r) => r.isFirst,
    );
  }

  void _accueil() {
    Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
  }

  Future<void> _deconnexion() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vous êtes déconnecté.')),
    );
    setState(() {
      _connecte = false;
      _admin = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
          child: LayoutBuilder(
            builder: (context, contraintes) {
              final large = contraintes.maxWidth >= 900;
              final moyen = contraintes.maxWidth >= 700;

              return Row(
                children: <Widget>[
                  Flexible(child: _LogoBouton(onTap: _accueil)),
                  const Spacer(),
                  if (large)
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Flexible(
                            child: _LienNav(
                              label: 'La Boutique',
                              route: '/boutique',
                              onTap: () => _aller('/boutique'),
                            ),
                          ),
                          Flexible(
                            child: _LienNav(
                              label: 'Studio Live',
                              route: '/studio-live',
                              onTap: () => _aller('/studio-live'),
                            ),
                          ),
                          Flexible(
                            child: _LienNav(
                              label: 'Guide & Tutoriel',
                              route: '/guide',
                              onTap: () => _aller('/guide'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 10),
                  if (widget.afficherAide && contraintes.maxWidth >= 420) ...<Widget>[
                    const AideWhatsApp(compact: true),
                    const SizedBox(width: 4),
                  ],
                  if (moyen) ...<Widget>[
                    const PaysSelector(compact: true),
                    const SizedBox(width: 8),
                  ],
                  _MenuCompte(
                    connecte: _connecte,
                    admin: _admin,
                    onCompte: () => _aller('/mon-espace'),
                    onAdmin: () => _aller('/admin-videos'),
                    onDeconnexion: _deconnexion,
                    compact: !moyen,
                  ),
                  if (!large) ...<Widget>[
                    const SizedBox(width: 2),
                    IconButton(
                      tooltip: 'Menu',
                      onPressed: () => _ouvrirMenu(context),
                      icon: const Icon(Icons.menu_rounded, color: K.text, size: 23),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _ouvrirMenu(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: K.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const LogoLockup(sousTitre: 'La Boutique · Studio Live'),
                const SizedBox(height: 20),
                _LigneMenu(
                  icone: Icons.storefront_rounded,
                  label: 'La Boutique',
                  sousTitre: 'Kits business sur mesure',
                  onTap: () {
                    Navigator.pop(context);
                    _aller('/boutique');
                  },
                ),
                _LigneMenu(
                  icone: Icons.sensors_rounded,
                  label: 'Studio Live',
                  sousTitre: 'Régie pro · abonnement 10 \$',
                  onTap: () {
                    Navigator.pop(context);
                    _aller('/studio-live');
                  },
                ),
                _LigneMenu(
                  icone: Icons.menu_book_rounded,
                  label: 'Guide & Tutoriel',
                  sousTitre: 'Commander, animer, vendre',
                  onTap: () {
                    Navigator.pop(context);
                    _aller('/guide');
                  },
                ),
                const Divider(height: 22, color: K.border),
                _LigneMenu(
                  icone: _connecte ? Icons.dashboard_rounded : Icons.person_rounded,
                  label: _connecte ? 'Mon espace' : 'Se connecter',
                  sousTitre: 'Compte, commandes, abonnement',
                  onTap: () {
                    Navigator.pop(context);
                    _aller('/mon-espace');
                  },
                ),
                if (_admin)
                  _LigneMenu(
                    icone: Icons.admin_panel_settings_rounded,
                    label: 'Administration',
                    sousTitre: 'Agence vidéo IA',
                    onTap: () {
                      Navigator.pop(context);
                      _aller('/admin-videos');
                    },
                  ),
                if (_connecte)
                  _LigneMenu(
                    icone: Icons.logout_rounded,
                    label: 'Se déconnecter',
                    onTap: () {
                      Navigator.pop(context);
                      _deconnexion();
                    },
                  ),
                const SizedBox(height: 8),
                const PaysSelector(),
                if (widget.afficherAide) ...<Widget>[
                  const SizedBox(height: 10),
                  const AideWhatsApp(pleinLargeur: true),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LogoBouton extends StatelessWidget {
  const _LogoBouton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: LogoLockup(tailleLogo: 36, tailleTexte: 19),
        ),
      ),
    );
  }
}

class _LienNav extends StatefulWidget {
  const _LienNav({
    required this.label,
    required this.route,
    required this.onTap,
  });

  final String label;
  final String route;
  final VoidCallback onTap;

  @override
  State<_LienNav> createState() => _LienNavState();
}

class _LienNavState extends State<_LienNav> {
  bool _survol = false;

  @override
  Widget build(BuildContext context) {
    final actif = ModalRoute.of(context)?.settings.name == widget.route;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _survol = true),
      onExit: (_) => setState(() => _survol = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: actif
                ? K.or.withValues(alpha: 0.08)
                : _survol
                    ? Colors.white.withValues(alpha: 0.035)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: actif ? K.or.withValues(alpha: 0.25) : Colors.transparent,
            ),
          ),
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: actif ? K.or : (_survol ? K.text : K.muted),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuCompte extends StatelessWidget {
  const _MenuCompte({
    required this.connecte,
    required this.admin,
    required this.onCompte,
    required this.onAdmin,
    required this.onDeconnexion,
    required this.compact,
  });

  final bool connecte;
  final bool admin;
  final VoidCallback onCompte;
  final VoidCallback onAdmin;
  final VoidCallback onDeconnexion;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Compte',
      offset: const Offset(0, 46),
      color: K.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: K.border),
      ),
      onSelected: (valeur) {
        switch (valeur) {
          case 'compte':
            onCompte();
          case 'admin':
            onAdmin();
          case 'deconnexion':
            onDeconnexion();
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'compte',
          child: Row(
            children: <Widget>[
              Icon(
                connecte ? Icons.person_rounded : Icons.login_rounded,
                size: 18,
                color: K.or,
              ),
              const SizedBox(width: 10),
              Text(
                connecte ? 'Mon espace' : 'Se connecter',
                style: const TextStyle(color: K.text, fontSize: 13),
              ),
            ],
          ),
        ),
        if (admin) ...<PopupMenuEntry<String>>[
          const PopupMenuDivider(height: 1),
          const PopupMenuItem<String>(
            value: 'admin',
            child: Row(
              children: <Widget>[
                Icon(Icons.admin_panel_settings_rounded, size: 18, color: K.emeraude),
                SizedBox(width: 10),
                Text(
                  'Administration',
                  style: TextStyle(color: K.text, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
        if (connecte) ...<PopupMenuEntry<String>>[
          const PopupMenuDivider(height: 1),
          const PopupMenuItem<String>(
            value: 'deconnexion',
            child: Row(
              children: <Widget>[
                Icon(Icons.logout_rounded, size: 18, color: K.muted),
                SizedBox(width: 10),
                Text(
                  'Se déconnecter',
                  style: TextStyle(color: K.muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ],
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 13, vertical: 9),
        decoration: BoxDecoration(
          color: K.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: K.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              connecte ? Icons.person_rounded : Icons.person_outline_rounded,
              color: connecte ? K.or : K.muted,
              size: 18,
            ),
            if (!compact) ...<Widget>[
              const SizedBox(width: 7),
              const Text(
                'Compte',
                style: TextStyle(
                  color: K.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LigneMenu extends StatelessWidget {
  const _LigneMenu({
    required this.icone,
    required this.label,
    this.sousTitre,
    required this.onTap,
  });

  final IconData icone;
  final String label;
  final String? sousTitre;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: K.or.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: K.or.withValues(alpha: 0.18)),
        ),
        child: Icon(icone, color: K.or, size: 19),
      ),
      title: Text(
        label,
        style: const TextStyle(color: K.text, fontSize: 14, fontWeight: FontWeight.w700),
      ),
      subtitle: sousTitre == null
          ? null
          : Text(
              sousTitre!,
              style: const TextStyle(color: K.faint, fontSize: 11),
            ),
      trailing: const Icon(Icons.chevron_right_rounded, color: K.faint, size: 19),
    );
  }
}

/// Utilitaire : ouvre le lien d'aide WhatsApp configuré.
Future<void> ouvrirAideWhatsApp(BuildContext context) async {
  await ouvrirLienAvecRetour(context, AppConfig.lienWhatsAppAide);
}
