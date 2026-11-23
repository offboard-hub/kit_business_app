// ============================================================================
//  RÉFÉRENTIEL MONDIAL DES PAYS, DEVISES ET ROUTES DE PAIEMENT — e-booklive
//
//  • 23 pays encaissés par SasPay dans leur devise locale (voir CODES_SASPAY).
//  • Tous les autres pays passent par Paddle : EUR pour l'Europe et le Maghreb,
//    USD partout ailleurs, avec une conversion locale purement indicative.
//  • Les taux sont exprimés en « 1 XOF = X devise ». Ils sont identiques à
//    `lib/core/countries.dart` (frontend) : toute modification doit être faite
//    dans les deux fichiers.
//
//  ⚠️ Le backend est seul juge du montant facturé : le client n'envoie jamais
//  de montant, il reçoit celui recalculé ici (via pricing.ts).
// ============================================================================

export type RoutePaiement = "saspay" | "paddle";

/** Zone géographique — sert uniquement à choisir la devise Paddle. */
export type Zone =
  | "afriqueNord"
  | "afriqueOuest"
  | "afriqueCentrale"
  | "afriqueEst"
  | "afriqueAustrale"
  | "europe"
  | "ameriqueNord"
  | "ameriqueLatine"
  | "asie"
  | "moyenOrient"
  | "oceanie";

export interface PaysMonde {
  /** Code ISO 3166-1 alpha-2 (ex. « MA »). */
  code: string;
  nom: string;
  drapeau: string;
  /** Indicatif téléphonique international (ex. « +212 »). */
  indicatif: string;
  /** Devise locale réelle (ex. « MAD »). */
  devise: string;
  zone: Zone;
  /** Le pays est-il encaissé par SasPay dans sa devise locale ? */
  sasPay: boolean;
}

// ----------------------------------------------------------------------------
//  1. TAUX DE CONVERSION (1 XOF = X devise) — miroir de lib/core/countries.dart
// ----------------------------------------------------------------------------
export const TAUX_XOF: Readonly<Record<string, number>> = {
  XOF: 1,
  XAF: 1,
  EUR: 0.00152449,
  USD: 0.00165,
  GBP: 0.00129,
  CHF: 0.00145,
  CAD: 0.00226,
  AUD: 0.0025,
  NZD: 0.00275,
  JPY: 0.247,
  CNY: 0.0118,
  HKD: 0.0129,
  SGD: 0.00222,
  KRW: 2.31,
  INR: 0.138,
  IDR: 26.4,
  MYR: 0.00743,
  PHP: 0.0956,
  THB: 0.0545,
  VND: 40.9,
  TWD: 0.0538,
  PKR: 0.459,
  BDT: 0.197,
  LKR: 0.495,
  NPR: 0.221,
  AFN: 0.118,
  AMD: 0.643,
  AZN: 0.00281,
  GEL: 0.00448,
  KZT: 0.86,
  KGS: 0.143,
  TJS: 0.018,
  TMT: 0.00578,
  UZS: 20.7,
  BYN: 0.0054,
  GYD: 0.345,
  MNT: 5.7,
  MMK: 3.47,
  KHR: 6.7,
  LAK: 36.3,
  BND: 0.00222,
  MVR: 0.0254,
  BTN: 0.138,
  ILS: 0.00615,
  JOD: 0.00117,
  LBP: 148,
  SYP: 21.8,
  IQD: 2.17,
  IRR: 69.3,
  SAR: 0.00619,
  AED: 0.00606,
  QAR: 0.00601,
  KWD: 0.000507,
  BHD: 0.000621,
  OMR: 0.000635,
  YER: 0.413,
  TRY: 0.056,
  RUB: 0.152,
  UAH: 0.068,
  PLN: 0.00655,
  CZK: 0.0383,
  HUF: 0.602,
  RON: 0.00759,
  BGN: 0.00298,
  RSD: 0.178,
  MKD: 0.0938,
  ALL: 0.155,
  BAM: 0.00298,
  MDL: 0.0295,
  ISK: 0.229,
  NOK: 0.0179,
  SEK: 0.0175,
  DKK: 0.01137,
  MAD: 0.0164,
  DZD: 0.222,
  TND: 0.00518,
  LYD: 0.00795,
  EGP: 0.081,
  CDF: 4.6,
  GNF: 14.3,
  NGN: 2.56,
  GHS: 0.0256,
  SLE: 0.0371,
  KES: 0.213,
  UGX: 5.69,
  TZS: 3.96,
  RWF: 2.05,
  MWK: 2.7,
  MZN: 0.105,
  ZMW: 0.0396,
  ZAR: 0.0295,
  NAD: 0.0295,
  SZL: 0.0295,
  LSL: 0.0295,
  BWP: 0.0225,
  AOA: 1.52,
  BIF: 4.8,
  DJF: 0.293,
  ERN: 0.0248,
  ETB: 0.222,
  GMD: 0.115,
  LRD: 0.32,
  MRU: 0.066,
  MUR: 0.077,
  CVE: 0.168,
  KMF: 0.746,
  MGA: 7.65,
  SCR: 0.0235,
  SOS: 0.943,
  SSP: 6.5,
  SDG: 0.99,
  STN: 0.0372,
  ZWL: 0.0436,
  ARS: 1.56,
  BOB: 0.0114,
  BRL: 0.0089,
  CLP: 1.57,
  COP: 6.6,
  CRC: 0.85,
  CUP: 0.0396,
  DOP: 0.098,
  GTQ: 0.0129,
  HNL: 0.0405,
  HTG: 0.216,
  JMD: 0.258,
  MXN: 0.03,
  NIO: 0.0608,
  PAB: 0.00165,
  PEN: 0.00626,
  PYG: 12.9,
  SRD: 0.058,
  TTD: 0.0112,
  UYU: 0.069,
  VES: 0.12,
  XCD: 0.00446,
  BSD: 0.00165,
  BBD: 0.0033,
  BZD: 0.00332,
  BMD: 0.00165,
  KYD: 0.00138,
  AWG: 0.00297,
  XCG: 0.00297,
  FKP: 0.00129,
  GIP: 0.00129,
  FJD: 0.00376,
  PGK: 0.0066,
  SBD: 0.0139,
  TOP: 0.0039,
  VUV: 0.197,
  WST: 0.0045,
  XPF: 0.182,
  KPW: 1.485,
};

/**
 * Devises affichées sans décimales (montants ronds).
 * Miroir exact de `devisesEntieres` dans lib/core/countries.dart.
 */
export const DEVISES_ENTIERES: ReadonlySet<string> = new Set([
  "XOF", "XAF", "CDF", "GNF", "UGX", "TZS", "RWF", "MWK", "MZN", "JPY",
  "KRW", "VND", "IDR", "CLP", "COP", "PYG", "KHR", "LAK", "MMK", "MNT",
  "UZS", "LBP", "IRR", "SYP", "ISK", "HUF", "NGN", "PKR", "LKR", "NPR",
  "BDT", "AFN", "AMD", "KZT", "KGS", "TJS", "XPF", "BYN", "GYD",
]);

/** Symboles d'affichage (repris du frontend pour des emails cohérents). */
export const SYMBOLES_DEVISES: Readonly<Record<string, string>> = {
  XOF: "FCFA",
  XAF: "FCFA",
  EUR: "€",
  USD: "$",
  GBP: "£",
  CHF: "CHF",
  CAD: "CA$",
  AUD: "A$",
  NZD: "NZ$",
  JPY: "¥",
  CNY: "¥",
  HKD: "HK$",
  SGD: "S$",
  KRW: "₩",
  INR: "₹",
  IDR: "Rp",
  MYR: "RM",
  PHP: "₱",
  THB: "฿",
  VND: "₫",
  TWD: "NT$",
  PKR: "₨",
  BDT: "৳",
  LKR: "Rs",
  NPR: "Rs",
  NGN: "₦",
  GHS: "GH₵",
  KES: "KSh",
  TZS: "TSh",
  UGX: "USh",
  RWF: "FRw",
  MWK: "MK",
  MZN: "MT",
  ZMW: "ZK",
  CDF: "FC",
  GNF: "FG",
  SLE: "Le",
  MAD: "DH",
  DZD: "DA",
  TND: "DT",
  EGP: "E£",
  ZAR: "R",
  BRL: "R$",
  MXN: "MX$",
  ARS: "AR$",
  CLP: "CL$",
  COP: "COL$",
  PEN: "S/",
  TRY: "₺",
  RUB: "₽",
  UAH: "₴",
  PLN: "zł",
  CZK: "Kč",
  HUF: "Ft",
  RON: "lei",
  BGN: "лв",
  RSD: "дин",
  AED: "د.إ",
  SAR: "﷼",
  QAR: "ر.ق",
  KWD: "د.ك",
  BHD: "د.ب",
  OMR: "ر.ع",
  JOD: "د.أ",
  ILS: "₪",
  XPF: "F",
  XCD: "EC$",
  TTD: "TT$",
  JMD: "J$",
  DOP: "RD$",
  GTQ: "Q",
  CRC: "₡",
  PAB: "B/.",
  UYU: "$U",
  VES: "Bs",
  BOB: "Bs",
  PYG: "₲",
  NIO: "C$",
  HNL: "L",
};

/** Taux d'une devise (1 XOF = X devise). Devise inconnue : 1 par sécurité. */
export function taux(devise: string): number {
  return TAUX_XOF[(devise ?? "").toUpperCase()] ?? 1;
}

/** Conversion brute depuis un montant en XOF (sans arrondi commercial). */
export function convertirDepuisXof(montantXof: number, devise: string): number {
  const montant = Number.isFinite(montantXof) ? montantXof : 0;
  return montant * taux(devise);
}

// ----------------------------------------------------------------------------
//  2. LES 23 PAYS SASPAY (ordre commercial du contrat)
// ----------------------------------------------------------------------------
export const CODES_SASPAY: readonly string[] = [
  "ML", "SN", "CI", "BF", "BJ", "TG", "NE",
  "CM", "GA", "CG",
  "CD", "GN", "NG", "GH", "SL", "KE", "UG", "TZ", "RW", "MW", "MZ", "ZM", "IN",
];

// ----------------------------------------------------------------------------
//  3. RÉFÉRENTIEL MONDIAL (code, nom FR, indicatif, devise locale, zone, SasPay)
//     Miroir de `paysMonde` dans lib/core/countries.dart.
// ----------------------------------------------------------------------------
type LignePays = [string, string, string, string, Zone, boolean?];

const LIGNES_PAYS: readonly LignePays[] = [
  ["ZA", "Afrique du Sud", "+27", "ZAR", "afriqueAustrale"],
  ["AL", "Albanie", "+355", "ALL", "europe"],
  ["DZ", "Algérie", "+213", "DZD", "afriqueNord"],
  ["DE", "Allemagne", "+49", "EUR", "europe"],
  ["AD", "Andorre", "+376", "EUR", "europe"],
  ["AO", "Angola", "+244", "AOA", "afriqueAustrale"],
  ["SA", "Arabie saoudite", "+966", "SAR", "moyenOrient"],
  ["AR", "Argentine", "+54", "ARS", "ameriqueLatine"],
  ["AM", "Arménie", "+374", "AMD", "asie"],
  ["AU", "Australie", "+61", "AUD", "oceanie"],
  ["AT", "Autriche", "+43", "EUR", "europe"],
  ["AZ", "Azerbaïdjan", "+994", "AZN", "asie"],
  ["BS", "Bahamas", "+1242", "BSD", "ameriqueNord"],
  ["BH", "Bahreïn", "+973", "BHD", "moyenOrient"],
  ["BD", "Bangladesh", "+880", "BDT", "asie"],
  ["BB", "Barbade", "+1246", "BBD", "ameriqueNord"],
  ["BE", "Belgique", "+32", "EUR", "europe"],
  ["BZ", "Belize", "+501", "BZD", "ameriqueNord"],
  ["BJ", "Bénin", "+229", "XOF", "afriqueOuest", true],
  ["BT", "Bhoutan", "+975", "BTN", "asie"],
  ["BY", "Biélorussie", "+375", "BYN", "europe"],
  ["BO", "Bolivie", "+591", "BOB", "ameriqueLatine"],
  ["BA", "Bosnie-Herzégovine", "+387", "BAM", "europe"],
  ["BW", "Botswana", "+267", "BWP", "afriqueAustrale"],
  ["BR", "Brésil", "+55", "BRL", "ameriqueLatine"],
  ["BN", "Brunei", "+673", "BND", "asie"],
  ["BG", "Bulgarie", "+359", "BGN", "europe"],
  ["BF", "Burkina Faso", "+226", "XOF", "afriqueOuest", true],
  ["BI", "Burundi", "+257", "BIF", "afriqueEst"],
  ["KH", "Cambodge", "+855", "KHR", "asie"],
  ["CM", "Cameroun", "+237", "XAF", "afriqueCentrale", true],
  ["CA", "Canada", "+1", "CAD", "ameriqueNord"],
  ["CV", "Cap-Vert", "+238", "CVE", "afriqueOuest"],
  ["CF", "Centrafrique", "+236", "XAF", "afriqueCentrale"],
  ["CL", "Chili", "+56", "CLP", "ameriqueLatine"],
  ["CN", "Chine", "+86", "CNY", "asie"],
  ["CY", "Chypre", "+357", "EUR", "europe"],
  ["CO", "Colombie", "+57", "COP", "ameriqueLatine"],
  ["KM", "Comores", "+269", "KMF", "afriqueEst"],
  ["CG", "Congo-Brazzaville", "+242", "XAF", "afriqueCentrale", true],
  ["CD", "Congo-Kinshasa", "+243", "CDF", "afriqueCentrale", true],
  ["KP", "Corée du Nord", "+850", "KPW", "asie"],
  ["KR", "Corée du Sud", "+82", "KRW", "asie"],
  ["CR", "Costa Rica", "+506", "CRC", "ameriqueLatine"],
  ["CI", "Côte d'Ivoire", "+225", "XOF", "afriqueOuest", true],
  ["HR", "Croatie", "+385", "EUR", "europe"],
  ["CU", "Cuba", "+53", "CUP", "ameriqueLatine"],
  ["DK", "Danemark", "+45", "DKK", "europe"],
  ["DJ", "Djibouti", "+253", "DJF", "afriqueEst"],
  ["DM", "Dominique", "+1767", "XCD", "ameriqueNord"],
  ["EG", "Égypte", "+20", "EGP", "afriqueNord"],
  ["AE", "Émirats arabes unis", "+971", "AED", "moyenOrient"],
  ["EC", "Équateur", "+593", "USD", "ameriqueLatine"],
  ["ER", "Érythrée", "+291", "ERN", "afriqueEst"],
  ["ES", "Espagne", "+34", "EUR", "europe"],
  ["EE", "Estonie", "+372", "EUR", "europe"],
  ["SZ", "Eswatini", "+268", "SZL", "afriqueAustrale"],
  ["US", "États-Unis", "+1", "USD", "ameriqueNord"],
  ["ET", "Éthiopie", "+251", "ETB", "afriqueEst"],
  ["FJ", "Fidji", "+679", "FJD", "oceanie"],
  ["FI", "Finlande", "+358", "EUR", "europe"],
  ["FR", "France", "+33", "EUR", "europe"],
  ["GA", "Gabon", "+241", "XAF", "afriqueCentrale", true],
  ["GM", "Gambie", "+220", "GMD", "afriqueOuest"],
  ["GE", "Géorgie", "+995", "GEL", "asie"],
  ["GH", "Ghana", "+233", "GHS", "afriqueOuest", true],
  ["GR", "Grèce", "+30", "EUR", "europe"],
  ["GD", "Grenade", "+1473", "XCD", "ameriqueNord"],
  ["GT", "Guatemala", "+502", "GTQ", "ameriqueLatine"],
  ["GN", "Guinée", "+224", "GNF", "afriqueOuest", true],
  ["GW", "Guinée-Bissau", "+245", "XOF", "afriqueOuest"],
  ["GQ", "Guinée équatoriale", "+240", "XAF", "afriqueCentrale"],
  ["GY", "Guyana", "+592", "GYD", "ameriqueLatine"],
  ["HT", "Haïti", "+509", "HTG", "ameriqueNord"],
  ["HN", "Honduras", "+504", "HNL", "ameriqueLatine"],
  ["HU", "Hongrie", "+36", "HUF", "europe"],
  ["IN", "Inde", "+91", "INR", "asie", true],
  ["ID", "Indonésie", "+62", "IDR", "asie"],
  ["IQ", "Irak", "+964", "IQD", "moyenOrient"],
  ["IR", "Iran", "+98", "IRR", "moyenOrient"],
  ["IE", "Irlande", "+353", "EUR", "europe"],
  ["IS", "Islande", "+354", "ISK", "europe"],
  ["IL", "Israël", "+972", "ILS", "moyenOrient"],
  ["IT", "Italie", "+39", "EUR", "europe"],
  ["JM", "Jamaïque", "+1876", "JMD", "ameriqueNord"],
  ["JP", "Japon", "+81", "JPY", "asie"],
  ["JO", "Jordanie", "+962", "JOD", "moyenOrient"],
  ["KZ", "Kazakhstan", "+7", "KZT", "asie"],
  ["KE", "Kenya", "+254", "KES", "afriqueEst", true],
  ["KG", "Kirghizistan", "+996", "KGS", "asie"],
  ["KI", "Kiribati", "+686", "AUD", "oceanie"],
  ["KW", "Koweït", "+965", "KWD", "moyenOrient"],
  ["XK", "Kosovo", "+383", "EUR", "europe"],
  ["LA", "Laos", "+856", "LAK", "asie"],
  ["LS", "Lesotho", "+266", "LSL", "afriqueAustrale"],
  ["LV", "Lettonie", "+371", "EUR", "europe"],
  ["LB", "Liban", "+961", "LBP", "moyenOrient"],
  ["LR", "Liberia", "+231", "LRD", "afriqueOuest"],
  ["LY", "Libye", "+218", "LYD", "afriqueNord"],
  ["LI", "Liechtenstein", "+423", "CHF", "europe"],
  ["LT", "Lituanie", "+370", "EUR", "europe"],
  ["LU", "Luxembourg", "+352", "EUR", "europe"],
  ["MK", "Macédoine du Nord", "+389", "MKD", "europe"],
  ["MG", "Madagascar", "+261", "MGA", "afriqueEst"],
  ["MY", "Malaisie", "+60", "MYR", "asie"],
  ["MW", "Malawi", "+265", "MWK", "afriqueEst", true],
  ["MV", "Maldives", "+960", "MVR", "asie"],
  ["ML", "Mali", "+223", "XOF", "afriqueOuest", true],
  ["MT", "Malte", "+356", "EUR", "europe"],
  ["MA", "Maroc", "+212", "MAD", "afriqueNord"],
  ["MH", "Îles Marshall", "+692", "USD", "oceanie"],
  ["MU", "Maurice", "+230", "MUR", "afriqueEst"],
  ["MR", "Mauritanie", "+222", "MRU", "afriqueOuest"],
  ["MX", "Mexique", "+52", "MXN", "ameriqueLatine"],
  ["FM", "Micronésie", "+691", "USD", "oceanie"],
  ["MD", "Moldavie", "+373", "MDL", "europe"],
  ["MC", "Monaco", "+377", "EUR", "europe"],
  ["MN", "Mongolie", "+976", "MNT", "asie"],
  ["ME", "Monténégro", "+382", "EUR", "europe"],
  ["MZ", "Mozambique", "+258", "MZN", "afriqueEst", true],
  ["MM", "Birmanie", "+95", "MMK", "asie"],
  ["NA", "Namibie", "+264", "NAD", "afriqueAustrale"],
  ["NR", "Nauru", "+674", "AUD", "oceanie"],
  ["NP", "Népal", "+977", "NPR", "asie"],
  ["NI", "Nicaragua", "+505", "NIO", "ameriqueLatine"],
  ["NE", "Niger", "+227", "XOF", "afriqueOuest", true],
  ["NG", "Nigeria", "+234", "NGN", "afriqueOuest", true],
  ["NO", "Norvège", "+47", "NOK", "europe"],
  ["NZ", "Nouvelle-Zélande", "+64", "NZD", "oceanie"],
  ["OM", "Oman", "+968", "OMR", "moyenOrient"],
  ["UG", "Ouganda", "+256", "UGX", "afriqueEst", true],
  ["UZ", "Ouzbékistan", "+998", "UZS", "asie"],
  ["PK", "Pakistan", "+92", "PKR", "asie"],
  ["PW", "Palaos", "+680", "USD", "oceanie"],
  ["PS", "Palestine", "+970", "ILS", "moyenOrient"],
  ["PA", "Panama", "+507", "PAB", "ameriqueLatine"],
  ["PG", "Papouasie-Nouvelle-Guinée", "+675", "PGK", "oceanie"],
  ["PY", "Paraguay", "+595", "PYG", "ameriqueLatine"],
  ["NL", "Pays-Bas", "+31", "EUR", "europe"],
  ["PE", "Pérou", "+51", "PEN", "ameriqueLatine"],
  ["PH", "Philippines", "+63", "PHP", "asie"],
  ["PL", "Pologne", "+48", "PLN", "europe"],
  ["PT", "Portugal", "+351", "EUR", "europe"],
  ["QA", "Qatar", "+974", "QAR", "moyenOrient"],
  ["DO", "République dominicaine", "+1809", "DOP", "ameriqueNord"],
  ["CZ", "Tchéquie", "+420", "CZK", "europe"],
  ["RO", "Roumanie", "+40", "RON", "europe"],
  ["GB", "Royaume-Uni", "+44", "GBP", "europe"],
  ["RU", "Russie", "+7", "RUB", "europe"],
  ["RW", "Rwanda", "+250", "RWF", "afriqueEst", true],
  ["KN", "Saint-Christophe-et-Niévès", "+1869", "XCD", "ameriqueNord"],
  ["LC", "Sainte-Lucie", "+1758", "XCD", "ameriqueNord"],
  ["VC", "Saint-Vincent-et-les-Grenadines", "+1784", "XCD", "ameriqueNord"],
  ["SV", "Salvador", "+503", "USD", "ameriqueLatine"],
  ["WS", "Samoa", "+685", "WST", "oceanie"],
  ["ST", "Sao Tomé-et-Principe", "+239", "STN", "afriqueCentrale"],
  ["SN", "Sénégal", "+221", "XOF", "afriqueOuest", true],
  ["RS", "Serbie", "+381", "RSD", "europe"],
  ["SC", "Seychelles", "+248", "SCR", "afriqueEst"],
  ["SL", "Sierra Leone", "+232", "SLE", "afriqueOuest", true],
  ["SG", "Singapour", "+65", "SGD", "asie"],
  ["SK", "Slovaquie", "+421", "EUR", "europe"],
  ["SI", "Slovénie", "+386", "EUR", "europe"],
  ["SO", "Somalie", "+252", "SOS", "afriqueEst"],
  ["SD", "Soudan", "+249", "SDG", "afriqueNord"],
  ["SS", "Soudan du Sud", "+211", "SSP", "afriqueEst"],
  ["LK", "Sri Lanka", "+94", "LKR", "asie"],
  ["SE", "Suède", "+46", "SEK", "europe"],
  ["CH", "Suisse", "+41", "CHF", "europe"],
  ["SR", "Suriname", "+597", "SRD", "ameriqueLatine"],
  ["SY", "Syrie", "+963", "SYP", "moyenOrient"],
  ["TJ", "Tadjikistan", "+992", "TJS", "asie"],
  ["TW", "Taïwan", "+886", "TWD", "asie"],
  ["TZ", "Tanzanie", "+255", "TZS", "afriqueEst", true],
  ["TD", "Tchad", "+235", "XAF", "afriqueCentrale"],
  ["TH", "Thaïlande", "+66", "THB", "asie"],
  ["TL", "Timor oriental", "+670", "USD", "asie"],
  ["TG", "Togo", "+228", "XOF", "afriqueOuest", true],
  ["TO", "Tonga", "+676", "TOP", "oceanie"],
  ["TT", "Trinité-et-Tobago", "+1868", "TTD", "ameriqueNord"],
  ["TN", "Tunisie", "+216", "TND", "afriqueNord"],
  ["TM", "Turkménistan", "+993", "TMT", "asie"],
  ["TR", "Turquie", "+90", "TRY", "moyenOrient"],
  ["TV", "Tuvalu", "+688", "AUD", "oceanie"],
  ["UA", "Ukraine", "+380", "UAH", "europe"],
  ["UY", "Uruguay", "+598", "UYU", "ameriqueLatine"],
  ["VU", "Vanuatu", "+678", "VUV", "oceanie"],
  ["VA", "Vatican", "+379", "EUR", "europe"],
  ["VE", "Venezuela", "+58", "VES", "ameriqueLatine"],
  ["VN", "Viêt Nam", "+84", "VND", "asie"],
  ["YE", "Yémen", "+967", "YER", "moyenOrient"],
  ["ZM", "Zambie", "+260", "ZMW", "afriqueEst", true],
  ["ZW", "Zimbabwe", "+263", "ZWL", "afriqueAustrale"],
  // Territoires et régions francophones / fréquemment utilisés.
  ["GP", "Guadeloupe", "+590", "EUR", "ameriqueLatine"],
  ["MQ", "Martinique", "+596", "EUR", "ameriqueLatine"],
  ["GF", "Guyane française", "+594", "EUR", "ameriqueLatine"],
  ["RE", "La Réunion", "+262", "EUR", "afriqueEst"],
  ["YT", "Mayotte", "+262", "EUR", "afriqueEst"],
  ["NC", "Nouvelle-Calédonie", "+687", "XPF", "oceanie"],
  ["PF", "Polynésie française", "+689", "XPF", "oceanie"],
  ["GL", "Groenland", "+299", "DKK", "ameriqueNord"],
  ["FO", "Îles Féroé", "+298", "DKK", "europe"],
  ["GI", "Gibraltar", "+350", "GIP", "europe"],
  ["JE", "Jersey", "+44", "GBP", "europe"],
  ["GG", "Guernesey", "+44", "GBP", "europe"],
  ["IM", "Île de Man", "+44", "GBP", "europe"],
  ["PR", "Porto Rico", "+1787", "USD", "ameriqueNord"],
  ["VI", "Îles Vierges américaines", "+1340", "USD", "ameriqueNord"],
  ["GU", "Guam", "+1671", "USD", "oceanie"],
  ["BM", "Bermudes", "+1441", "BMD", "ameriqueNord"],
  ["KY", "Îles Caïmans", "+1345", "KYD", "ameriqueNord"],
  ["AW", "Aruba", "+297", "AWG", "ameriqueLatine"],
  ["CW", "Curaçao", "+599", "XCG", "ameriqueLatine"],
  ["SX", "Saint-Martin", "+1721", "XCG", "ameriqueLatine"],
  ["FK", "Îles Malouines", "+500", "FKP", "ameriqueLatine"],
];

/** Emoji drapeau construit depuis le code ISO2 (ex. « MA » → 🇲🇦). */
export function drapeauPays(code: string): string {
  const propre = (code ?? "").trim().toUpperCase();
  if (!/^[A-Z]{2}$/.test(propre)) return "🌍";
  const base = 0x1f1e6;
  return String.fromCodePoint(
    base + (propre.charCodeAt(0) - 65),
    base + (propre.charCodeAt(1) - 65),
  );
}

/** Tous les pays du monde connus du backend (routage + devise + indicatif). */
export const PAYS_MONDE: readonly PaysMonde[] = LIGNES_PAYS.map(
  ([code, nom, indicatif, devise, zone, sasPay]) => ({
    code,
    nom,
    drapeau: drapeauPays(code),
    indicatif,
    devise,
    zone,
    sasPay: sasPay === true,
  }),
);

const PAR_CODE: ReadonlyMap<string, PaysMonde> = new Map(
  PAYS_MONDE.map((pays) => [pays.code, pays]),
);

/** Les 23 pays SasPay actifs (dérivés du référentiel mondial). */
export const PAYS_SASPAY: readonly PaysMonde[] = CODES_SASPAY.map(
  (code) => PAR_CODE.get(code),
).filter((pays): pays is PaysMonde => pays !== undefined);

// ----------------------------------------------------------------------------
//  4. HELPERS DE ROUTAGE ET D'AFFICHAGE
// ----------------------------------------------------------------------------

/** Un pays par son code ISO2 (insensible à la casse), ou undefined. */
export function paysMonde(code: string | null | undefined): PaysMonde | undefined {
  if (!code) return undefined;
  return PAR_CODE.get(code.trim().toUpperCase());
}

/** Un pays SasPay par son code ISO2, ou undefined si le pays n'est pas SasPay. */
export function paysSasPay(code: string | null | undefined): PaysMonde | undefined {
  const pays = paysMonde(code);
  return pays?.sasPay ? pays : undefined;
}

export function estPaysSasPay(code: string | null | undefined): boolean {
  return paysSasPay(code) !== undefined;
}

/** Route de paiement : SasPay pour les 23 pays, Paddle pour tous les autres. */
export function routePaiement(code: string | null | undefined): RoutePaiement {
  return estPaysSasPay(code) ? "saspay" : "paddle";
}

/** Devise locale réelle du pays (ex. MA → MAD). Défaut international : USD. */
export function deviseLocale(code: string | null | undefined): string {
  return paysMonde(code)?.devise ?? "USD";
}

/**
 * Devise de facturation Paddle : EUR pour l'Europe et le Maghreb
 * (Maroc, Algérie, Tunisie, Libye, Égypte, Soudan), USD sinon.
 */
export function devisePaddle(code: string | null | undefined): "EUR" | "USD" {
  const zone = paysMonde(code)?.zone;
  return zone === "europe" || zone === "afriqueNord" ? "EUR" : "USD";
}

/** Nom français du pays, ou le code brut si le pays est inconnu. */
export function paysLabel(code: string | null | undefined): string {
  return paysMonde(code)?.nom ?? (code ?? "").trim().toUpperCase();
}

/** Indicatif téléphonique (« +225 »), ou chaîne vide si inconnu. */
export function indicatifPays(code: string | null | undefined): string {
  return paysMonde(code)?.indicatif ?? "";
}

/** Devise réellement facturée : locale (SasPay) ou EUR/USD (Paddle). */
export function deviseFacturation(code: string | null | undefined): string {
  return estPaysSasPay(code) ? deviseLocale(code) : devisePaddle(code);
}
