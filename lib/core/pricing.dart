import 'package:flutter/material.dart';

import 'config.dart';
import 'countries.dart';
import 'models.dart';

/// ============================================================================
///  CATALOGUE, SECTEURS ET CONVERSION MULTIDEVISE — e-booklive
///
///  Prix de référence :
///   • Kits métiers : FCFA (XOF), tarifs existants conservés.
///   • Studio Live  : 10 USD (source de vérité), converti dans la devise locale.
///
///  Le montant réellement facturé est toujours recalculé par le serveur.
///  Ici, on affiche : prix local (SasPay) ou prix Paddle + conversion indicative.
/// ============================================================================

/// Secteur proposé à l'étape 1 de La Boutique.
class Secteur {
  const Secteur({
    required this.code,
    required this.label,
    required this.description,
    required this.emoji,
    required this.icone,
  });

  final String code;
  final String label;
  final String description;
  final String emoji;
  final IconData icone;
}

const List<Secteur> secteurs = <Secteur>[
  Secteur(
    code: 'ecommerce',
    label: 'E-commerce & Mode',
    description: 'Vêtements, accessoires, cosmétiques, livraison à domicile.',
    emoji: '🛍️',
    icone: Icons.shopping_bag_rounded,
  ),
  Secteur(
    code: 'immobilier',
    label: 'Immobilier',
    description: 'Vente, location, promotion immobilière et gestion locative.',
    emoji: '🏠',
    icone: Icons.apartment_rounded,
  ),
  Secteur(
    code: 'restauration',
    label: 'Restauration',
    description: 'Restaurant, maquis, fast-food, traiteur et livraison.',
    emoji: '🍲',
    icone: Icons.restaurant_rounded,
  ),
  Secteur(
    code: 'beaute',
    label: 'Beauté & Bien-être',
    description: 'Salon, spa, coiffure, onglerie, soins et cosmétiques.',
    emoji: '💅',
    icone: Icons.spa_rounded,
  ),
  Secteur(
    code: 'formation',
    label: 'Formation & Éducation',
    description: 'Cours, coaching, écoles, ateliers et contenus payants.',
    emoji: '🎓',
    icone: Icons.school_rounded,
  ),
  Secteur(
    code: 'transport',
    label: 'Transport & Logistique',
    description: 'VTC, livraison, fret, location de véhicules et tournées.',
    emoji: '🚚',
    icone: Icons.local_shipping_rounded,
  ),
  Secteur(
    code: 'services_b2b',
    label: 'Services B2B',
    description: 'Agence, conseil, freelance, marketing et sous-traitance.',
    emoji: '💼',
    icone: Icons.business_center_rounded,
  ),
  Secteur(
    code: 'sante',
    label: 'Santé',
    description: 'Clinique, pharmacie, laboratoire, cabinet et bien-être.',
    emoji: '🩺',
    icone: Icons.health_and_safety_rounded,
  ),
];

/// Secteur « Autre métier » : l'utilisateur écrit son activité.
const Secteur secteurAutre = Secteur(
  code: 'autre',
  label: 'Autre métier',
  description: 'Écrivez votre activité en quelques mots.',
  emoji: '✍️',
  icone: Icons.edit_note_rounded,
);

Secteur? secteurParCode(String? code) {
  if (code == null) return null;
  for (final secteur in <Secteur>[...secteurs, secteurAutre]) {
    if (secteur.code == code) return secteur;
  }
  return null;
}

/// Les 4 kits proposés dans La Boutique (tarifs FCFA existants).
const List<Offre> kitsBoutique = offres;

/// ============================================================================
///  CONVERSION & AFFICHAGE DES PRIX
/// ============================================================================
class Prix {
  const Prix._();

  /// Abonnement Studio Live : 10 USD pour 30 jours.
  static const int studioUsd = 10;
  static const int studioJours = 30;

  /// Équivalent XOF de 10 USD au taux de référence (10 / 0,00165).
  static const int studioXof = 6061;

  /// Montant d'un kit dans la devise réellement facturée.
  static num montantKit(int prixXof, PaysMonde pays) {
    if (pays.viaSasPay) {
      return arrondir(prixXof * pays.taux, pays.devise);
    }
    final devise = pays.devisePaddle;
    return arrondir(prixXof * (tauxXof[devise] ?? 1), devise);
  }

  /// Montant du Studio Live dans la devise réellement facturée.
  static num montantStudio(PaysMonde pays) {
    if (pays.viaSasPay) {
      return arrondir(studioXof * pays.taux, pays.devise);
    }
    final devise = pays.devisePaddle;
    final taux = tauxXof[devise] ?? 1;
    final tauxUsd = tauxXof['USD'] ?? 0.00165;
    return arrondir(studioUsd / tauxUsd * taux, devise);
  }

  /// Devis complet d'un kit : montant facturé + éventuelle conversion locale.
  static DevisPrix devisKit(int prixXof, PaysMonde pays) {
    if (pays.viaSasPay) {
      return DevisPrix(
        montant: montantKit(prixXof, pays),
        devise: pays.devise,
        fournisseur: Fournisseur.sasPay,
        libelleRoute: 'SasPay',
      );
    }
    final devise = pays.devisePaddle;
    final montant = arrondir(prixXof * (tauxXof[devise] ?? 1), devise);
    final local = arrondir(prixXof * pays.taux, pays.devise);
    return DevisPrix(
      montant: montant,
      devise: devise,
      fournisseur: Fournisseur.paddle,
      libelleRoute: 'Paddle',
      montantIndicatif: devise == pays.devise ? null : local,
      deviseIndicative: devise == pays.devise ? null : pays.devise,
    );
  }

  /// Devis complet du Studio Live (10 USD / 30 jours).
  static DevisPrix devisStudio(PaysMonde pays) {
    if (pays.viaSasPay) {
      return DevisPrix(
        montant: montantStudio(pays),
        devise: pays.devise,
        fournisseur: Fournisseur.sasPay,
        libelleRoute: 'SasPay',
      );
    }
    final devise = pays.devisePaddle;
    final montant = montantStudio(pays);
    final local = arrondir(studioXof * pays.taux, pays.devise);
    return DevisPrix(
      montant: montant,
      devise: devise,
      fournisseur: Fournisseur.paddle,
      libelleRoute: 'Paddle',
      montantIndicatif: devise == pays.devise ? null : local,
      deviseIndicative: devise == pays.devise ? null : pays.devise,
    );
  }

  /// Arrondi commercial lisible.
  static num arrondir(double montant, String devise) {
    if (devisesEntieres.contains(devise)) {
      if (montant >= 10000) return (montant / 500).round() * 500;
      if (montant >= 1000) return (montant / 100).round() * 100;
      return montant.round();
    }
    return (montant * 100).round() / 100;
  }

  /// « 9 000 FCFA », « 13,72 € », « 10,00 $ », « 23 000 NGN ».
  static String formater(num montant, String devise) {
    final entier = devisesEntieres.contains(devise);
    final valeur = entier ? montant.round().toString() : montant.toStringAsFixed(2);
    final morceaux = valeur.split('.');
    final groupe = _grouper(morceaux.first);
    final decimales = morceaux.length > 1 ? ',${morceaux.last}' : '';
    return '$groupe$decimales ${symbole(devise)}';
  }

  static String formaterFcfa(num montant) => formater(montant, 'XOF');

  /// Version courte sans espace insécable, utile dans les boutons.
  static String formaterCompact(num montant, String devise) {
    return formater(montant, devise).replaceAll(' ', '\u202F');
  }

  static String symbole(String devise) => symbolesDevises[devise] ?? devise;

  static String _grouper(String chiffres) {
    final tampon = StringBuffer();
    for (var i = 0; i < chiffres.length; i++) {
      if (i > 0 && (chiffres.length - i) % 3 == 0) tampon.write(' ');
      tampon.write(chiffres[i]);
    }
    return tampon.toString();
  }

  /// Route de paiement du pays.
  static Fournisseur fournisseur(PaysMonde pays) =>
      pays.viaSasPay ? Fournisseur.sasPay : Fournisseur.paddle;

  static String libelleRoute(PaysMonde pays) => pays.sasPay
      ? 'SasPay · ${pays.devise}'
      : 'Paddle · ${pays.devisePaddle}';

  /// Phrase rassurante affichée sous le bouton de paiement.
  static String explicationRoute(PaysMonde pays) {
    if (pays.viaSasPay) {
      return 'Paiement sécurisé SasPay, débité en ${pays.devise} '
          '(mobile money ou carte). Aucune donnée bancaire ne transite par nos serveurs.';
    }
    return 'Paiement sécurisé Paddle en ${pays.devisePaddle}, TVA gérée automatiquement. '
        'Le montant local (${pays.devise}) est donné à titre indicatif. '
        'Si le prix EUR n\'est pas configuré, Paddle débite le prix USD équivalent.';
  }
}

/// Prix calculé et prêt à afficher.
class DevisPrix {
  const DevisPrix({
    required this.montant,
    required this.devise,
    required this.fournisseur,
    required this.libelleRoute,
    this.montantIndicatif,
    this.deviseIndicative,
  });

  final num montant;
  final String devise;
  final Fournisseur fournisseur;
  final String libelleRoute;
  final num? montantIndicatif;
  final String? deviseIndicative;

  String get principal => Prix.formater(montant, devise);

  String? get indicatif {
    if (montantIndicatif == null || deviseIndicative == null) return null;
    return '≈ ${Prix.formater(montantIndicatif!, deviseIndicative!)}';
  }

  bool get estSasPay => fournisseur == Fournisseur.sasPay;
}
