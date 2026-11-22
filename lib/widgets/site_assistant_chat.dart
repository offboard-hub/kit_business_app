import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/links.dart';
import '../core/theme.dart';
import '../services/api.dart';
import 'whatsapp.dart';

class _Message {
  const _Message({required this.texte, required this.assistant});

  final String texte;
  final bool assistant;
}

/// Bulle de chat IA du site — répond aux questions des spectateurs des Lives
/// OBS et les redirige vers le lien d'achat SasPay.
class SiteAssistantChat extends StatefulWidget {
  const SiteAssistantChat({super.key, this.afficherWhatsApp = true});

  final bool afficherWhatsApp;

  @override
  State<SiteAssistantChat> createState() => _SiteAssistantChatState();
}

class _SiteAssistantChatState extends State<SiteAssistantChat> {
  final TextEditingController _saisie = TextEditingController();
  final ScrollController _defilement = ScrollController();
  final String _idConversation = 'web-${DateTime.now().microsecondsSinceEpoch}';

  final List<_Message> _messages = [
    const _Message(
      texte:
          'Bonjour 👋 Je suis Awa, l\'assistante Kit Business. Je vous aide à choisir le kit adapté à votre métier. Quel est votre secteur ?',
      assistant: true,
    ),
  ];

  List<String> _suggestions = const [
    'Quel kit pour un maquis ?',
    'Combien coûte le Pack Complet ?',
    'Comment je reçois mon kit ?',
  ];

  String? _cta;
  bool _ouvert = false;
  bool _chargement = false;

  @override
  void dispose() {
    _saisie.dispose();
    _defilement.dispose();
    super.dispose();
  }

  void _defiler() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_defilement.hasClients) return;
      _defilement.animateTo(
        _defilement.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _envoyer([String? texteForce]) async {
    final texte = (texteForce ?? _saisie.text).trim();
    if (texte.isEmpty || _chargement) return;

    setState(() {
      _messages.add(_Message(texte: texte, assistant: false));
      _saisie.clear();
      _chargement = true;
    });
    _defiler();

    try {
      final reponse = await ApiService.assistant(message: texte, conversationId: _idConversation);
      if (!mounted) return;
      setState(() {
        _messages.add(_Message(texte: reponse.reply, assistant: true));
        _chargement = false;
        if (reponse.suggestions.isNotEmpty) _suggestions = reponse.suggestions;
        _cta = reponse.ctaUrl;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          const _Message(
            texte:
                'Je n\'arrive pas à répondre pour le moment. Choisissez votre kit directement ou écrivez-nous sur WhatsApp, nous répondons vite.',
            assistant: true,
          ),
        );
        _chargement = false;
        _cta = AppConfig.lienCommande;
      });
    }
    _defiler();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_ouvert) ...[
          _panneau(context),
          const SizedBox(height: 10),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.afficherWhatsApp && !_ouvert) ...[
              const WhatsAppFlottant(),
              const SizedBox(width: 10),
            ],
            FloatingActionButton(
              heroTag: 'assistant-ia',
              backgroundColor: K.gold,
              foregroundColor: K.night,
              tooltip: _ouvert ? 'Fermer l\'assistant' : 'Poser une question',
              onPressed: () => setState(() => _ouvert = !_ouvert),
              child: Icon(_ouvert ? Icons.close_rounded : Icons.auto_awesome_rounded),
            ),
          ],
        ),
      ],
    );
  }

  Widget _panneau(BuildContext context) {
    final taille = MediaQuery.sizeOf(context);
    final largeur = math.min(taille.width - 28, 372.0);
    final hauteur = math.min(taille.height * 0.62, 486.0);

    return Container(
      width: largeur,
      height: hauteur,
      decoration: BoxDecoration(
        color: K.night,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: K.gold.withValues(alpha: 0.35)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 30, offset: const Offset(0, 12))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(gradient: K.or, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const Text('A', style: TextStyle(color: K.night, fontWeight: FontWeight.w900, fontSize: 18)),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Awa · Assistante IA',
                        style: TextStyle(color: K.sand, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: K.green),
                          SizedBox(width: 5),
                          Text('En ligne · répond en quelques secondes',
                              style: TextStyle(color: K.mist, fontSize: 10.5)),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _ouvert = false),
                  icon: const Icon(Icons.close_rounded, color: K.mist, size: 20),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: ListView.builder(
              controller: _defilement,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              itemCount: _messages.length + (_chargement ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _messages.length) return _bulleChargement();
                return _bulle(_messages[index]);
              },
            ),
          ),
          if (_suggestions.isNotEmpty && !_chargement)
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _suggestions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final suggestion = _suggestions[index];
                  return ActionChip(
                    label: Text(suggestion, style: const TextStyle(fontSize: 11, color: K.gold)),
                    backgroundColor: K.deep,
                    side: BorderSide(color: K.gold.withValues(alpha: 0.3)),
                    onPressed: () => _envoyer(suggestion),
                  );
                },
              ),
            ),
          if (_cta != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: () => ouvrirLienAvecRetour(context, _cta!),
                  icon: const Icon(Icons.rocket_launch_rounded, size: 17, color: K.night),
                  label: const Text(
                    'Choisir mon kit (dès 3 000 FCFA)',
                    style: TextStyle(color: K.night, fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: K.gold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _saisie,
                    style: const TextStyle(color: K.sand, fontSize: 13.5),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _envoyer(),
                    decoration: InputDecoration(
                      hintText: 'Posez votre question…',
                      hintStyle: TextStyle(color: K.mist.withValues(alpha: 0.6), fontSize: 13),
                      filled: true,
                      fillColor: K.deep.withValues(alpha: 0.8),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 42,
                  height: 42,
                  child: ElevatedButton(
                    onPressed: _chargement ? null : () => _envoyer(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: K.gold,
                      padding: EdgeInsets.zero,
                      shape: const CircleBorder(),
                    ),
                    child: const Icon(Icons.send_rounded, color: K.night, size: 19),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulle(_Message message) {
    return Align(
      alignment: message.assistant ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: message.assistant ? K.deep : K.gold,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.assistant ? 4 : 16),
            bottomRight: Radius.circular(message.assistant ? 16 : 4),
          ),
          border: message.assistant ? Border.all(color: K.gold.withValues(alpha: 0.2)) : null,
        ),
        child: Text(
          message.texte,
          style: TextStyle(
            color: message.assistant ? K.sand : K.night,
            fontSize: 13,
            height: 1.45,
            fontWeight: message.assistant ? FontWeight.w400 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _bulleChargement() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: K.deep,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: K.gold.withValues(alpha: 0.2)),
        ),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(color: K.gold, strokeWidth: 2),
        ),
      ),
    );
  }
}
