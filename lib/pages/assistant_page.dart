import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/theme.dart';
import '../widgets/logo_ebooklive.dart';

/// ============================================================================
///  ASSISTANT IA — VUE PLEINE INTERFACE
///  « Retour au site » revient exactement sur la page précédente (état conservé).
///  La conversation est la même que celle de la bulle flottante.
/// ============================================================================
class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key});

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final AssistantState _etat = AssistantState.instance;
  final TextEditingController _saisie = TextEditingController();
  final ScrollController _defilement = ScrollController();

  @override
  void initState() {
    super.initState();
    _etat.ouvrirPleinEcran();
    WidgetsBinding.instance.addPostFrameCallback((_) => _defiler());
  }

  @override
  void dispose() {
    _etat.quitterPleinEcran();
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
        _defilement.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _retour() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PatternBackground(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _EnTete(onRetour: _retour),
              const Divider(height: 1, color: K.border),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, contraintes) {
                    final large = contraintes.maxWidth > 980;
                    return Row(
                      children: <Widget>[
                        Expanded(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 820),
                              child: Column(
                                children: <Widget>[
                                  Expanded(child: _conversation()),
                                  _suggestions(),
                                  _composeur(),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (large) ...<Widget>[
                          Container(width: 1, color: K.border),
                          const SizedBox(
                            width: 300,
                            child: _Raccourcis(),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conversation() {
    return ListenableBuilder(
      listenable: _etat,
      builder: (context, _) {
        return ListView.builder(
          controller: _defilement,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          itemCount: _etat.messages.length + (_etat.chargement ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _etat.messages.length) return const _ChargementGrand();
            return _BulleGrande(message: _etat.messages[index]);
          },
        );
      },
    );
  }

  Widget _suggestions() {
    return ListenableBuilder(
      listenable: _etat,
      builder: (context, _) {
        if (_etat.chargement || _etat.suggestions.isEmpty) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _etat.suggestions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final suggestion = _etat.suggestions[index];
              return ActionChip(
                avatar: const Icon(Icons.auto_awesome_rounded, size: 13, color: K.or),
                label: Text(
                  suggestion,
                  style: const TextStyle(fontSize: 11.5, color: K.text),
                ),
                backgroundColor: K.surface,
                side: const BorderSide(color: K.border),
                onPressed: () => _envoyer(suggestion),
              );
            },
          ),
        );
      },
    );
  }

  Widget _composeur() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          decoration: BoxDecoration(
            color: K.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: K.borderLight),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _saisie,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  style: const TextStyle(color: K.text, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Écrivez votre question à Awa…',
                    hintStyle: TextStyle(color: K.faint, fontSize: 13.5),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  ),
                  onSubmitted: (_) => _envoyer(),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 46,
                height: 46,
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _envoyer(),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: K.marque,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.arrow_upward_rounded, color: K.bg, size: 22),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnTete extends StatelessWidget {
  const _EnTete({required this.onRetour});

  final VoidCallback onRetour;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        children: <Widget>[
          const LogoEbooklive(size: 38),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Assistant e-booklive',
                  style: TextStyle(
                    color: K.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Prix par pays · La Boutique · Studio Live · Guide',
                  style: TextStyle(color: K.faint, fontSize: 10.5),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onRetour,
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Retour au site'),
            style: OutlinedButton.styleFrom(
              foregroundColor: K.text,
              side: const BorderSide(color: K.borderLight),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
              textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _Raccourcis extends StatelessWidget {
  const _Raccourcis();

  @override
  Widget build(BuildContext context) {
    const raccourcis = <(IconData, String, String, String)>[
      (Icons.storefront_rounded, 'La Boutique', '8 secteurs, 4 kits', '/boutique'),
      (Icons.sensors_rounded, 'Studio Live', '10 \$ / 30 jours', '/studio-live'),
      (Icons.menu_book_rounded, 'Guide & Tutoriel', '3 étapes illustrées', '/guide'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'ACCÈS RAPIDES',
            style: TextStyle(
              color: K.faint,
              fontSize: 9.5,
              letterSpacing: 2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          for (final raccourci in raccourcis)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pushNamed(context, raccourci.$4),
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: K.surface.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: K.border),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(raccourci.$1, color: K.or, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                raccourci.$2,
                                style: const TextStyle(
                                  color: K.text,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                raccourci.$3,
                                style: const TextStyle(color: K.faint, fontSize: 9.5),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: K.faint, size: 17),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: K.emeraude.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: K.emeraude.withValues(alpha: 0.2)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.lock_outline_rounded, size: 13, color: K.emeraude),
                    SizedBox(width: 6),
                    Text(
                      'Confidentialité',
                      style: TextStyle(
                        color: K.emeraude,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'Ne partagez jamais de données bancaires dans le chat. Les réponses '
                  'sont générées par IA : vérifiez toujours le prix affiché avant de payer.',
                  style: TextStyle(color: K.muted, fontSize: 10, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BulleGrande extends StatelessWidget {
  const _BulleGrande({required this.message});

  final MessageAssistant message;

  @override
  Widget build(BuildContext context) {
    final assistant = message.assistant;
    if (!assistant) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          margin: const EdgeInsets.only(bottom: 18, left: 40),
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
          decoration: BoxDecoration(
            gradient: K.orGradient,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(17),
              topRight: Radius.circular(17),
              bottomLeft: Radius.circular(17),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: K.or.withValues(alpha: 0.18),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            message.texte,
            style: const TextStyle(
              color: K.bg,
              fontSize: 13.5,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: const EdgeInsets.only(bottom: 18, right: 30),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: K.surface.withValues(alpha: 0.72),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(17),
            bottomLeft: Radius.circular(17),
            bottomRight: Radius.circular(17),
          ),
          border: Border.all(color: K.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(gradient: K.marque, shape: BoxShape.circle),
              child: const Icon(Icons.auto_awesome_rounded, color: K.bg, size: 15),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message.texte,
                style: const TextStyle(color: K.text, fontSize: 13.5, height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChargementGrand extends StatelessWidget {
  const _ChargementGrand();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: K.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: K.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(color: K.or, strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              'Awa rédige sa réponse…',
              style: TextStyle(color: K.muted.withValues(alpha: 0.9), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
