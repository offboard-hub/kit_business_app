import 'package:web/web.dart' as web;

/// Version web : le pays choisi est mémorisé dans le localStorage.
class StockagePays {
  const StockagePays._();

  static const String _cle = 'ebooklive.pays';

  static Future<String?> lire() async {
    try {
      return web.window.localStorage.getItem(_cle);
    } catch (_) {
      return null;
    }
  }

  static Future<void> ecrire(String code) async {
    try {
      web.window.localStorage.setItem(_cle, code);
    } catch (_) {
      // Navigation privée ou stockage plein : ce n'est pas bloquant.
    }
  }
}
