import 'package:flutter_test/flutter_test.dart';
import 'package:kit_business_app/core/models.dart';

void main() {
  group('Checkout', () {
    test('parse une réponse SasPay', () {
      final checkout = CheckoutCree.fromJson(<String, dynamic>{
        'success': true,
        'provider': 'saspay',
        'kind': 'kit',
        'order_id': 'order-1',
        'session_id': 'sess-1',
        'checkout_url': 'https://pay.saspay.me/abc',
        'montant': 23000,
        'devise': 'NGN',
        'offre': 'Pack Complet',
        'metier': 'E-commerce & Mode',
        'pays': 'Nigeria',
      });

      expect(checkout.orderId, 'order-1');
      expect(checkout.fournisseur, Fournisseur.sasPay);
      expect(checkout.montant, 23000);
      expect(checkout.devise, 'NGN');
      expect(checkout.estStudio, isFalse);
      expect(checkout.reference, 'order-1');
    });

    test('parse une réponse Paddle Studio', () {
      final checkout = CheckoutCree.fromJson(<String, dynamic>{
        'success': true,
        'provider': 'paddle',
        'kind': 'studio',
        'subscription_id': 'sub-1',
        'transaction_id': 'txn_1',
        'client_token': 'live_1',
        'environment': 'sandbox',
        'checkout_url': '',
        'montant': 9.24,
        'devise': 'EUR',
        'montant_indicatif': 99.4,
        'devise_indicative': 'MAD',
        'offre': 'Studio Live',
        'metier': 'Beauté',
        'pays': 'Maroc',
      });

      expect(checkout.fournisseur, Fournisseur.paddle);
      expect(checkout.estStudio, isTrue);
      expect(checkout.subscriptionId, 'sub-1');
      expect(checkout.transactionId, 'txn_1');
      expect(checkout.environment, 'sandbox');
      expect(checkout.reference, 'sub-1');
      expect(checkout.montantIndicatif, 99.4);
    });
  });

  group('Studio Live', () {
    test('un abonnement actif calcule ses jours restants', () {
      final abonnement = AbonnementStudio.fromJson(<String, dynamic>{
        'id': 'sub-1',
        'email': 'awa@example.com',
        'nom_activite': 'Studio Awa',
        'metier_code': 'beaute',
        'metier_label': 'Beauté & Bien-être',
        'pays_code': 'MA',
        'pays_label': 'Maroc',
        'devise': 'EUR',
        'montant_local': 9.24,
        'montant_usd': 10,
        'provider': 'paddle',
        'status': 'ACTIF',
        'guide_status': 'PRET',
        'created_at': '2026-01-01T10:00:00Z',
        'expires_at':
            DateTime.now().add(const Duration(days: 12)).toUtc().toIso8601String(),
      });

      expect(abonnement.estActif, isTrue);
      expect(abonnement.joursRestants, 11);
      expect(abonnement.libelleStatut, contains('j restants'));
    });

    test('un abonnement expiré n\'est pas actif', () {
      final abonnement = AbonnementStudio.fromJson(<String, dynamic>{
        'id': 'sub-2',
        'email': 'awa@example.com',
        'nom_activite': 'Studio Awa',
        'metier_code': 'beaute',
        'status': 'ACTIF',
        'created_at': '2025-01-01T10:00:00Z',
        'expires_at': '2025-02-01T10:00:00Z',
      });
      expect(abonnement.estActif, isFalse);
      expect(abonnement.libelleStatut, 'Expiré');
    });

    test('une session expose son format, son mode et sa fiche', () {
      final session = SessionLive.fromJson(<String, dynamic>{
        'id': 'sess-1',
        'subscription_id': 'sub-1',
        'room_id': 'abc123',
        'invite_token': 'token',
        'titre': 'Ventes privées wax',
        'plateformes': <String>['SALLE', 'TIKTOK'],
        'format': 'DUO',
        'mode_visuel': 'ECRAN',
        'fiche_produit': <String, dynamic>{'titre': 'Robe wax', 'produits': '9 000 FCFA'},
        'statut': 'PRET',
      });

      expect(session.estDuo, isTrue);
      expect(session.partageEcran, isTrue);
      expect(session.plateformes, contains('TIKTOK'));
      expect(session.ficheProduit['titre'], 'Robe wax');
      expect(session.libelleFormat, 'Duo / co-animateur');
    });

    test('le guide est prêt seulement avec du contenu', () {
      final guide = GuideLive.fromJson(<String, dynamic>{
        'id': 'guide-1',
        'subscription_id': 'sub-1',
        'titre': 'Mon guide',
        'contenu_html': '<h1>Guide</h1>',
        'contenu_markdown': '# Guide',
        'statut': 'PRET',
      });
      expect(guide.estPret, isTrue);

      final vide = GuideLive.fromJson(<String, dynamic>{
        'id': 'guide-2',
        'subscription_id': 'sub-1',
        'statut': 'EN_COURS',
      });
      expect(vide.estPret, isFalse);
    });
  });

  group('Résultat de commande', () {
    test('parse les liens et la livraison email', () {
      final resultat = ResultatCommande.fromJson(<String, dynamic>{
        'order_id': 'order-1',
        'paid': true,
        'statut': 'LIVRE',
        'liens': <String, dynamic>{
          'livre': 'https://x/livre',
          'prompts': 'https://x/prompts',
          'sheet': 'https://x/sheet',
        },
        'livraison': <String, dynamic>{
          'email': <String, dynamic>{'envoye': true},
        },
        'commande': <String, dynamic>{
          'nom_projet': 'Ma boutique',
          'metier_label': 'E-commerce & Mode',
          'montant_fcfa': 9000,
        },
      });

      expect(resultat.paid, isTrue);
      expect(resultat.liens.aDesLiens, isTrue);
      expect(resultat.livraison.email, isTrue);
      expect(resultat.montant, 9000);
    });

    test('parse un abonnement et un guide Studio', () {
      final resultat = ResultatCommande.fromJson(<String, dynamic>{
        'success': true,
        'paid': true,
        'subscription_id': 'sub-1',
        'statut': 'ACTIF',
        'abonnement': <String, dynamic>{
          'id': 'sub-1',
          'status': 'ACTIF',
          'created_at': '2026-01-01T10:00:00Z',
        },
        'guide': <String, dynamic>{
          'id': 'guide-1',
          'subscription_id': 'sub-1',
          'contenu_html': '<p>Bonjour</p>',
          'statut': 'PRET',
        },
      });

      expect(resultat.abonnement?.id, 'sub-1');
      expect(resultat.guide?.estPret, isTrue);
    });
  });
}
