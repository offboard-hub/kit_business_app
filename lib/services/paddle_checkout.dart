// Ouverture de la couche Paddle.js (fallback quand Paddle ne renvoie pas
// d'URL de checkout hébergée).
export 'paddle_checkout_stub.dart'
    if (dart.library.js_interop) 'paddle_checkout_web.dart';
