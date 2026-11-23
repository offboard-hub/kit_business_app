import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/links.dart';
import '../core/models.dart';
import '../core/theme.dart';
import 'paddle_checkout.dart';

/// Lance le paiement : overlay Paddle.js en priorité, sinon page hébergée
/// SasPay / Paddle.
///
/// ⚠️ Paddle peut renvoyer une `checkout_url` sur notre propre domaine
/// (`https://e-booklive.offboard-hub.com?_ptxn=…`). Ouvrir ce lien comme une
/// page externe ne déclenche AUCUN paiement : il faut passer par Paddle.js avec
/// `transaction_id` + `client_token`, sinon on affiche une erreur claire.
Future<bool> lancerCheckout(BuildContext context, CheckoutCree checkout) async {
  final estPaddle = checkout.fournisseur == Fournisseur.paddle;

  // 1. Paddle.js : recommandé, fonctionne aussi avec une URL de retour sur
  //    notre domaine (le `_ptxn` est alors géré par l'overlay).
  if (estPaddle &&
      checkout.transactionId.isNotEmpty &&
      checkout.clientToken.isNotEmpty) {
    final ouvert = await ouvrirPaddleCheckout(
      clientToken: checkout.clientToken,
      transactionId: checkout.transactionId,
      environment: checkout.environment,
    );
    if (ouvert) return true;
  }

  // 2. Page de paiement hébergée (SasPay, ou Paddle si l'URL est externe).
  if (checkout.checkoutUrl.isNotEmpty) {
    if (estPaddle && _estNotreDomaine(checkout.checkoutUrl)) {
      if (context.mounted) await _dialogueLien(context, '');
      return false;
    }
    final ouvert = await ouvrirLien(checkout.checkoutUrl);
    if (!ouvert && context.mounted) {
      await _dialogueLien(context, checkout.checkoutUrl);
    }
    return ouvert;
  }

  if (context.mounted) {
    await _dialogueLien(context, '');
  }
  return false;
}

bool _estNotreDomaine(String url) {
  final uri = Uri.tryParse(url);
  final site = Uri.tryParse(AppConfig.siteUrl);
  if (uri == null || site == null) return false;
  return uri.host.isNotEmpty && uri.host == site.host;
}

Future<void> _dialogueLien(BuildContext context, String url) async {
  if (url.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: K.surface,
        title: const Text('Paiement indisponible', style: TextStyle(color: K.text)),
        content: const Text(
          'Le lien de paiement n\'a pas pu être ouvert. Réessayez dans un instant '
          'ou contactez-nous sur WhatsApp : nous vous envoyons un lien sécurisé.',
          style: TextStyle(color: K.muted, fontSize: 13, height: 1.5),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer', style: TextStyle(color: K.muted)),
          ),
        ],
      ),
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: K.surface,
      title: const Text('Finaliser le paiement', style: TextStyle(color: K.text)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Votre navigateur a bloqué l\'ouverture de la page de paiement. '
            'Copiez ce lien sécurisé dans un nouvel onglet :',
            style: TextStyle(color: K.muted, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 12),
          SelectableText(url, style: const TextStyle(color: K.or, fontSize: 12)),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer', style: TextStyle(color: K.muted)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            ouvrirLienAvecRetour(context, url);
          },
          style: ElevatedButton.styleFrom(backgroundColor: K.or),
          child: const Text('Ouvrir', style: TextStyle(color: K.bg)),
        ),
      ],
    ),
  );
}
