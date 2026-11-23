import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Ouvre l'overlay Paddle.js via le pont JavaScript défini dans `web/index.html`.
/// Retourne `false` si Paddle.js n'est pas chargé (l'appelant peut alors
/// proposer le lien de paiement ou le support WhatsApp).
Future<bool> ouvrirPaddleCheckout({
  required String clientToken,
  required String transactionId,
  String environment = 'production',
}) async {
  try {
    await _chargerPaddle();
    final pont = globalContext['ebooklivePaddle'];
    if (pont == null || pont.isUndefinedOrNull) return false;
    final resultat = (pont as JSObject).callMethod(
      'open'.toJS,
      clientToken.toJS,
      transactionId.toJS,
      environment.toJS,
    );
    return resultat.dartify() == true;
  } catch (_) {
    return false;
  }
}

/// Charge Paddle.js uniquement au moment du paiement Paddle.
Future<void> _chargerPaddle() async {
  final existant = globalContext['Paddle'];
  if (existant != null && !existant.isUndefinedOrNull) return;

  final script = web.document.createElement('script') as web.HTMLScriptElement;
  script.src = 'https://cdn.paddle.com/paddle/v2/paddle.js';
  script.async = true;
  web.document.head!.append(script);

  for (var i = 0; i < 30; i++) {
    final paddle = globalContext['Paddle'];
    if (paddle != null && !paddle.isUndefinedOrNull) return;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}
