import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/account.dart';
import '../../app/providers.dart';
import '../../core/community/community.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/dialogs.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.g.dart';
import '../../l10n/generated/app_localizations.dart';

final hymnReviewsProvider = FutureProvider.autoDispose
    .family<HymnReviews, String>(
      (ref, hymnId) => ref.watch(communityRemoteProvider)!.reviews(hymnId),
    );

/// « 4,5 » (virgule décimale).
String formatRating(double value) => NumberFormat('0.0', 'fr').format(value);

/// Étoiles d'une note (lecture seule), annoncées « 4 sur 5 ».
class Stars extends StatelessWidget {
  const Stars(this.rating, {super.key, this.size = 18});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.lad;
    return Semantics(
      label: AppLocalizations.of(context).ratingOutOf5(formatRating(rating)),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              rating >= i
                  ? Icons.star
                  : rating >= i - 0.5
                  ? Icons.star_half
                  : Icons.star_border,
              size: size,
              color: p.gold,
            ),
        ],
      ),
    );
  }
}

/// Onglet « Avis » de la fiche (choix du propriétaire, planche 8) : moyenne,
/// avis publiés, son propre avis et son état de modération. Demande Internet.
class ReviewsTab extends ConsumerWidget {
  const ReviewsTab({super.key, required this.hymnId});

  final String hymnId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final reviews = ref.watch(hymnReviewsProvider(hymnId));
    final signedIn = ref.watch(currentUserProvider).value != null;
    final data = reviews.value;
    if (data == null) {
      return reviews.hasError
          ? Padding(
              padding: const EdgeInsets.all(LadSpace.lg),
              child: Column(
                children: [
                  Text(l10n.reviewsOffline, textAlign: TextAlign.center),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(hymnReviewsProvider(hymnId)),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            )
          : const Padding(
              padding: EdgeInsets.all(LadSpace.xl),
              child: Center(child: CircularProgressIndicator()),
            );
    }
    if (!data.enabled) {
      return Padding(
        padding: const EdgeInsets.all(LadSpace.lg),
        child: Text(l10n.reviewsDisabled, textAlign: TextAlign.center),
      );
    }
    final mine = data.mine;
    final body = LadTheme.textStyle(LadTypeScale.body, p.text);
    final muted = LadTheme.textStyle(LadTypeScale.caption, p.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (data.average case final average?) ...[
              Text(
                formatRating(average),
                style: LadTheme.textStyle(LadTypeScale.title, p.text),
              ),
              const SizedBox(width: LadSpace.sm),
              Stars(average),
              const SizedBox(width: LadSpace.sm),
            ],
            Expanded(child: Text(l10n.reviewCount(data.count), style: muted)),
          ],
        ),
        const SizedBox(height: LadSpace.md),
        if (mine == null)
          FilledButton.icon(
            icon: const Icon(Icons.rate_review_outlined),
            label: Text(l10n.writeReview),
            onPressed: () => signedIn
                ? showReviewForm(context, ref, hymnId)
                : context.push('/compte'),
          )
        else
          Container(
            padding: const EdgeInsets.all(LadSpace.md),
            decoration: BoxDecoration(
              color: p.surfaceWarm,
              borderRadius: BorderRadius.circular(LadRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.yourReview,
                        style: LadTheme.textStyle(LadTypeScale.label, p.text),
                      ),
                    ),
                    Text(
                      switch (mine.status) {
                        'approved' => l10n.reviewPublished,
                        'rejected' => l10n.reviewRejected,
                        _ => l10n.reviewPending,
                      },
                      style: LadTheme.textStyle(
                        LadTypeScale.caption,
                        mine.status == 'approved' ? p.success : p.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: LadSpace.xs),
                Stars(mine.rating.toDouble()),
                if (mine.body != null) Text(mine.body!, style: body),
                if (mine.reply != null)
                  Padding(
                    padding: const EdgeInsets.only(top: LadSpace.xs),
                    child: Text(l10n.teamReply(mine.reply!), style: muted),
                  ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () =>
                          showReviewForm(context, ref, hymnId, initial: mine),
                      child: Text(l10n.edit),
                    ),
                    TextButton(
                      onPressed: () async {
                        if (!await confirmDialog(
                          context,
                          title: l10n.deleteReviewTitle,
                          action: l10n.delete,
                          destructive: true,
                        )) {
                          return;
                        }
                        await ref
                            .read(communityRemoteProvider)!
                            .deleteMyReview(hymnId);
                        ref.invalidate(hymnReviewsProvider(hymnId));
                      },
                      child: Text(l10n.delete),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: LadSpace.lg),
        if (data.reviews.isEmpty)
          Text(l10n.noReviewsYet, style: muted, textAlign: TextAlign.center),
        for (final review in data.reviews)
          Padding(
            padding: const EdgeInsets.only(bottom: LadSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Stars(review.rating.toDouble(), size: 16),
                    const SizedBox(width: LadSpace.sm),
                    if (review.createdAt case final date?)
                      Text(
                        MaterialLocalizations.of(context)
                            .formatMediumDate(date.toLocal()),
                        style: muted,
                      ),
                  ],
                ),
                if (review.body != null) Text(review.body!, style: body),
                if (review.reply != null)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: LadSpace.xs,
                      left: LadSpace.md,
                    ),
                    child: Text(l10n.teamReply(review.reply!), style: muted),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Note (étoiles) et commentaire facultatif ; publié après validation.
Future<void> showReviewForm(
  BuildContext context,
  WidgetRef ref,
  String hymnId, {
  MyReview? initial,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final sent = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _ReviewForm(hymnId: hymnId, initial: initial),
  );
  if (sent != true) return;
  ref.invalidate(hymnReviewsProvider(hymnId));
  messenger.showSnackBar(SnackBar(content: Text(l10n.reviewThanks)));
}

class _ReviewForm extends ConsumerStatefulWidget {
  const _ReviewForm({required this.hymnId, this.initial});

  final String hymnId;
  final MyReview? initial;

  @override
  ConsumerState<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends ConsumerState<_ReviewForm> {
  late int _rating = widget.initial?.rating ?? 0;
  late final _body = TextEditingController(text: widget.initial?.body);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final text = _body.text.trim();
      await ref
          .read(communityRemoteProvider)!
          .submitReview(widget.hymnId, _rating, text.isEmpty ? null : text);
      if (mounted) Navigator.pop(context, true);
    } on Object {
      if (mounted) setState(() => _error = l10n.reviewSendFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            LadSpace.xl,
            0,
            LadSpace.xl,
            LadSpace.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.writeReview,
                style: LadTheme.textStyle(LadTypeScale.headline, p.text),
              ),
              const SizedBox(height: LadSpace.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      tooltip: l10n.starCount(i),
                      iconSize: 36,
                      color: p.gold,
                      isSelected: _rating >= i,
                      icon: const Icon(Icons.star_border),
                      selectedIcon: const Icon(Icons.star),
                      onPressed: () => setState(() => _rating = i),
                    ),
                ],
              ),
              const SizedBox(height: LadSpace.md),
              TextField(
                controller: _body,
                maxLength: 1000,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: l10n.commentOptional),
              ),
              Text(
                l10n.reviewModerationHint,
                style: LadTheme.textStyle(
                  LadTypeScale.caption,
                  p.textSecondary,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: LadSpace.sm),
                Text(
                  _error!,
                  style: LadTheme.textStyle(LadTypeScale.label, p.error),
                ),
              ],
              const SizedBox(height: LadSpace.lg),
              FilledButton(
                onPressed: _rating == 0 || _busy ? null : _send,
                child: Text(l10n.send),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
