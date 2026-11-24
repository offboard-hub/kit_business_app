import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_business_app/pages/boutique_page.dart';
import 'package:kit_business_app/pages/guide_page.dart';
import 'package:kit_business_app/pages/home_page.dart';
import 'package:kit_business_app/pages/studio_live_page.dart';
import 'package:kit_business_app/widgets/logo_ebooklive.dart';

void main() {
  testWidgets('le nouveau logo vectoriel se dessine', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF090D16),
          body: Center(child: LogoEbooklive(size: 96)),
        ),
      ),
    );

    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la page Guide & Tutoriel se construit', (tester) async {
    tester.view.physicalSize = const Size(1280, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: GuidePage()));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Tout comprendre'), findsOneWidget);
    expect(find.text('Commander dans La Boutique'), findsWidgets);
    expect(find.text('Studio Live'), findsWidgets);
  });

  testWidgets('la page d\'accueil présente les deux univers', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('La Boutique'), findsWidgets);
    expect(find.text('Studio Live'), findsWidgets);
    expect(find.text('Guide & Tutoriel'), findsWidgets);
    expect(find.text('Caméra Produits'), findsOneWidget);
    expect(find.text('Partage d\'Écran'), findsOneWidget);
    expect(find.text('Explorer La Boutique'), findsWidgets);
    expect(find.text('Découvrir le Studio Live'), findsWidgets);
  });

  testWidgets('l\'accueil tient sur un écran mobile', (tester) async {
    tester.view.physicalSize = const Size(390, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('Explorer La Boutique'), findsWidgets);
    expect(find.text('Caméra Produits'), findsOneWidget);
  });

  testWidgets('Studio Live propose l\'essai gratuit et l\'abonnement', (tester) async {
    tester.view.physicalSize = const Size(1280, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: StudioLivePage()));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('Essayer gratuitement 3 jours'), findsWidgets);
    expect(find.textContaining('S\'abonner maintenant'), findsWidgets);
    expect(find.textContaining('20 messages IA/jour'), findsWidgets);
  });

  testWidgets('Studio Live tient sur un écran mobile', (tester) async {
    tester.view.physicalSize = const Size(390, 3400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: StudioLivePage()));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('Essayer gratuitement 3 jours'), findsWidgets);
    expect(find.textContaining('S\'abonner maintenant'), findsWidgets);
  });

  testWidgets('La Boutique passe de l\'étape secteur à l\'étape kit', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: BoutiquePage()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('Quel est votre métier ?'), findsOneWidget);
    expect(find.text('E-commerce & Mode'), findsOneWidget);
    expect(find.text('Autre métier'), findsOneWidget);

    await tester.tap(find.text('E-commerce & Mode'));
    await tester.pump();
    await tester.ensureVisible(find.text('Continuer'));
    await tester.tap(find.text('Continuer'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text('Choisissez votre kit'), findsOneWidget);
    expect(find.text('Pack Complet'), findsWidgets);
    expect(find.text('Votre pays'), findsOneWidget);
  });
}
