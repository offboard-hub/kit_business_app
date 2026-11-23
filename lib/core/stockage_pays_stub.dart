/// Version non-web : aucune persistance, le pays reste en mémoire.
class StockagePays {
  const StockagePays._();

  static Future<String?> lire() async => null;

  static Future<void> ecrire(String code) async {}
}
