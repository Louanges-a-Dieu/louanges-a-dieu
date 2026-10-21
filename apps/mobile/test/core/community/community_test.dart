import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/community/community.dart';

import '../../support/catalog_fixtures.dart';

/// Serveur simulé : garde les envois de statistiques, échoue sur demande.
final class FakeCommunity implements CommunityRemote {
  final sent = <List<Map<String, Object?>>>[];
  var fail = false;
  HymnReviews reviewsResult = const HymnReviews(
    enabled: true,
    count: 0,
    average: null,
    reviews: [],
    mine: null,
  );
  final submitted = <(String, int, String?)>[];

  @override
  Future<void> recordUsage(List<Map<String, Object?>> events) async {
    if (fail) throw Exception('hors connexion');
    sent.add(events);
  }

  @override
  Future<HymnReviews> reviews(String hymnId) async => reviewsResult;

  @override
  Future<void> submitReview(String hymnId, int rating, String? body) async {
    submitted.add((hymnId, rating, body));
    reviewsResult = HymnReviews(
      enabled: true,
      count: reviewsResult.count,
      average: reviewsResult.average,
      reviews: reviewsResult.reviews,
      mine: MyReview(
        rating: rating,
        body: body,
        status: 'pending',
        reply: null,
      ),
    );
  }

  @override
  Future<void> deleteMyReview(String hymnId) async {}
}

void main() {
  test(
    'compteurs regroupés, envoyés par lots, gardés en cas d’échec',
    () async {
      final db = memoryDatabase();
      addTearDown(db.close);
      final remote = FakeCommunity();
      var enabled = true;
      final recorder = UsageRecorder(
        db,
        remote: remote,
        enabled: () async => enabled,
      );

      await recorder.record('h1', UsageEvent.view);
      await recorder.record('h1', UsageEvent.view);
      await recorder.record('h2', UsageEvent.project);
      expect(remote.sent, isEmpty, reason: 'pas avant le lot');

      remote.fail = true;
      await recorder.flush();
      expect(remote.sent, isEmpty);

      remote.fail = false;
      await recorder.flush();
      expect(
        remote.sent.single,
        unorderedEquals([
          {'hymnId': 'h1', 'event': 'view', 'count': 2},
          {'hymnId': 'h2', 'event': 'project', 'count': 1},
        ]),
      );
      await recorder.flush();
      expect(remote.sent, hasLength(1), reason: 'rien à renvoyer');

      // Un lot complet part tout seul.
      for (var i = 0; i < UsageRecorder.batch; i++) {
        await recorder.record('h3', UsageEvent.listen);
      }
      expect(remote.sent.last, [
        {'hymnId': 'h3', 'event': 'listen', 'count': UsageRecorder.batch},
      ]);

      // Désactivé : rien n'est compté.
      enabled = false;
      await recorder.record('h4', UsageEvent.view);
      await recorder.flush();
      expect(remote.sent, hasLength(2));
    },
  );

  test('avis : lecture de la réponse du serveur', () {
    final reviews = HymnReviews.fromJson({
      'enabled': true,
      'count': 2,
      'average': 4.5,
      'reviews': [
        {
          'rating': 5,
          'body': 'Beau',
          'reply': 'Merci',
          'createdAt': '2026-10-21T10:00:00Z',
        },
        {'rating': 4, 'body': null, 'reply': null, 'createdAt': null},
      ],
      'mine': {'rating': 4, 'body': null, 'status': 'pending', 'reply': null},
    });
    expect(reviews.average, 4.5);
    expect(reviews.reviews.first.reply, 'Merci');
    expect(reviews.mine?.status, 'pending');
    expect(HymnReviews.fromJson({'enabled': false}).count, 0);
  });
}
