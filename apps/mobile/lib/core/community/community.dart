import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';

/// Avis publié sur un cantique (approuvé dans le back-office), sans aucune
/// donnée sur son auteur.
@immutable
final class Review {
  const Review({
    required this.rating,
    required this.body,
    required this.reply,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, Object?> json) => Review(
    rating: (json['rating']! as num).toInt(),
    body: json['body'] as String?,
    reply: json['reply'] as String?,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
  );

  final int rating;
  final String? body;
  final String? reply;
  final DateTime? createdAt;
}

/// Son propre avis et son état de modération.
@immutable
final class MyReview {
  const MyReview({
    required this.rating,
    required this.body,
    required this.status,
    required this.reply,
  });

  factory MyReview.fromJson(Map<String, Object?> json) => MyReview(
    rating: (json['rating']! as num).toInt(),
    body: json['body'] as String?,
    status: json['status']! as String,
    reply: json['reply'] as String?,
  );

  final int rating;
  final String? body;

  /// pending | approved | rejected
  final String status;
  final String? reply;
}

/// Avis d'un cantique (planche 8, écran 11 ; RPC hymn_reviews).
@immutable
final class HymnReviews {
  const HymnReviews({
    required this.enabled,
    required this.count,
    required this.average,
    required this.reviews,
    required this.mine,
  });

  factory HymnReviews.fromJson(Map<String, Object?> json) => HymnReviews(
    enabled: json['enabled'] == true,
    count: (json['count'] as num?)?.toInt() ?? 0,
    average: (json['average'] as num?)?.toDouble(),
    reviews: [
      for (final r in (json['reviews'] as List<Object?>? ?? const []))
        Review.fromJson(r! as Map<String, Object?>),
    ],
    mine: switch (json['mine']) {
      final Map<String, Object?> m => MyReview.fromJson(m),
      _ => null,
    },
  );

  final bool enabled;
  final int count;
  final double? average;
  final List<Review> reviews;
  final MyReview? mine;
}

/// Échanges « communauté » avec le serveur : statistiques anonymes et avis.
abstract interface class CommunityRemote {
  Future<void> recordUsage(List<Map<String, Object?>> events);
  Future<HymnReviews> reviews(String hymnId);
  Future<void> submitReview(String hymnId, int rating, String? body);
  Future<void> deleteMyReview(String hymnId);
}

class SupabaseCommunityRemote implements CommunityRemote {
  SupabaseCommunityRemote(this._client);

  final SupabaseClient _client;

  @override
  Future<void> recordUsage(List<Map<String, Object?>> events) =>
      _client.rpc<void>('record_usage', params: {'p_events': events});

  @override
  Future<HymnReviews> reviews(String hymnId) async {
    final result = await _client.rpc<Object?>(
      'hymn_reviews',
      params: {'p_hymn_id': hymnId},
    );
    if (result is! Map<String, Object?>) {
      throw const FormatException('hymn_reviews : réponse inattendue');
    }
    return HymnReviews.fromJson(result);
  }

  @override
  Future<void> submitReview(String hymnId, int rating, String? body) =>
      _client.rpc<void>(
        'submit_review',
        params: {'p_hymn_id': hymnId, 'p_rating': rating, 'p_body': body},
      );

  @override
  Future<void> deleteMyReview(String hymnId) =>
      _client.rpc<void>('delete_my_review', params: {'p_hymn_id': hymnId});
}

/// Usage compté (statistiques anonymes) : consultation, écoute, projection.
enum UsageEvent { view, listen, project }

/// Statistiques anonymes (choix du propriétaire, 2026-10-21) : l'app compte
/// localement les consultations, écoutes et projections par cantique, puis
/// envoie des totaux, sans identifiant d'utilisateur ni d'appareil. Les
/// compteurs non envoyés survivent à un redémarrage (sync_state).
class UsageRecorder {
  UsageRecorder(this._db, {required this.remote, required this.enabled});

  final AppDatabase _db;
  final CommunityRemote? remote;

  /// Réglage de l'utilisateur (Confidentialité → Statistiques anonymes).
  final Future<bool> Function() enabled;

  static const _key = 'usage.pending';

  /// Envoi dès que ce nombre d'usages est atteint (sinon à la mise en
  /// arrière-plan de l'app).
  static const batch = 20;

  Future<void>? _flushing;

  Future<Map<String, int>> _pending() async {
    final row = await (_db.select(
      _db.syncState,
    )..where((s) => s.key.equals(_key))).getSingleOrNull();
    if (row == null) return {};
    try {
      return (jsonDecode(row.value) as Map<String, Object?>).map(
        (k, v) => MapEntry(k, (v! as num).toInt()),
      );
    } on Object {
      return {};
    }
  }

  Future<void> _save(Map<String, int> pending) => _db
      .into(_db.syncState)
      .insertOnConflictUpdate(
        SyncStateCompanion.insert(key: _key, value: jsonEncode(pending)),
      );

  Future<void> record(String hymnId, UsageEvent event) async {
    if (remote == null || !await enabled()) return;
    final pending = await _pending();
    final key = '$hymnId|${event.name}';
    pending[key] = (pending[key] ?? 0) + 1;
    await _save(pending);
    if (pending.values.fold(0, (a, b) => a + b) >= batch) await flush();
  }

  /// Envoie les compteurs ; gardés pour plus tard en cas d'échec.
  Future<void> flush() =>
      _flushing ??= _flush().whenComplete(() => _flushing = null);

  Future<void> _flush() async {
    final remote = this.remote;
    if (remote == null) return;
    final pending = await _pending();
    if (pending.isEmpty) return;
    if (!await enabled()) {
      await _save({});
      return;
    }
    try {
      await remote.recordUsage([
        for (final MapEntry(:key, :value) in pending.entries)
          {
            'hymnId': key.split('|').first,
            'event': key.split('|').last,
            'count': value,
          },
      ]);
    } on Object {
      return;
    }
    // Usages comptés pendant l'envoi : conservés.
    final now = await _pending();
    for (final MapEntry(:key, :value) in pending.entries) {
      final left = (now[key] ?? 0) - value;
      if (left > 0) {
        now[key] = left;
      } else {
        now.remove(key);
      }
    }
    await _save(now);
  }
}
