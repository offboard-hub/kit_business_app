import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kit_business_app/core/config.dart';
import 'package:kit_business_app/core/models.dart';
import 'package:kit_business_app/core/theme.dart';
import 'package:kit_business_app/pages/commande_page.dart';
import 'package:kit_business_app/pages/landing_page.dart';
import 'package:kit_business_app/pages/tiktok_callback_page.dart';

void main() {
  group('Positionnement Afrique francophone', () {
    test('les tarifs sont uniquement en FCFA', () {
      expect(AppConfig.fcfa(3000), '3 000 FCFA');
      expect(AppConfig.fcfa(3500), '3 500 FCFA');
      expect(AppConfig.fcfa(5000), '5 000 FCFA');
      expect(AppConfig.fcfa(9000), '9 000 FCFA');
    });

    test('les 4 offres ont les bons prix', () {
      expect(offres.length, 4);
      expect(offres.firstWhere((o) => o.apiType == 'prompt').prix, 3000);
      expect(offres.firstWhere((o) => o.apiType == 'sheet').prix, 3500);
      expect(offres.firstWhere((o) => o.apiType == 'livre').prix, 5000);
      expect(offres.firstWhere((o) => o.apiType == 'pack').prix, 9000);
      expect(offres.firstWhere((o) => o.apiType == 'pack').populaire, isTrue);
    });

    test('les 6 kits métiers sont disponibles', () {
      expect(kitsMetiers.length, 6);
      expect(kitsMetiers.map((k) => k.code),
          containsAll(['restaurant', 'ecommerce', 'elevage', 'beaute', 'agence', 'financement']));
    });

    test('les pays africains ont un indicatif et une devise FCFA', () {
      final codes = paysAfricains.map((p) => p.code).toList();
      expect(codes, containsAll(['CI', 'SN', 'ML', 'CM', 'BF', 'BJ', 'TG', 'GA']));

      final coteIvoire = paysParCode('CI');
      expect(coteIvoire.indicatif, '+225');
      expect(coteIvoire.devise, 'XOF');

      final cameroun = paysParCode('CM');
      expect(cameroun.indicatif, '+237');
      expect(cameroun.devise, 'XAF');

      for (final pays in paysAfricains) {
        expect(pays.devise, anyOf('XOF', 'XAF'));
      }
    });

    test('le bouton Aide WhatsApp pointe vers wa.me', () {
      expect(AppConfig.lienWhatsAppAide.startsWith('https://wa.me/'), isTrue);
    });
  });

  testWidgets('le logo Kit Business se dessine', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: AppLogo(size: 52))),
      ),
    );

    expect(find.byIcon(Icons.rocket_launch_rounded), findsOneWidget);
  });

  testWidgets('la page d\'accueil se construit sans exception', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: LandingPage()));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('FCFA'), findsWidgets);
    expect(find.textContaining('Aide WhatsApp'), findsWidgets);
    expect(find.text('Notes & Avis de nos clients'), findsOneWidget);
    expect(find.text('Laissez votre avis'), findsOneWidget);

    // Libère le carrousel et son minuteur.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('la section avis tient sur un écran mobile', (tester) async {
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: LandingPage()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('Notes & Avis de nos clients'), findsOneWidget);
    expect(find.text('Publier mon avis'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('un avis expose sa localisation et son initiale', () {
    final avis = AvisSite.fromJson({
      'id': 'abc',
      'note': 4,
      'nom': 'Awa',
      'pays': 'Bénin',
      'ville': 'Cotonou',
      'commentaire': 'Très utile pour fixer mes prix.',
      'created_at': '2026-03-12T10:00:00Z',
    });

    expect(avis.note, 4);
    expect(avis.initiale, 'A');
    expect(avis.localisation, 'Cotonou · Bénin');
  });

  testWidgets('le retour TikTok refusé affiche une erreur claire', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TiktokCallbackPage(code: '', erreurTiktok: 'access_denied'),
      ),
    );
    await tester.pump();

    expect(find.text('Connexion TikTok impossible'), findsOneWidget);
    expect(find.textContaining('access_denied'), findsOneWidget);
    expect(find.text('Ouvrir /admin-videos'), findsOneWidget);
  });

  testWidgets('le tunnel de commande tient sur un écran mobile', (tester) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: CommandePage()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Composer mon kit'), findsOneWidget);
    expect(find.text('Restaurant / Maquis'), findsOneWidget);
    expect(find.text('Pack Complet'), findsWidgets);

    // Sélection d'un kit métier en 1 clic.
    await tester.ensureVisible(find.text('Restaurant / Maquis'));
    await tester.tap(find.text('Restaurant / Maquis'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
  });
}
