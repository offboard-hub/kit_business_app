// ============================================================================
//  RÉFÉRENTIEL MONDIAL DES PAYS & DEVISES — e-booklive
//
//  • Tous les pays du monde (recherche instantanée + drapeaux).
//  • 23 pays encaissés par SasPay dans leur devise locale.
//  • Tous les autres pays passent par Paddle (EUR pour l'Europe et le Maghreb,
//    USD ailleurs) avec une conversion locale indicative.
//
//  Les taux sont exprimés en « 1 XOF = X devise ». Ils sont volontairement
//  simples à mettre à jour : une seule table `tauxXof` à ajuster.
//  ⚠️ Le backend possède le même référentiel
//  (supabase/functions/_shared/countries.ts) et recalcule toujours le montant
//  facturé : le prix affiché ici est indicatif, jamais envoyé comme montant.
// ============================================================================

/// Zone géographique — sert à choisir la devise de facturation Paddle.
enum Region {
  afriqueNord,
  afriqueOuest,
  afriqueCentrale,
  afriqueEst,
  afriqueAustrale,
  europe,
  ameriqueNord,
  ameriqueLatine,
  asie,
  moyenOrient,
  oceanie,
}

/// Taux de conversion : 1 XOF = X unité de la devise.
const Map<String, double> tauxXof = <String, double>{
  'XOF': 1,
  'XAF': 1,
  'EUR': 0.00152449,
  'USD': 0.00165,
  'GBP': 0.00129,
  'CHF': 0.00145,
  'CAD': 0.00226,
  'AUD': 0.00250,
  'NZD': 0.00275,
  'JPY': 0.247,
  'CNY': 0.0118,
  'HKD': 0.0129,
  'SGD': 0.00222,
  'KRW': 2.31,
  'INR': 0.138,
  'IDR': 26.4,
  'MYR': 0.00743,
  'PHP': 0.0956,
  'THB': 0.0545,
  'VND': 40.9,
  'TWD': 0.0538,
  'PKR': 0.459,
  'BDT': 0.197,
  'LKR': 0.495,
  'NPR': 0.221,
  'AFN': 0.118,
  'AMD': 0.643,
  'AZN': 0.00281,
  'GEL': 0.00448,
  'KZT': 0.86,
  'KGS': 0.143,
  'TJS': 0.018,
  'TMT': 0.00578,
  'UZS': 20.7,
  'BYN': 0.0054,
  'GYD': 0.345,
  'MNT': 5.7,
  'MMK': 3.47,
  'KHR': 6.7,
  'LAK': 36.3,
  'BND': 0.00222,
  'MVR': 0.0254,
  'BTN': 0.138,
  'ILS': 0.00615,
  'JOD': 0.00117,
  'LBP': 148,
  'SYP': 21.8,
  'IQD': 2.17,
  'IRR': 69.3,
  'SAR': 0.00619,
  'AED': 0.00606,
  'QAR': 0.00601,
  'KWD': 0.000507,
  'BHD': 0.000621,
  'OMR': 0.000635,
  'YER': 0.413,
  'TRY': 0.056,
  'RUB': 0.152,
  'UAH': 0.068,
  'PLN': 0.00655,
  'CZK': 0.0383,
  'HUF': 0.602,
  'RON': 0.00759,
  'BGN': 0.00298,
  'RSD': 0.178,
  'MKD': 0.0938,
  'ALL': 0.155,
  'BAM': 0.00298,
  'MDL': 0.0295,
  'ISK': 0.229,
  'NOK': 0.0179,
  'SEK': 0.0175,
  'DKK': 0.01137,
  'MAD': 0.0164,
  'DZD': 0.222,
  'TND': 0.00518,
  'LYD': 0.00795,
  'EGP': 0.081,
  'CDF': 4.60,
  'GNF': 14.30,
  'NGN': 2.56,
  'GHS': 0.0256,
  'SLE': 0.0371,
  'KES': 0.213,
  'UGX': 5.69,
  'TZS': 3.96,
  'RWF': 2.05,
  'MWK': 2.70,
  'MZN': 0.105,
  'ZMW': 0.0396,
  'ZAR': 0.0295,
  'NAD': 0.0295,
  'SZL': 0.0295,
  'LSL': 0.0295,
  'BWP': 0.0225,
  'AOA': 1.52,
  'BIF': 4.8,
  'DJF': 0.293,
  'ERN': 0.0248,
  'ETB': 0.222,
  'GMD': 0.115,
  'LRD': 0.32,
  'MRU': 0.066,
  'MUR': 0.077,
  'CVE': 0.168,
  'KMF': 0.746,
  'MGA': 7.65,
  'SCR': 0.0235,
  'SOS': 0.943,
  'SSP': 6.5,
  'SDG': 0.99,
  'STN': 0.0372,
  'ZWL': 0.0436,
  'ARS': 1.56,
  'BOB': 0.0114,
  'BRL': 0.0089,
  'CLP': 1.57,
  'COP': 6.6,
  'CRC': 0.85,
  'CUP': 0.0396,
  'DOP': 0.098,
  'GTQ': 0.0129,
  'HNL': 0.0405,
  'HTG': 0.216,
  'JMD': 0.258,
  'MXN': 0.0300,
  'NIO': 0.0608,
  'PAB': 0.00165,
  'PEN': 0.00626,
  'PYG': 12.9,
  'SRD': 0.058,
  'TTD': 0.0112,
  'UYU': 0.069,
  'VES': 0.12,
  'XCD': 0.00446,
  'BSD': 0.00165,
  'BBD': 0.0033,
  'BZD': 0.00332,
  'BMD': 0.00165,
  'KYD': 0.00138,
  'AWG': 0.00297,
  'XCG': 0.00297,
  'FKP': 0.00129,
  'GIP': 0.00129,
  'FJD': 0.00376,
  'PGK': 0.0066,
  'SBD': 0.0139,
  'TOP': 0.0039,
  'VUV': 0.197,
  'WST': 0.0045,
  'XPF': 0.182,
  'KPW': 1.485,
};

/// Devises affichées sans décimales (montants ronds).
const Set<String> devisesEntieres = <String>{
  'XOF', 'XAF', 'CDF', 'GNF', 'UGX', 'TZS', 'RWF', 'MWK', 'MZN', 'JPY',
  'KRW', 'VND', 'IDR', 'CLP', 'COP', 'PYG', 'KHR', 'LAK', 'MMK', 'MNT',
  'UZS', 'LBP', 'IRR', 'SYP', 'ISK', 'HUF', 'NGN', 'PKR', 'LKR', 'NPR',
  'BDT', 'AFN', 'AMD', 'KZT', 'KGS', 'TJS', 'XPF',
  'BYN', 'GYD',
};

const Map<String, String> symbolesDevises = <String, String>{
  'XOF': 'FCFA',
  'XAF': 'FCFA',
  'EUR': '€',
  'USD': '\$',
  'GBP': '£',
  'CHF': 'CHF',
  'CAD': 'CA\$',
  'AUD': 'A\$',
  'NZD': 'NZ\$',
  'JPY': '¥',
  'CNY': '¥',
  'HKD': 'HK\$',
  'SGD': 'S\$',
  'KRW': '₩',
  'INR': '₹',
  'IDR': 'Rp',
  'MYR': 'RM',
  'PHP': '₱',
  'THB': '฿',
  'VND': '₫',
  'TWD': 'NT\$',
  'PKR': '₨',
  'BDT': '৳',
  'LKR': 'Rs',
  'NPR': 'Rs',
  'NGN': '₦',
  'GHS': 'GH₵',
  'KES': 'KSh',
  'TZS': 'TSh',
  'UGX': 'USh',
  'RWF': 'FRw',
  'MWK': 'MK',
  'MZN': 'MT',
  'ZMW': 'ZK',
  'CDF': 'FC',
  'GNF': 'FG',
  'SLE': 'Le',
  'MAD': 'DH',
  'DZD': 'DA',
  'TND': 'DT',
  'EGP': 'E£',
  'ZAR': 'R',
  'BRL': 'R\$',
  'MXN': 'MX\$',
  'ARS': 'AR\$',
  'CLP': 'CL\$',
  'COP': 'COL\$',
  'PEN': 'S/',
  'TRY': '₺',
  'RUB': '₽',
  'UAH': '₴',
  'PLN': 'zł',
  'CZK': 'Kč',
  'HUF': 'Ft',
  'RON': 'lei',
  'BGN': 'лв',
  'RSD': 'дин',
  'AED': 'د.إ',
  'SAR': '﷼',
  'QAR': 'ر.ق',
  'KWD': 'د.ك',
  'BHD': 'د.ب',
  'OMR': 'ر.ع',
  'JOD': 'د.أ',
  'ILS': '₪',
  'XPF': 'F',
  'XCD': 'EC\$',
  'TTD': 'TT\$',
  'JMD': 'J\$',
  'DOP': 'RD\$',
  'GTQ': 'Q',
  'CRC': '₡',
  'PAB': 'B/.',
  'UYU': '\$U',
  'VES': 'Bs',
  'BOB': 'Bs',
  'PYG': '₲',
  'NIO': 'C\$',
  'HNL': 'L',
};

/// Un pays du monde, avec sa devise locale et sa route de paiement.
class PaysMonde {
  const PaysMonde(
    this.code,
    this.nom,
    this.drapeau,
    this.indicatif,
    this.devise,
    this.region, {
    this.sasPay = false,
  });

  /// Code ISO 3166-1 alpha-2 (ex. « MA »).
  final String code;
  final String nom;

  /// Drapeau emoji (affiché tel quel).
  final String drapeau;

  /// Indicatif téléphonique international (ex. « +212 »).
  final String indicatif;

  /// Devise locale réelle (ex. « MAD »).
  final String devise;
  final Region region;

  /// Le pays est-il encaissé par SasPay dans sa devise locale ?
  final bool sasPay;

  /// Devise de facturation Paddle : EUR (Europe + Maghreb) ou USD.
  String get devisePaddle =>
      (region == Region.europe || region == Region.afriqueNord) ? 'EUR' : 'USD';

  /// Devise réellement facturée pour ce pays.
  String get deviseFacturation => sasPay ? devise : devisePaddle;

  /// Taux : 1 XOF = X devise locale.
  double get taux => tauxXof[devise] ?? 1;

  bool get aDecimales => !devisesEntieres.contains(devise);

  bool get viaSasPay => sasPay;

  String get libelleRoute => sasPay ? 'SasPay · $devise' : 'Paddle · $devisePaddle';

  /// « 🇲🇦 Maroc · MAD » — utilisé dans les listes.
  String get libelleComplet => '$drapeau $nom · $devise';

  @override
  String toString() => nom;
}

const PaysMonde _afriqueDuSud = PaysMonde('ZA', 'Afrique du Sud', '🇿🇦', '+27', 'ZAR', Region.afriqueAustrale);
const PaysMonde _albanie = PaysMonde('AL', 'Albanie', '🇦🇱', '+355', 'ALL', Region.europe);
const PaysMonde _algerie = PaysMonde('DZ', 'Algérie', '🇩🇿', '+213', 'DZD', Region.afriqueNord);
const PaysMonde _allemagne = PaysMonde('DE', 'Allemagne', '🇩🇪', '+49', 'EUR', Region.europe);
const PaysMonde _andorre = PaysMonde('AD', 'Andorre', '🇦🇩', '+376', 'EUR', Region.europe);
const PaysMonde _angola = PaysMonde('AO', 'Angola', '🇦🇴', '+244', 'AOA', Region.afriqueAustrale);
const PaysMonde _arabieSaoudite = PaysMonde('SA', 'Arabie saoudite', '🇸🇦', '+966', 'SAR', Region.moyenOrient);
const PaysMonde _argentine = PaysMonde('AR', 'Argentine', '🇦🇷', '+54', 'ARS', Region.ameriqueLatine);
const PaysMonde _armenie = PaysMonde('AM', 'Arménie', '🇦🇲', '+374', 'AMD', Region.asie);
const PaysMonde _australie = PaysMonde('AU', 'Australie', '🇦🇺', '+61', 'AUD', Region.oceanie);
const PaysMonde _autriche = PaysMonde('AT', 'Autriche', '🇦🇹', '+43', 'EUR', Region.europe);
const PaysMonde _azerbaidjan = PaysMonde('AZ', 'Azerbaïdjan', '🇦🇿', '+994', 'AZN', Region.asie);
const PaysMonde _bahamas = PaysMonde('BS', 'Bahamas', '🇧🇸', '+1242', 'BSD', Region.ameriqueNord);
const PaysMonde _bahrein = PaysMonde('BH', 'Bahreïn', '🇧🇭', '+973', 'BHD', Region.moyenOrient);
const PaysMonde _bangladesh = PaysMonde('BD', 'Bangladesh', '🇧🇩', '+880', 'BDT', Region.asie);
const PaysMonde _barbade = PaysMonde('BB', 'Barbade', '🇧🇧', '+1246', 'BBD', Region.ameriqueNord);
const PaysMonde _belgique = PaysMonde('BE', 'Belgique', '🇧🇪', '+32', 'EUR', Region.europe);
const PaysMonde _belize = PaysMonde('BZ', 'Belize', '🇧🇿', '+501', 'BZD', Region.ameriqueNord);
const PaysMonde _benin = PaysMonde('BJ', 'Bénin', '🇧🇯', '+229', 'XOF', Region.afriqueOuest, sasPay: true);
const PaysMonde _bhoutan = PaysMonde('BT', 'Bhoutan', '🇧🇹', '+975', 'BTN', Region.asie);
const PaysMonde _bielorussie = PaysMonde('BY', 'Biélorussie', '🇧🇾', '+375', 'BYN', Region.europe);
const PaysMonde _bolivie = PaysMonde('BO', 'Bolivie', '🇧🇴', '+591', 'BOB', Region.ameriqueLatine);
const PaysMonde _bosnie = PaysMonde('BA', 'Bosnie-Herzégovine', '🇧🇦', '+387', 'BAM', Region.europe);
const PaysMonde _botswana = PaysMonde('BW', 'Botswana', '🇧🇼', '+267', 'BWP', Region.afriqueAustrale);
const PaysMonde _bresil = PaysMonde('BR', 'Brésil', '🇧🇷', '+55', 'BRL', Region.ameriqueLatine);
const PaysMonde _brunei = PaysMonde('BN', 'Brunei', '🇧🇳', '+673', 'BND', Region.asie);
const PaysMonde _bulgarie = PaysMonde('BG', 'Bulgarie', '🇧🇬', '+359', 'BGN', Region.europe);
const PaysMonde _burkina = PaysMonde('BF', 'Burkina Faso', '🇧🇫', '+226', 'XOF', Region.afriqueOuest, sasPay: true);
const PaysMonde _burundi = PaysMonde('BI', 'Burundi', '🇧🇮', '+257', 'BIF', Region.afriqueEst);
const PaysMonde _cambodge = PaysMonde('KH', 'Cambodge', '🇰🇭', '+855', 'KHR', Region.asie);
const PaysMonde _cameroun = PaysMonde('CM', 'Cameroun', '🇨🇲', '+237', 'XAF', Region.afriqueCentrale, sasPay: true);
const PaysMonde _canada = PaysMonde('CA', 'Canada', '🇨🇦', '+1', 'CAD', Region.ameriqueNord);
const PaysMonde _capVert = PaysMonde('CV', 'Cap-Vert', '🇨🇻', '+238', 'CVE', Region.afriqueOuest);
const PaysMonde _centrafrique = PaysMonde('CF', 'Centrafrique', '🇨🇫', '+236', 'XAF', Region.afriqueCentrale);
const PaysMonde _chili = PaysMonde('CL', 'Chili', '🇨🇱', '+56', 'CLP', Region.ameriqueLatine);
const PaysMonde _chine = PaysMonde('CN', 'Chine', '🇨🇳', '+86', 'CNY', Region.asie);
const PaysMonde _chypre = PaysMonde('CY', 'Chypre', '🇨🇾', '+357', 'EUR', Region.europe);
const PaysMonde _colombie = PaysMonde('CO', 'Colombie', '🇨🇴', '+57', 'COP', Region.ameriqueLatine);
const PaysMonde _comores = PaysMonde('KM', 'Comores', '🇰🇲', '+269', 'KMF', Region.afriqueEst);
const PaysMonde _congoBrazzaville = PaysMonde('CG', 'Congo-Brazzaville', '🇨🇬', '+242', 'XAF', Region.afriqueCentrale, sasPay: true);
const PaysMonde _congoKinshasa = PaysMonde('CD', 'Congo-Kinshasa', '🇨🇩', '+243', 'CDF', Region.afriqueCentrale, sasPay: true);
const PaysMonde _coreeDuNord = PaysMonde('KP', 'Corée du Nord', '🇰🇵', '+850', 'KPW', Region.asie);
const PaysMonde _coreeDuSud = PaysMonde('KR', 'Corée du Sud', '🇰🇷', '+82', 'KRW', Region.asie);
const PaysMonde _costaRica = PaysMonde('CR', 'Costa Rica', '🇨🇷', '+506', 'CRC', Region.ameriqueLatine);
const PaysMonde _coteIvoire = PaysMonde('CI', 'Côte d\'Ivoire', '🇨🇮', '+225', 'XOF', Region.afriqueOuest, sasPay: true);
const PaysMonde _croatie = PaysMonde('HR', 'Croatie', '🇭🇷', '+385', 'EUR', Region.europe);
const PaysMonde _cuba = PaysMonde('CU', 'Cuba', '🇨🇺', '+53', 'CUP', Region.ameriqueLatine);
const PaysMonde _danemark = PaysMonde('DK', 'Danemark', '🇩🇰', '+45', 'DKK', Region.europe);
const PaysMonde _djibouti = PaysMonde('DJ', 'Djibouti', '🇩🇯', '+253', 'DJF', Region.afriqueEst);
const PaysMonde _dominique = PaysMonde('DM', 'Dominique', '🇩🇲', '+1767', 'XCD', Region.ameriqueNord);
const PaysMonde _egypte = PaysMonde('EG', 'Égypte', '🇪🇬', '+20', 'EGP', Region.afriqueNord);
const PaysMonde _emirats = PaysMonde('AE', 'Émirats arabes unis', '🇦🇪', '+971', 'AED', Region.moyenOrient);
const PaysMonde _equateur = PaysMonde('EC', 'Équateur', '🇪🇨', '+593', 'USD', Region.ameriqueLatine);
const PaysMonde _erythree = PaysMonde('ER', 'Érythrée', '🇪🇷', '+291', 'ERN', Region.afriqueEst);
const PaysMonde _espagne = PaysMonde('ES', 'Espagne', '🇪🇸', '+34', 'EUR', Region.europe);
const PaysMonde _estonie = PaysMonde('EE', 'Estonie', '🇪🇪', '+372', 'EUR', Region.europe);
const PaysMonde _eswatini = PaysMonde('SZ', 'Eswatini', '🇸🇿', '+268', 'SZL', Region.afriqueAustrale);
const PaysMonde _etatsUnis = PaysMonde('US', 'États-Unis', '🇺🇸', '+1', 'USD', Region.ameriqueNord);
const PaysMonde _ethiopie = PaysMonde('ET', 'Éthiopie', '🇪🇹', '+251', 'ETB', Region.afriqueEst);
const PaysMonde _fidji = PaysMonde('FJ', 'Fidji', '🇫🇯', '+679', 'FJD', Region.oceanie);
const PaysMonde _finlande = PaysMonde('FI', 'Finlande', '🇫🇮', '+358', 'EUR', Region.europe);
const PaysMonde _france = PaysMonde('FR', 'France', '🇫🇷', '+33', 'EUR', Region.europe);
const PaysMonde _gabon = PaysMonde('GA', 'Gabon', '🇬🇦', '+241', 'XAF', Region.afriqueCentrale, sasPay: true);
const PaysMonde _gambie = PaysMonde('GM', 'Gambie', '🇬🇲', '+220', 'GMD', Region.afriqueOuest);
const PaysMonde _georgie = PaysMonde('GE', 'Géorgie', '🇬🇪', '+995', 'GEL', Region.asie);
const PaysMonde _ghana = PaysMonde('GH', 'Ghana', '🇬🇭', '+233', 'GHS', Region.afriqueOuest, sasPay: true);
const PaysMonde _grece = PaysMonde('GR', 'Grèce', '🇬🇷', '+30', 'EUR', Region.europe);
const PaysMonde _grenade = PaysMonde('GD', 'Grenade', '🇬🇩', '+1473', 'XCD', Region.ameriqueNord);
const PaysMonde _guatemala = PaysMonde('GT', 'Guatemala', '🇬🇹', '+502', 'GTQ', Region.ameriqueLatine);
const PaysMonde _guinee = PaysMonde('GN', 'Guinée', '🇬🇳', '+224', 'GNF', Region.afriqueOuest, sasPay: true);
const PaysMonde _guineeBissau = PaysMonde('GW', 'Guinée-Bissau', '🇬🇼', '+245', 'XOF', Region.afriqueOuest);
const PaysMonde _guineeEquatoriale = PaysMonde('GQ', 'Guinée équatoriale', '🇬🇶', '+240', 'XAF', Region.afriqueCentrale);
const PaysMonde _guyana = PaysMonde('GY', 'Guyana', '🇬🇾', '+592', 'GYD', Region.ameriqueLatine);
const PaysMonde _haiti = PaysMonde('HT', 'Haïti', '🇭🇹', '+509', 'HTG', Region.ameriqueNord);
const PaysMonde _honduras = PaysMonde('HN', 'Honduras', '🇭🇳', '+504', 'HNL', Region.ameriqueLatine);
const PaysMonde _hongrie = PaysMonde('HU', 'Hongrie', '🇭🇺', '+36', 'HUF', Region.europe);
const PaysMonde _inde = PaysMonde('IN', 'Inde', '🇮🇳', '+91', 'INR', Region.asie, sasPay: true);
const PaysMonde _indonesie = PaysMonde('ID', 'Indonésie', '🇮🇩', '+62', 'IDR', Region.asie);
const PaysMonde _irak = PaysMonde('IQ', 'Irak', '🇮🇶', '+964', 'IQD', Region.moyenOrient);
const PaysMonde _iran = PaysMonde('IR', 'Iran', '🇮🇷', '+98', 'IRR', Region.moyenOrient);
const PaysMonde _irlande = PaysMonde('IE', 'Irlande', '🇮🇪', '+353', 'EUR', Region.europe);
const PaysMonde _islande = PaysMonde('IS', 'Islande', '🇮🇸', '+354', 'ISK', Region.europe);
const PaysMonde _israel = PaysMonde('IL', 'Israël', '🇮🇱', '+972', 'ILS', Region.moyenOrient);
const PaysMonde _italie = PaysMonde('IT', 'Italie', '🇮🇹', '+39', 'EUR', Region.europe);
const PaysMonde _jamaique = PaysMonde('JM', 'Jamaïque', '🇯🇲', '+1876', 'JMD', Region.ameriqueNord);
const PaysMonde _japon = PaysMonde('JP', 'Japon', '🇯🇵', '+81', 'JPY', Region.asie);
const PaysMonde _jordanie = PaysMonde('JO', 'Jordanie', '🇯🇴', '+962', 'JOD', Region.moyenOrient);
const PaysMonde _kazakhstan = PaysMonde('KZ', 'Kazakhstan', '🇰🇿', '+7', 'KZT', Region.asie);
const PaysMonde _kenya = PaysMonde('KE', 'Kenya', '🇰🇪', '+254', 'KES', Region.afriqueEst, sasPay: true);
const PaysMonde _kirghizistan = PaysMonde('KG', 'Kirghizistan', '🇰🇬', '+996', 'KGS', Region.asie);
const PaysMonde _kiribati = PaysMonde('KI', 'Kiribati', '🇰🇮', '+686', 'AUD', Region.oceanie);
const PaysMonde _koweit = PaysMonde('KW', 'Koweït', '🇰🇼', '+965', 'KWD', Region.moyenOrient);
const PaysMonde _kosovo = PaysMonde('XK', 'Kosovo', '🇽🇰', '+383', 'EUR', Region.europe);
const PaysMonde _laos = PaysMonde('LA', 'Laos', '🇱🇦', '+856', 'LAK', Region.asie);
const PaysMonde _lesotho = PaysMonde('LS', 'Lesotho', '🇱🇸', '+266', 'LSL', Region.afriqueAustrale);
const PaysMonde _lettonie = PaysMonde('LV', 'Lettonie', '🇱🇻', '+371', 'EUR', Region.europe);
const PaysMonde _liban = PaysMonde('LB', 'Liban', '🇱🇧', '+961', 'LBP', Region.moyenOrient);
const PaysMonde _liberia = PaysMonde('LR', 'Liberia', '🇱🇷', '+231', 'LRD', Region.afriqueOuest);
const PaysMonde _libye = PaysMonde('LY', 'Libye', '🇱🇾', '+218', 'LYD', Region.afriqueNord);
const PaysMonde _liechtenstein = PaysMonde('LI', 'Liechtenstein', '🇱🇮', '+423', 'CHF', Region.europe);
const PaysMonde _lituanie = PaysMonde('LT', 'Lituanie', '🇱🇹', '+370', 'EUR', Region.europe);
const PaysMonde _luxembourg = PaysMonde('LU', 'Luxembourg', '🇱🇺', '+352', 'EUR', Region.europe);
const PaysMonde _macedoine = PaysMonde('MK', 'Macédoine du Nord', '🇲🇰', '+389', 'MKD', Region.europe);
const PaysMonde _madagascar = PaysMonde('MG', 'Madagascar', '🇲🇬', '+261', 'MGA', Region.afriqueEst);
const PaysMonde _malaisie = PaysMonde('MY', 'Malaisie', '🇲🇾', '+60', 'MYR', Region.asie);
const PaysMonde _malawi = PaysMonde('MW', 'Malawi', '🇲🇼', '+265', 'MWK', Region.afriqueEst, sasPay: true);
const PaysMonde _maldives = PaysMonde('MV', 'Maldives', '🇲🇻', '+960', 'MVR', Region.asie);
const PaysMonde _mali = PaysMonde('ML', 'Mali', '🇲🇱', '+223', 'XOF', Region.afriqueOuest, sasPay: true);
const PaysMonde _malte = PaysMonde('MT', 'Malte', '🇲🇹', '+356', 'EUR', Region.europe);
const PaysMonde _maroc = PaysMonde('MA', 'Maroc', '🇲🇦', '+212', 'MAD', Region.afriqueNord);
const PaysMonde _marshall = PaysMonde('MH', 'Îles Marshall', '🇲🇭', '+692', 'USD', Region.oceanie);
const PaysMonde _maurice = PaysMonde('MU', 'Maurice', '🇲🇺', '+230', 'MUR', Region.afriqueEst);
const PaysMonde _mauritanie = PaysMonde('MR', 'Mauritanie', '🇲🇷', '+222', 'MRU', Region.afriqueOuest);
const PaysMonde _mexique = PaysMonde('MX', 'Mexique', '🇲🇽', '+52', 'MXN', Region.ameriqueLatine);
const PaysMonde _micronesie = PaysMonde('FM', 'Micronésie', '🇫🇲', '+691', 'USD', Region.oceanie);
const PaysMonde _moldavie = PaysMonde('MD', 'Moldavie', '🇲🇩', '+373', 'MDL', Region.europe);
const PaysMonde _monaco = PaysMonde('MC', 'Monaco', '🇲🇨', '+377', 'EUR', Region.europe);
const PaysMonde _mongolie = PaysMonde('MN', 'Mongolie', '🇲🇳', '+976', 'MNT', Region.asie);
const PaysMonde _montenegro = PaysMonde('ME', 'Monténégro', '🇲🇪', '+382', 'EUR', Region.europe);
const PaysMonde _mozambique = PaysMonde('MZ', 'Mozambique', '🇲🇿', '+258', 'MZN', Region.afriqueEst, sasPay: true);
const PaysMonde _myanmar = PaysMonde('MM', 'Birmanie', '🇲🇲', '+95', 'MMK', Region.asie);
const PaysMonde _namibie = PaysMonde('NA', 'Namibie', '🇳🇦', '+264', 'NAD', Region.afriqueAustrale);
const PaysMonde _nauru = PaysMonde('NR', 'Nauru', '🇳🇷', '+674', 'AUD', Region.oceanie);
const PaysMonde _nepal = PaysMonde('NP', 'Népal', '🇳🇵', '+977', 'NPR', Region.asie);
const PaysMonde _nicaragua = PaysMonde('NI', 'Nicaragua', '🇳🇮', '+505', 'NIO', Region.ameriqueLatine);
const PaysMonde _niger = PaysMonde('NE', 'Niger', '🇳🇪', '+227', 'XOF', Region.afriqueOuest, sasPay: true);
const PaysMonde _nigeria = PaysMonde('NG', 'Nigeria', '🇳🇬', '+234', 'NGN', Region.afriqueOuest, sasPay: true);
const PaysMonde _norvege = PaysMonde('NO', 'Norvège', '🇳🇴', '+47', 'NOK', Region.europe);
const PaysMonde _nouvelleZelande = PaysMonde('NZ', 'Nouvelle-Zélande', '🇳🇿', '+64', 'NZD', Region.oceanie);
const PaysMonde _oman = PaysMonde('OM', 'Oman', '🇴🇲', '+968', 'OMR', Region.moyenOrient);
const PaysMonde _ouganda = PaysMonde('UG', 'Ouganda', '🇺🇬', '+256', 'UGX', Region.afriqueEst, sasPay: true);
const PaysMonde _ouzbekistan = PaysMonde('UZ', 'Ouzbékistan', '🇺🇿', '+998', 'UZS', Region.asie);
const PaysMonde _pakistan = PaysMonde('PK', 'Pakistan', '🇵🇰', '+92', 'PKR', Region.asie);
const PaysMonde _palaos = PaysMonde('PW', 'Palaos', '🇵🇼', '+680', 'USD', Region.oceanie);
const PaysMonde _palestine = PaysMonde('PS', 'Palestine', '🇵🇸', '+970', 'ILS', Region.moyenOrient);
const PaysMonde _panama = PaysMonde('PA', 'Panama', '🇵🇦', '+507', 'PAB', Region.ameriqueLatine);
const PaysMonde _papouasie = PaysMonde('PG', 'Papouasie-Nouvelle-Guinée', '🇵🇬', '+675', 'PGK', Region.oceanie);
const PaysMonde _paraguay = PaysMonde('PY', 'Paraguay', '🇵🇾', '+595', 'PYG', Region.ameriqueLatine);
const PaysMonde _paysBas = PaysMonde('NL', 'Pays-Bas', '🇳🇱', '+31', 'EUR', Region.europe);
const PaysMonde _perou = PaysMonde('PE', 'Pérou', '🇵🇪', '+51', 'PEN', Region.ameriqueLatine);
const PaysMonde _philippines = PaysMonde('PH', 'Philippines', '🇵🇭', '+63', 'PHP', Region.asie);
const PaysMonde _pologne = PaysMonde('PL', 'Pologne', '🇵🇱', '+48', 'PLN', Region.europe);
const PaysMonde _portugal = PaysMonde('PT', 'Portugal', '🇵🇹', '+351', 'EUR', Region.europe);
const PaysMonde _qatar = PaysMonde('QA', 'Qatar', '🇶🇦', '+974', 'QAR', Region.moyenOrient);
const PaysMonde _republiqueDominicaine = PaysMonde('DO', 'République dominicaine', '🇩🇴', '+1809', 'DOP', Region.ameriqueNord);
const PaysMonde _republiqueTcheque = PaysMonde('CZ', 'Tchéquie', '🇨🇿', '+420', 'CZK', Region.europe);
const PaysMonde _roumanie = PaysMonde('RO', 'Roumanie', '🇷🇴', '+40', 'RON', Region.europe);
const PaysMonde _royaumeUni = PaysMonde('GB', 'Royaume-Uni', '🇬🇧', '+44', 'GBP', Region.europe);
const PaysMonde _russie = PaysMonde('RU', 'Russie', '🇷🇺', '+7', 'RUB', Region.europe);
const PaysMonde _rwanda = PaysMonde('RW', 'Rwanda', '🇷🇼', '+250', 'RWF', Region.afriqueEst, sasPay: true);
const PaysMonde _saintChristophe = PaysMonde('KN', 'Saint-Christophe-et-Niévès', '🇰🇳', '+1869', 'XCD', Region.ameriqueNord);
const PaysMonde _sainteLucie = PaysMonde('LC', 'Sainte-Lucie', '🇱🇨', '+1758', 'XCD', Region.ameriqueNord);
const PaysMonde _saintVincent = PaysMonde('VC', 'Saint-Vincent-et-les-Grenadines', '🇻🇨', '+1784', 'XCD', Region.ameriqueNord);
const PaysMonde _salvador = PaysMonde('SV', 'Salvador', '🇸🇻', '+503', 'USD', Region.ameriqueLatine);
const PaysMonde _samoa = PaysMonde('WS', 'Samoa', '🇼🇸', '+685', 'WST', Region.oceanie);
const PaysMonde _saoTome = PaysMonde('ST', 'Sao Tomé-et-Principe', '🇸🇹', '+239', 'STN', Region.afriqueCentrale);
const PaysMonde _senegal = PaysMonde('SN', 'Sénégal', '🇸🇳', '+221', 'XOF', Region.afriqueOuest, sasPay: true);
const PaysMonde _serbie = PaysMonde('RS', 'Serbie', '🇷🇸', '+381', 'RSD', Region.europe);
const PaysMonde _seychelles = PaysMonde('SC', 'Seychelles', '🇸🇨', '+248', 'SCR', Region.afriqueEst);
const PaysMonde _sierraLeone = PaysMonde('SL', 'Sierra Leone', '🇸🇱', '+232', 'SLE', Region.afriqueOuest, sasPay: true);
const PaysMonde _singapour = PaysMonde('SG', 'Singapour', '🇸🇬', '+65', 'SGD', Region.asie);
const PaysMonde _slovaquie = PaysMonde('SK', 'Slovaquie', '🇸🇰', '+421', 'EUR', Region.europe);
const PaysMonde _slovenie = PaysMonde('SI', 'Slovénie', '🇸🇮', '+386', 'EUR', Region.europe);
const PaysMonde _somalie = PaysMonde('SO', 'Somalie', '🇸🇴', '+252', 'SOS', Region.afriqueEst);
const PaysMonde _soudan = PaysMonde('SD', 'Soudan', '🇸🇩', '+249', 'SDG', Region.afriqueNord);
const PaysMonde _soudanDuSud = PaysMonde('SS', 'Soudan du Sud', '🇸🇸', '+211', 'SSP', Region.afriqueEst);
const PaysMonde _sriLanka = PaysMonde('LK', 'Sri Lanka', '🇱🇰', '+94', 'LKR', Region.asie);
const PaysMonde _suede = PaysMonde('SE', 'Suède', '🇸🇪', '+46', 'SEK', Region.europe);
const PaysMonde _suisse = PaysMonde('CH', 'Suisse', '🇨🇭', '+41', 'CHF', Region.europe);
const PaysMonde _suriname = PaysMonde('SR', 'Suriname', '🇸🇷', '+597', 'SRD', Region.ameriqueLatine);
const PaysMonde _syrie = PaysMonde('SY', 'Syrie', '🇸🇾', '+963', 'SYP', Region.moyenOrient);
const PaysMonde _tadjikistan = PaysMonde('TJ', 'Tadjikistan', '🇹🇯', '+992', 'TJS', Region.asie);
const PaysMonde _taiwan = PaysMonde('TW', 'Taïwan', '🇹🇼', '+886', 'TWD', Region.asie);
const PaysMonde _tanzanie = PaysMonde('TZ', 'Tanzanie', '🇹🇿', '+255', 'TZS', Region.afriqueEst, sasPay: true);
const PaysMonde _tchad = PaysMonde('TD', 'Tchad', '🇹🇩', '+235', 'XAF', Region.afriqueCentrale);
const PaysMonde _thailande = PaysMonde('TH', 'Thaïlande', '🇹🇭', '+66', 'THB', Region.asie);
const PaysMonde _timor = PaysMonde('TL', 'Timor oriental', '🇹🇱', '+670', 'USD', Region.asie);
const PaysMonde _togo = PaysMonde('TG', 'Togo', '🇹🇬', '+228', 'XOF', Region.afriqueOuest, sasPay: true);
const PaysMonde _tonga = PaysMonde('TO', 'Tonga', '🇹🇴', '+676', 'TOP', Region.oceanie);
const PaysMonde _trinite = PaysMonde('TT', 'Trinité-et-Tobago', '🇹🇹', '+1868', 'TTD', Region.ameriqueNord);
const PaysMonde _tunisie = PaysMonde('TN', 'Tunisie', '🇹🇳', '+216', 'TND', Region.afriqueNord);
const PaysMonde _turkmenistan = PaysMonde('TM', 'Turkménistan', '🇹🇲', '+993', 'TMT', Region.asie);
const PaysMonde _turquie = PaysMonde('TR', 'Turquie', '🇹🇷', '+90', 'TRY', Region.moyenOrient);
const PaysMonde _tuvalu = PaysMonde('TV', 'Tuvalu', '🇹🇻', '+688', 'AUD', Region.oceanie);
const PaysMonde _ukraine = PaysMonde('UA', 'Ukraine', '🇺🇦', '+380', 'UAH', Region.europe);
const PaysMonde _uruguay = PaysMonde('UY', 'Uruguay', '🇺🇾', '+598', 'UYU', Region.ameriqueLatine);
const PaysMonde _vanuatu = PaysMonde('VU', 'Vanuatu', '🇻🇺', '+678', 'VUV', Region.oceanie);
const PaysMonde _vatican = PaysMonde('VA', 'Vatican', '🇻🇦', '+379', 'EUR', Region.europe);
const PaysMonde _venezuela = PaysMonde('VE', 'Venezuela', '🇻🇪', '+58', 'VES', Region.ameriqueLatine);
const PaysMonde _vietnam = PaysMonde('VN', 'Viêt Nam', '🇻🇳', '+84', 'VND', Region.asie);
const PaysMonde _yemen = PaysMonde('YE', 'Yémen', '🇾🇪', '+967', 'YER', Region.moyenOrient);
const PaysMonde _zambie = PaysMonde('ZM', 'Zambie', '🇿🇲', '+260', 'ZMW', Region.afriqueEst, sasPay: true);
const PaysMonde _zimbabwe = PaysMonde('ZW', 'Zimbabwe', '🇿🇼', '+263', 'ZWL', Region.afriqueAustrale);

// Territoires et régions francophones / fréquemment utilisés.
const PaysMonde _guadeloupe = PaysMonde('GP', 'Guadeloupe', '🇬🇵', '+590', 'EUR', Region.ameriqueLatine);
const PaysMonde _martinique = PaysMonde('MQ', 'Martinique', '🇲🇶', '+596', 'EUR', Region.ameriqueLatine);
const PaysMonde _guyane = PaysMonde('GF', 'Guyane française', '🇬🇫', '+594', 'EUR', Region.ameriqueLatine);
const PaysMonde _reunion = PaysMonde('RE', 'La Réunion', '🇷🇪', '+262', 'EUR', Region.afriqueEst);
const PaysMonde _mayotte = PaysMonde('YT', 'Mayotte', '🇾🇹', '+262', 'EUR', Region.afriqueEst);
const PaysMonde _nouvelleCaledonie = PaysMonde('NC', 'Nouvelle-Calédonie', '🇳🇨', '+687', 'XPF', Region.oceanie);
const PaysMonde _polynesie = PaysMonde('PF', 'Polynésie française', '🇵🇫', '+689', 'XPF', Region.oceanie);
const PaysMonde _groenland = PaysMonde('GL', 'Groenland', '🇬🇱', '+299', 'DKK', Region.ameriqueNord);
const PaysMonde _ilesFeroe = PaysMonde('FO', 'Îles Féroé', '🇫🇴', '+298', 'DKK', Region.europe);
const PaysMonde _gibraltar = PaysMonde('GI', 'Gibraltar', '🇬🇮', '+350', 'GIP', Region.europe);
const PaysMonde _jersey = PaysMonde('JE', 'Jersey', '🇯🇪', '+44', 'GBP', Region.europe);
const PaysMonde _guernesey = PaysMonde('GG', 'Guernesey', '🇬🇬', '+44', 'GBP', Region.europe);
const PaysMonde _ileDeMan = PaysMonde('IM', 'Île de Man', '🇮🇲', '+44', 'GBP', Region.europe);
const PaysMonde _portoRico = PaysMonde('PR', 'Porto Rico', '🇵🇷', '+1787', 'USD', Region.ameriqueNord);
const PaysMonde _ilesViergesUS = PaysMonde('VI', 'Îles Vierges américaines', '🇻🇮', '+1340', 'USD', Region.ameriqueNord);
const PaysMonde _guam = PaysMonde('GU', 'Guam', '🇬🇺', '+1671', 'USD', Region.oceanie);
const PaysMonde _bermudes = PaysMonde('BM', 'Bermudes', '🇧🇲', '+1441', 'BMD', Region.ameriqueNord);
const PaysMonde _ilesCaimans = PaysMonde('KY', 'Îles Caïmans', '🇰🇾', '+1345', 'KYD', Region.ameriqueNord);
const PaysMonde _aruba = PaysMonde('AW', 'Aruba', '🇦🇼', '+297', 'AWG', Region.ameriqueLatine);
const PaysMonde _curacao = PaysMonde('CW', 'Curaçao', '🇨🇼', '+599', 'XCG', Region.ameriqueLatine);
const PaysMonde _saintMartin = PaysMonde('SX', 'Saint-Martin', '🇸🇽', '+1721', 'XCG', Region.ameriqueLatine);
const PaysMonde _malouines = PaysMonde('FK', 'Îles Malouines', '🇫🇰', '+500', 'FKP', Region.ameriqueLatine);

/// Tous les pays du monde (ordre alphabétique français).
const List<PaysMonde> paysMonde = <PaysMonde>[
  _afriqueDuSud,
  _albanie,
  _algerie,
  _allemagne,
  _andorre,
  _angola,
  _arabieSaoudite,
  _argentine,
  _armenie,
  _australie,
  _autriche,
  _azerbaidjan,
  _bahamas,
  _bahrein,
  _bangladesh,
  _barbade,
  _belgique,
  _belize,
  _benin,
  _bhoutan,
  _bielorussie,
  _bolivie,
  _bosnie,
  _botswana,
  _bresil,
  _brunei,
  _bulgarie,
  _burkina,
  _burundi,
  _cambodge,
  _cameroun,
  _canada,
  _capVert,
  _centrafrique,
  _chili,
  _chine,
  _chypre,
  _colombie,
  _comores,
  _congoBrazzaville,
  _congoKinshasa,
  _coreeDuNord,
  _coreeDuSud,
  _costaRica,
  _coteIvoire,
  _croatie,
  _cuba,
  _danemark,
  _djibouti,
  _dominique,
  _egypte,
  _emirats,
  _equateur,
  _erythree,
  _espagne,
  _estonie,
  _eswatini,
  _etatsUnis,
  _ethiopie,
  _fidji,
  _finlande,
  _france,
  _gabon,
  _gambie,
  _georgie,
  _ghana,
  _grece,
  _grenade,
  _guatemala,
  _guinee,
  _guineeBissau,
  _guineeEquatoriale,
  _guyana,
  _haiti,
  _honduras,
  _hongrie,
  _inde,
  _indonesie,
  _irak,
  _iran,
  _irlande,
  _islande,
  _israel,
  _italie,
  _jamaique,
  _japon,
  _jordanie,
  _kazakhstan,
  _kenya,
  _kirghizistan,
  _kiribati,
  _koweit,
  _kosovo,
  _laos,
  _lesotho,
  _lettonie,
  _liban,
  _liberia,
  _libye,
  _liechtenstein,
  _lituanie,
  _luxembourg,
  _macedoine,
  _madagascar,
  _malaisie,
  _malawi,
  _maldives,
  _mali,
  _malte,
  _maroc,
  _marshall,
  _maurice,
  _mauritanie,
  _mexique,
  _micronesie,
  _moldavie,
  _monaco,
  _mongolie,
  _montenegro,
  _mozambique,
  _myanmar,
  _namibie,
  _nauru,
  _nepal,
  _nicaragua,
  _niger,
  _nigeria,
  _norvege,
  _nouvelleZelande,
  _oman,
  _ouganda,
  _ouzbekistan,
  _pakistan,
  _palaos,
  _palestine,
  _panama,
  _papouasie,
  _paraguay,
  _paysBas,
  _perou,
  _philippines,
  _pologne,
  _portugal,
  _qatar,
  _republiqueDominicaine,
  _republiqueTcheque,
  _roumanie,
  _royaumeUni,
  _russie,
  _rwanda,
  _saintChristophe,
  _sainteLucie,
  _saintVincent,
  _salvador,
  _samoa,
  _saoTome,
  _senegal,
  _serbie,
  _seychelles,
  _sierraLeone,
  _singapour,
  _slovaquie,
  _slovenie,
  _somalie,
  _soudan,
  _soudanDuSud,
  _sriLanka,
  _suede,
  _suisse,
  _suriname,
  _syrie,
  _tadjikistan,
  _taiwan,
  _tanzanie,
  _tchad,
  _thailande,
  _timor,
  _togo,
  _tonga,
  _trinite,
  _tunisie,
  _turkmenistan,
  _turquie,
  _tuvalu,
  _ukraine,
  _uruguay,
  _vanuatu,
  _vatican,
  _venezuela,
  _vietnam,
  _yemen,
  _zambie,
  _zimbabwe,
  // Territoires / régions francophones.
  _guadeloupe,
  _martinique,
  _guyane,
  _reunion,
  _mayotte,
  _nouvelleCaledonie,
  _polynesie,
  _groenland,
  _ilesFeroe,
  _gibraltar,
  _jersey,
  _guernesey,
  _ileDeMan,
  _portoRico,
  _ilesViergesUS,
  _guam,
  _bermudes,
  _ilesCaimans,
  _aruba,
  _curacao,
  _saintMartin,
  _malouines,
];

/// Pays par défaut (Maroc, marché historique de la marque).
const PaysMonde paysParDefaut = _maroc;

/// Les 23 pays actifs SasPay, dans l'ordre du contrat commercial.
const List<String> codesSasPay = <String>[
  'ML', 'SN', 'CI', 'BF', 'BJ', 'TG', 'NE',
  'CM', 'GA', 'CG',
  'CD', 'GN', 'NG', 'GH', 'SL', 'KE', 'UG', 'TZ', 'RW', 'MW', 'MZ', 'ZM', 'IN',
];

/// Retrouve un pays par son code ISO (jamais null : repli sur le Maroc).
PaysMonde paysParCode(String? code) {
  if (code == null || code.isEmpty) return paysParDefaut;
  final propre = code.toUpperCase();
  for (final pays in paysMonde) {
    if (pays.code == propre) return pays;
  }
  return paysParDefaut;
}

/// Liste des pays SasPay (pour les badges et les tests).
List<PaysMonde> get paysSasPay =>
    paysMonde.where((pays) => pays.sasPay).toList(growable: false);

/// Recherche insensible aux accents, au code, à la devise et à l'indicatif.
List<PaysMonde> rechercherPays(String requete) {
  final q = sansAccents(requete.trim().toLowerCase()).replaceAll('+', '');
  if (q.isEmpty) return paysMonde;
  return paysMonde.where((pays) {
    return sansAccents(pays.nom.toLowerCase()).contains(q) ||
        pays.code.toLowerCase().contains(q) ||
        pays.devise.toLowerCase().contains(q) ||
        pays.indicatif.replaceAll('+', '').contains(q);
  }).toList(growable: false);
}

/// Retire les accents les plus courants (recherche instantanée côté client).
String sansAccents(String texte) {
  const remplacements = <String, String>{
    'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a',
    'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i',
    'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o', 'õ': 'o',
    'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
    'ÿ': 'y', 'ñ': 'n', 'œ': 'oe', 'æ': 'ae', 'ß': 'ss',
  };
  final tampon = StringBuffer();
  for (final caractere in texte.split('')) {
    tampon.write(remplacements[caractere] ?? caractere);
  }
  return tampon.toString();
}
