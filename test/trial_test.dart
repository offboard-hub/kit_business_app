import 'package:flutter_test/flutter_test.dart';
import 'package:kit_business_app/core/models.dart';

void main() {
  group('Essai gratuit Studio Live', () {
    test('dure exactement 3 jours et expose les jours restants', () {
      final debut = DateTime.now().subtract(const Duration(hours: 1));
      final essai = EssaiStudio(
        userId: 'user-1',
        startedAt: debut,
        endsAt: debut.add(const Duration(days: EssaiStudio.dureeJours)),
        createdAt: debut,
      );

      expect(EssaiStudio.dureeJours, 3);
      expect(essai.endsAt.difference(essai.startedAt), const Duration(days: 3));
      expect(essai.estActif, isTrue);
      expect(essai.estExpire, isFalse);
      expect(essai.joursRestants, 3);
    });

    test('un essai expiré n\'est plus actif', () {
      final debut = DateTime.now().subtract(const Duration(days: 4));
      final essai = EssaiStudio(
        userId: 'user-1',
        startedAt: debut,
        endsAt: debut.add(const Duration(days: 3)),
        createdAt: debut,
      );

      expect(essai.estActif, isFalse);
      expect(essai.estExpire, isTrue);
      expect(essai.joursRestants, 0);
      expect(essai.libelle, 'Votre essai est terminé');
    });

    test('fromJson lit live_subscriptions et expose le décompte heures/minutes', () {
      final essai = EssaiStudio.fromJson(<String, dynamic>{
        'user_id': 'user-1',
        'trial_started_at': '2026-01-01T10:00:00Z',
        'trial_ends_at': '2026-01-04T10:00:00Z',
        'is_trial': true,
      });

      expect(essai.startedAt, DateTime.parse('2026-01-01T10:00:00Z'));
      expect(essai.endsAt, DateTime.parse('2026-01-04T10:00:00Z'));
      expect(essai.estActif, isFalse);
      expect(essai.compteARebours, 'terminé');
      expect(essai.libelle, 'Votre essai est terminé');
    });

    test('fromJson retombe sur 3 jours si ends_at manque', () {
      final essai = EssaiStudio.fromJson(<String, dynamic>{
        'user_id': 'user-1',
        'started_at': '2026-01-01T10:00:00Z',
      });

      expect(
        essai.endsAt.difference(essai.startedAt),
        const Duration(days: 3),
      );
    });
  });

  group('Accès effectif au Studio Live', () {
    AbonnementStudio abonnement({bool actif = true}) {
      final expiration = actif
          ? DateTime.now().add(const Duration(days: 20))
          : DateTime.now().subtract(const Duration(days: 1));
      return AbonnementStudio.fromJson(<String, dynamic>{
        'id': 'sub-1',
        'email': 'awa@example.com',
        'nom_activite': 'Studio Awa',
        'metier_code': 'beaute',
        'status': actif ? 'ACTIF' : 'EXPIRE',
        'created_at': '2026-01-01T10:00:00Z',
        'expires_at': expiration.toUtc().toIso8601String(),
      });
    }

    EssaiStudio essai({required bool actif}) {
      final debut = actif
          ? DateTime.now().subtract(const Duration(hours: 2))
          : DateTime.now().subtract(const Duration(days: 4));
      return EssaiStudio(
        userId: 'user-1',
        startedAt: debut,
        endsAt: debut.add(const Duration(days: 3)),
        createdAt: debut,
      );
    }

    test('abonnement actif : accès complet et guide autorisé', () {
      final acces = AccesStudio(abonnement: abonnement(), essai: essai(actif: true));
      expect(acces.estPaye, isTrue);
      expect(acces.estEssai, isFalse);
      expect(acces.aAcces, isTrue);
      expect(acces.guideAutorise, isTrue);
    });

    test('essai actif : accès régie/chat, mais pas de Livre Guide', () {
      final acces = AccesStudio(essai: essai(actif: true));
      expect(acces.estPaye, isFalse);
      expect(acces.estEssai, isTrue);
      expect(acces.aAcces, isTrue);
      expect(acces.guideAutorise, isFalse);
      expect(acces.libelleAcces, contains('Essai gratuit'));
    });

    test('essai expiré : accès fermé et message clair', () {
      final acces = AccesStudio(essai: essai(actif: false));
      expect(acces.aAcces, isFalse);
      expect(acces.essaiExpire, isTrue);
      expect(acces.guideAutorise, isFalse);
      expect(acces.libelleAcces, 'Votre essai est terminé');
    });

    test('un abonnement expiré ne donne pas accès', () {
      final acces = AccesStudio(abonnement: abonnement(actif: false));
      expect(acces.estPaye, isFalse);
      expect(acces.aAcces, isFalse);
      expect(acces.guideAutorise, isFalse);
    });

    test('aucun essai ni abonnement : aucun accès', () {
      const acces = AccesStudio();
      expect(acces.aAcces, isFalse);
      expect(acces.essaiExpire, isFalse);
      expect(acces.guideAutorise, isFalse);
      expect(acces.libelleAcces, 'Aucun accès actif');
    });

    test('essai gratuit ne donne jamais accès aux guides', () {
      final acces = AccesStudio(essai: essai(actif: true));
      expect(acces.guideAutorise, isFalse);
    });
  });

  group('Session d\'essai', () {
    test('toJson omet subscription_id pour une session d\'essai', () {
      final session = SessionLive(
        id: '',
        subscriptionId: '',
        userId: 'user-1',
        roomId: 'abc123',
        inviteToken: 'token',
        titre: 'Live essai',
        plateformes: const <String>['SALLE'],
        format: 'SOLO',
        modeVisuel: 'CAMERA',
        ficheProduit: const <String, dynamic>{},
        statut: 'BROUILLON',
      );

      final json = session.toJson();
      expect(json.containsKey('subscription_id'), isFalse);
      expect(json['user_id'], 'user-1');
      expect(json['room_id'], 'abc123');
    });

    test('toJson conserve subscription_id pour un abonné payé', () {
      final session = SessionLive(
        id: '',
        subscriptionId: 'sub-1',
        userId: 'user-1',
        roomId: 'abc123',
        inviteToken: 'token',
        titre: 'Live payé',
        plateformes: const <String>['SALLE'],
        format: 'SOLO',
        modeVisuel: 'CAMERA',
        ficheProduit: const <String, dynamic>{},
        statut: 'BROUILLON',
      );

      expect(session.toJson()['subscription_id'], 'sub-1');
    });
  });
}
