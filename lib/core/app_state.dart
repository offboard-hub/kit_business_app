import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'countries.dart';
import 'pricing.dart';
import 'stockage_pays.dart';
import '../services/api.dart';

/// ============================================================================
///  ÉTAT GLOBAL PARTAGÉ
///  • CountryStore   : pays sélectionné (persisté localement), source unique de
///                     vérité pour la conversion des prix sur tout le site.
///  • AssistantState : conversation de l'assistant IA partagée entre la bulle
///                     flottante et la vue pleine page (on ne perd rien quand
///                     on passe de l'une à l'autre).
/// ============================================================================

class CountryStore {
  const CountryStore._();

  static final ValueNotifier<PaysMonde> pays =
      ValueNotifier<PaysMonde>(paysParDefaut);

  static bool _initialise = false;

  /// Restaure le pays choisi lors de la dernière visite.
  static Future<void> initialiser() async {
    if (_initialise) return;
    _initialise = true;
    final code = await StockagePays.lire();
    if (code != null && code.isNotEmpty) {
      pays.value = paysParCode(code);
    }
  }

  /// Change le pays et le mémorise.
  static void definir(PaysMonde nouveau) {
    if (nouveau.code == pays.value.code) return;
    pays.value = nouveau;
    unawaited(StockagePays.ecrire(nouveau.code));
  }

  /// Devis kit pour le pays courant.
  static DevisPrix devisKit(int prixXof) => Prix.devisKit(prixXof, pays.value);

  /// Devis Studio Live pour le pays courant.
  static DevisPrix devisStudio() => Prix.devisStudio(pays.value);
}

/// Un message de la conversation de l'assistant.
class MessageAssistant {
  const MessageAssistant({
    required this.texte,
    required this.assistant,
    required this.date,
  });

  final String texte;
  final bool assistant;
  final DateTime date;
}

/// Conversation partagée avec l'assistant IA du site.
class AssistantState extends ChangeNotifier {
  AssistantState._();

  static final AssistantState instance = AssistantState._();

  final List<MessageAssistant> messages = <MessageAssistant>[
    MessageAssistant(
      texte:
          'Bonjour 👋 Je suis Awa, l\'assistante e-booklive. Je vous aide à choisir '
          'entre La Boutique et le Studio Live, à comprendre les prix dans votre '
          'devise et à préparer votre direct. Que puis-je faire pour vous ?',
      assistant: true,
      date: DateTime.now(),
    ),
  ];

  final String conversationId = _identifiantConversation();

  static String _identifiantConversation() {
    final alea = Random.secure();
    final tampon = StringBuffer('web-');
    for (var i = 0; i < 16; i++) {
      tampon.write(alea.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return tampon.toString();
  }

  List<String> suggestions = const <String>[
    'Quel kit pour ma boutique en ligne ?',
    'Combien coûte le Studio Live au Maroc ?',
    'Comment fonctionne le paiement SasPay ?',
    'Comment préparer mon premier live ?',
  ];

  String? cta;
  bool chargement = false;
  bool _pleinEcran = false;

  bool get pleinEcran => _pleinEcran;

  void ouvrirPleinEcran() {
    _pleinEcran = true;
    notifyListeners();
  }

  void quitterPleinEcran() {
    _pleinEcran = false;
    notifyListeners();
  }

  Future<void> envoyer(String texte) async {
    final message = texte.trim();
    if (message.isEmpty || chargement) return;

    messages.add(
      MessageAssistant(texte: message, assistant: false, date: DateTime.now()),
    );
    chargement = true;
    notifyListeners();

    try {
      final reponse = await ApiService.assistant(
        message: message,
        conversationId: conversationId,
      );
      messages.add(
        MessageAssistant(
          texte: reponse.reply,
          assistant: true,
          date: DateTime.now(),
        ),
      );
      if (reponse.suggestions.isNotEmpty) suggestions = reponse.suggestions;
      cta = reponse.ctaUrl;
    } catch (_) {
      messages.add(
        MessageAssistant(
          texte:
              'Je n\'arrive pas à répondre pour le moment. Vous pouvez ouvrir La '
              'Boutique ou le Studio Live directement, ou nous écrire sur WhatsApp : '
              'nous répondons vite.',
          assistant: true,
          date: DateTime.now(),
        ),
      );
    } finally {
      chargement = false;
      notifyListeners();
    }
  }
}
