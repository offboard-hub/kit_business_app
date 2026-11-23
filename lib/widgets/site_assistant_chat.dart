import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/theme.dart';
import 'whatsapp.dart';

/// ============================================================================
///  ASSISTANT IA DU SITE — bulle flottante discrète (bas droite).
///  La conversation est partagée avec la vue pleine page : « Ouvrir en pleine
///  interface » pousse `/assistant`, et « Retour au site » revient exactement
///  où l'utilisateur était (la page précédente garde son état).
/// ============================================================================
class SiteAssistantChat extends StatefulWidget {
  const SiteAssistantChat({super.key, this.afficherWhatsApp = true});

  final bool afficherWhatsApp;

  @override
  State<SiteAssistantChat> createState() => _SiteAssistantChatState();
}

class _SiteAssistantChatState extends State<SiteAssistantChat> {
  final TextEditingController _saisie = TextEditingController();
  final ScrollController _defilement = ScrollController();
  final AssistantState _etat = AssistantState.instance;
  bool _ouvert = false;

  @override
  void dispose() {
    _saisie.dispose();
    _defilement.dispose();
    super.dispose();
  }

  Future<void> _envoyer([String? texteForce]) async {
    final texte = (texteForce ?? _saisie.text).trim();
    if (texte.isEmpty) return;
    _saisie.clear();
    await _etat.envoyer(texte);
    _defiler();
  }

  void _defiler() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_defilement.hasClients) return;
      _defilement.animateTo(
        _defilement.position.maxScrollExtent + 90,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        if (_ouvert) ...<Widget>[
          _Panneau(
            etat: _etat,
            saisie: _saisie,
            defilement: _defilement,
            onEnvoyer: _envoyer,
            onFermer: () => setState(() => _ouvert = false),
            onPleinEcran: () {
              setState(() => _ouvert = false);
              Navigator.pushNamed(context, '/assistant');
            },
          ),
          const SizedBox(height: 10),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (widget.afficherWhatsApp && !_ouvert) ...<Widget>[
              const WhatsAppFlottant(),
              const SizedBox(width: 10),
            ],
            _BulleAssistant(
              ouvert: _ouvert,
              onTap: () {
                setState(() => _ouvert = !_ouvert);
                if (_ouvert) _defiler();
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _BulleAssistant extends StatefulWidget {
  const _BulleAssistant({required this.ouvert, required this.onTap});

  final bool ouvert;
  final VoidCallback onTap;

  @override
  State<_BulleAssistant> createState() => _BulleAssistantState();
}

class _BulleAssistantState extends State<_BulleAssistant> {
  bool _survol = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _survol = true),
      onExit: (_) => setState(() => _survol = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: widget.ouvert ? K.direct : K.marque,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: (widget.ouvert ? K.emeraude : K.or)
                    .withValues(alpha: _survol ? 0.5 : 0.32),
                blurRadius: _survol ? 30 : 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            widget.ouvert ? Icons.close_rounded : Icons.auto_awesome_rounded,
            color: K.bg,
            size: 26,
          ),
        ),
      ),
    );
  }
}

class _Panneau extends StatelessWidget {
  const _Panneau({
    required this.etat,
    required this.saisie,
    required this.defilement,
    required this.onEnvoyer,
    required this.onFermer,
    required this.onPleinEcran,
  });

  final AssistantState etat;
  final TextEditingController saisie;
  final ScrollController defilement;
  final Future<void> Function([String? texte]) onEnvoyer;
  final VoidCallback onFermer;
  final VoidCallback onPleinEcran;

  @override
  Widget build(BuildContext context) {
    final taille = MediaQuery.sizeOf(context);
    final largeur = math.min(taille.width - 28, 390.0);
    final hauteur = math.min(taille.height * 0.68, 560.0);

    return Container(
      width: largeur,
      height: hauteur,
      decoration: BoxDecoration(
        color: K.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: K.borderLight),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          _EnTete(onFermer: onFermer, onPleinEcran: onPleinEcran),
          const Divider(height: 1, color: K.border),
          Expanded(
            child: ListenableBuilder(
              listenable: etat,
              builder: (context, _) {
                return ListView.builder(
                  controller: defilement,
                  padding: const EdgeInsets.fromLTRB(13, 13, 13, 6),
                  itemCount: etat.messages.length + (etat.chargement ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= etat.messages.length) return const _Chargement();
                    return _Bulle(message: etat.messages[index]);
                  },
                );
              },
            ),
          ),
          ListenableBuilder(
            listenable: etat,
            builder: (context, _) {
              if (etat.chargement || etat.suggestions.isEmpty) {
                return const SizedBox.shrink();
              }
              return SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: etat.suggestions.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final suggestion = etat.suggestions[index];
                    return ActionChip(
                      label: Text(
                        suggestion,
                        style: const TextStyle(fontSize: 10.5, color: K.or),
                      ),
                      backgroundColor: K.bg.withValues(alpha: 0.6),
                      side: BorderSide(color: K.or.withValues(alpha: 0.24)),
                      onPressed: () => onEnvoyer(suggestion),
                    );
                  },
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: saisie,
                    style: const TextStyle(color: K.text, fontSize: 13),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onEnvoyer(),
                    decoration: InputDecoration(
                      hintText: 'Posez votre question…',
                      hintStyle: const TextStyle(color: K.faint, fontSize: 12.5),
                      filled: true,
                      fillColor: K.bg.withValues(alpha: 0.55),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: K.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: K.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: K.or, width: 1.3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => onEnvoyer(),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: K.orGradient,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.arrow_upward_rounded, color: K.bg, size: 20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EnTete extends StatelessWidget {
  const _EnTete({required this.onFermer, required this.onPleinEcran});

  final VoidCallback onFermer;
  final VoidCallback onPleinEcran;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(gradient: K.marque, shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome_rounded, color: K.bg, size: 19),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Awa · Assistante e-booklive',
                  style: TextStyle(
                    color: K.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 2),
                Row(
                  children: <Widget>[
                    Icon(Icons.circle, size: 6, color: K.emeraude),
                    SizedBox(width: 5),
                    Text(
                      'En ligne · réponse en quelques secondes',
                      style: TextStyle(color: K.faint, fontSize: 9.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Plein écran',
            onPressed: onPleinEcran,
            icon: const Icon(Icons.open_in_full_rounded, color: K.muted, size: 18),
          ),
          IconButton(
            tooltip: 'Fermer',
            onPressed: onFermer,
            icon: const Icon(Icons.close_rounded, color: K.muted, size: 19),
          ),
        ],
      ),
    );
  }
}

class _Bulle extends StatelessWidget {
  const _Bulle({required this.message});

  final MessageAssistant message;

  @override
  Widget build(BuildContext context) {
    final assistant = message.assistant;
    return Align(
      alignment: assistant ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 292),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: assistant ? K.bg.withValues(alpha: 0.6) : K.or.withValues(alpha: 0.14),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: Radius.circular(assistant ? 4 : 15),
            bottomRight: Radius.circular(assistant ? 15 : 4),
          ),
          border: Border.all(
            color: assistant ? K.border : K.or.withValues(alpha: 0.28),
          ),
        ),
        child: Text(
          message.texte,
          style: TextStyle(
            color: assistant ? K.text : K.orSoft,
            fontSize: 12.5,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _Chargement extends StatelessWidget {
  const _Chargement();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: K.bg.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: K.border),
        ),
        child: const SizedBox(
          width: 15,
          height: 15,
          child: CircularProgressIndicator(color: K.or, strokeWidth: 2),
        ),
      ),
    );
  }
}
