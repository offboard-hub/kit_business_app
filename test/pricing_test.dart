import 'package:flutter_test/flutter_test.dart';
import 'package:kit_business_app/core/countries.dart';
import 'package:kit_business_app/core/pricing.dart';

void main() {
  group('Référentiel des pays', () {
    test('contient tous les pays du monde et des codes uniques', () {
      expect(paysMonde.length, greaterThanOrEqualTo(200));
      final codes = paysMonde.map((p) => p.code).toSet();
      expect(codes.length, paysMonde.length);
    });

    test('les 23 pays SasPay sont exactement ceux du contrat', () {
      final codes = paysSasPay.map((p) => p.code).toSet();
      expect(codes, <String>{
        'ML', 'SN', 'CI', 'BF', 'BJ', 'TG', 'NE',
        'CM', 'GA', 'CG',
        'CD', 'GN', 'NG', 'GH', 'SL', 'KE', 'UG', 'TZ', 'RW', 'MW', 'MZ', 'ZM', 'IN',
      });
      expect(codes.length, 23);
    });

    test('les pays SasPay facturent dans leur devise locale', () {
      expect(paysParCode('NG').devise, 'NGN');
      expect(paysParCode('KE').devise, 'KES');
      expect(paysParCode('CD').devise, 'CDF');
      expect(paysParCode('IN').devise, 'INR');
      expect(paysParCode('SN').viaSasPay, isTrue);
    });

    test('le reste du monde passe par Paddle en USD', () {
      expect(paysParCode('MA').viaSasPay, isFalse);
      expect(paysParCode('MA').devisePaddle, 'USD');
      expect(paysParCode('FR').devisePaddle, 'USD');
      expect(paysParCode('US').devisePaddle, 'USD');
      expect(paysParCode('AE').devisePaddle, 'USD');
    });

    test('la recherche ignore les accents et trouve par devise', () {
      expect(rechercherPays('ivoire').first.code, 'CI');
      expect(rechercherPays('curaçao').first.code, 'CW');
      expect(rechercherPays('NGN').any((p) => p.code == 'NG'), isTrue);
      expect(rechercherPays('+221').first.code, 'SN');
    });

    test('un code inconnu retombe sur le Maroc', () {
      expect(paysParCode('ZZ').code, 'MA');
      expect(paysParCode(null).code, 'MA');
    });
  });

  group('Conversion des prix', () {
    test('les kits conservent les tarifs FCFA', () {
      expect(Prix.montantKit(3000, paysParCode('SN')), 3000);
      expect(Prix.montantKit(3500, paysParCode('CM')), 3500);
      expect(Prix.montantKit(5000, paysParCode('CI')), 5000);
      expect(Prix.montantKit(9000, paysParCode('BF')), 9000);
      expect(Prix.formaterFcfa(9000), '9 000 FCFA');
    });

    test('conversion SasPay en devise locale', () {
      expect(Prix.montantKit(9000, paysParCode('NG')), 23000);
      expect(Prix.montantKit(9000, paysParCode('KE')), 1917.0);
      final devis = Prix.devisKit(9000, paysParCode('NG'));
      expect(devis.fournisseur.name, 'sasPay');
      expect(devis.principal, '23 000 ₦');
      expect(devis.indicatif, isNull);
    });

    test('conversion Paddle en USD par défaut + indicatif local', () {
      final fr = Prix.devisKit(9000, paysParCode('FR'));
      expect(fr.devise, 'USD');
      expect(fr.montant, 14.85);
      expect(fr.principal, '14,85 \$');

      final ma = Prix.devisKit(9000, paysParCode('MA'));
      expect(ma.principal, '14,85 \$');
      expect(ma.indicatif, '≈ 147,60 DH');
      expect(ma.deviseIndicative, 'MAD');

      final us = Prix.devisKit(9000, paysParCode('US'));
      expect(us.devise, 'USD');
      expect(us.montant, 14.85);
    });

    test('Studio Live = 10 USD converti automatiquement', () {
      expect(Prix.studioUsd, 10);
      expect(Prix.montantStudio(paysParCode('US')), 10);
      expect(Prix.montantStudio(paysParCode('SN')), 6100);
      expect(Prix.montantStudio(paysParCode('NG')), 15500);

      final fr = Prix.devisStudio(paysParCode('FR'));
      expect(fr.devise, 'USD');
      expect(fr.montant, 10);
      expect(fr.principal, '10,00 \$');

      final ma = Prix.devisStudio(paysParCode('MA'));
      expect(ma.montant, 10);
      expect(ma.indicatif, '≈ 99,39 DH');
    });

    test('arrondis commerciaux et formatage', () {
      expect(Prix.formater(23000, 'NGN'), '23 000 ₦');
      expect(Prix.formater(13.72, 'EUR'), '13,72 €');
      expect(Prix.formater(10, 'USD'), '10,00 \$');
      expect(Prix.formater(6100, 'XOF'), '6 100 FCFA');
      expect(Prix.symbole('INR'), '₹');
    });

    test('les secteurs couvrent les 8 métiers + Autre', () {
      expect(secteurs.length, 8);
      expect(secteurParCode('ecommerce')?.label, 'E-commerce & Mode');
      expect(secteurParCode('autre')?.label, 'Autre métier');
      expect(secteurParCode('inexistant'), isNull);
    });
  });
}
