import 'package:flutter/material.dart';

import '../core/links.dart';
import '../core/models.dart';
import '../core/theme.dart';
import 'paddle_checkout.dart';

/// Lance le paiement : page hébergée SasPay/Paddle, ou overlay Paddle.js.
/// Retourne `true` si une page/overlay a bien été ouvert.
Future<bool> lancerCheckout(BuildContext context, CheckoutCree checkout) async {
  if (checkout.checkoutUrl.isNotEmpty) {
    final ouvert = await ouvrirLien(checkout.checkoutUrl);
    if (!ouvert && context.mounted) {
      await _dialogueLien(context, checkout.checkoutUrl);
    }
    return ouvert;
  }

  if (checkout.fournisseur == Fournisseur.paddle &&
      checkout.transactionId.isNotEmpty &&
      checkout.clientToken.isNotEmpty) {
    final ouvert = await ouvrirPaddleCheckout(
      clientToken: checkout.clientToken,
      transactionId: checkout.transactionId,
      environment: checkout.environment,
    );
    if (ouvert) return true;
  }

  if (context.mounted) {
    await _dialogueLien(context, checkout.checkoutUrl);
  }
  return false;
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
