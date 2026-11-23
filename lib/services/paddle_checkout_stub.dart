/// Version non-web : Paddle.js n'est pas disponible.
Future<bool> ouvrirPaddleCheckout({
  required String clientToken,
  required String transactionId,
  String environment = 'production',
}) async {
  return false;
}
