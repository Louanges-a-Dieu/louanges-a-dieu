import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/account.dart';
import '../../app/providers.dart';
import '../../core/auth/auth_service.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.g.dart';
import '../../l10n/generated/app_localizations.dart';

/// Compte (tâche 6.2) : connexion par e-mail sans mot de passe, état de la
/// synchronisation, déconnexion, suppression du compte.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.account)),
      body: user == null ? const _SignIn() : _SignedIn(user: user),
    );
  }
}

String authMessage(AppLocalizations l10n, Object error) => switch (error) {
  AuthFailure(kind: AuthFailureKind.invalidEmail) => l10n.authInvalidEmail,
  AuthFailure(kind: AuthFailureKind.rateLimited) => l10n.authRateLimited,
  AuthFailure(kind: AuthFailureKind.invalidCode) => l10n.authInvalidCode,
  AuthFailure(kind: AuthFailureKind.network) => l10n.authNetwork,
  AuthFailure(kind: AuthFailureKind.unavailable) => l10n.authUnavailable,
  _ => l10n.authUnknown,
};

class _SignIn extends ConsumerStatefulWidget {
  const _SignIn();

  @override
  ConsumerState<_SignIn> createState() => _SignInState();
}

class _SignInState extends ConsumerState<_SignIn> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  String? _sentTo;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Object catch (e) {
      if (mounted) {
        setState(() => _error = authMessage(AppLocalizations.of(context), e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final auth = ref.read(authServiceProvider);
    return ListView(
      padding: const EdgeInsets.all(LadSpace.xl),
      children: [
        const Center(child: WheatEar(size: 36)),
        const SizedBox(height: LadSpace.lg),
        if (_sentTo == null) ...[
          Text(
            l10n.accountIntro,
            style: LadTheme.textStyle(LadTypeScale.body, p.textSecondary),
          ),
          const SizedBox(height: LadSpace.xl),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.send,
            decoration: InputDecoration(labelText: l10n.emailLabel),
            onSubmitted: (_) => _send(auth),
          ),
          const SizedBox(height: LadSpace.lg),
          FilledButton(
            onPressed: _busy ? null : () => _send(auth),
            child: Text(l10n.sendSignInEmail),
          ),
        ] else ...[
          Text(
            l10n.emailSentTitle,
            textAlign: TextAlign.center,
            style: LadTheme.textStyle(LadTypeScale.headline, p.text),
          ),
          const SizedBox(height: LadSpace.sm),
          Text(
            l10n.emailSent(_sentTo!),
            textAlign: TextAlign.center,
            style: LadTheme.textStyle(LadTypeScale.body, p.textSecondary),
          ),
          const SizedBox(height: LadSpace.xl),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            decoration: InputDecoration(labelText: l10n.codeLabel),
            onSubmitted: (_) => _verify(auth),
          ),
          const SizedBox(height: LadSpace.lg),
          FilledButton(
            onPressed: _busy ? null : () => _verify(auth),
            child: Text(l10n.verifyCode),
          ),
          TextButton(
            onPressed: _busy ? null : () => setState(() => _sentTo = null),
            child: Text(l10n.changeEmail),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: LadSpace.md),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: LadTheme.textStyle(LadTypeScale.body, p.error),
          ),
        ],
      ],
    );
  }

  void _send(AuthService auth) => _run(() async {
    await auth.sendSignInEmail(_email.text);
    if (mounted) setState(() => _sentTo = _email.text.trim());
  });

  void _verify(AuthService auth) =>
      _run(() => auth.verifyCode(_sentTo!, _code.text));
}

class _SignedIn extends ConsumerWidget {
  const _SignedIn({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final status = ref.watch(syncRunnerProvider);
    return ListView(
      padding: const EdgeInsets.all(LadSpace.xl),
      children: [
        Text(
          l10n.signedInAs(user.email ?? ''),
          style: LadTheme.textStyle(LadTypeScale.body, p.text),
        ),
        const SizedBox(height: LadSpace.xl),
        Text(
          status.syncing ? l10n.syncing : l10n.pendingChanges(status.pending),
          style: LadTheme.textStyle(LadTypeScale.body, p.textSecondary),
        ),
        if (status.lastFailed)
          Padding(
            padding: const EdgeInsets.only(top: LadSpace.xs),
            child: Text(
              l10n.syncFailed,
              style: LadTheme.textStyle(LadTypeScale.label, p.error),
            ),
          ),
        const SizedBox(height: LadSpace.md),
        OutlinedButton.icon(
          icon: const Icon(Icons.sync),
          label: Text(l10n.syncNow),
          onPressed: status.syncing
              ? null
              : () => ref.read(syncRunnerProvider.notifier).syncNow(),
        ),
        const WheatDivider(),
        OutlinedButton(
          onPressed: () => _signOut(context, ref),
          child: Text(l10n.signOut),
        ),
        const SizedBox(height: LadSpace.md),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: p.error),
          onPressed: () => _delete(context, ref),
          child: Text(l10n.deleteAccount),
        ),
      ],
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final actions = ref.read(accountActionsProvider);
    final unsynced = await actions.unsyncedBeforeSignOut();
    if (!context.mounted) return;
    var keepFavorites = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.signOutTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.signOutMessage),
              if (unsynced > 0) ...[
                const SizedBox(height: LadSpace.sm),
                Text(
                  l10n.signOutUnsynced(unsynced),
                  style: TextStyle(color: context.lad.error),
                ),
              ],
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: keepFavorites,
                title: Text(l10n.keepFavorites),
                onChanged: (v) => setState(() => keepFavorites = v ?? true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.signOut),
            ),
          ],
        ),
      ),
    );
    if (confirmed ?? false) await actions.signOut(keepFavorites: keepFavorites);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteAccountTitle),
        content: Text(l10n.deleteAccountMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.lad.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    try {
      await ref.read(accountActionsProvider).deleteAccount();
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(authMessage(l10n, e))));
      }
    }
  }
}
