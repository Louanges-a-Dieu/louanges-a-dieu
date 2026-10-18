import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// Saisie d'un texte court (nom de liste, titre, intitulé, note).
/// Renvoie le texte saisi (nettoyé), ou null si annulé. Si [optional] est vrai,
/// une saisie vide est acceptée et renvoyée comme chaîne vide.
Future<String?> textInputDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String action,
  String initial = '',
  bool optional = false,
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextInputDialog(
    title: title,
    label: label,
    action: action,
    initial: initial,
    optional: optional,
  ),
);

/// Le contrôleur appartient à l'état du dialogue : il n'est détruit qu'après
/// l'animation de fermeture.
class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.label,
    required this.action,
    required this.initial,
    required this.optional,
  });

  final String title;
  final String label;
  final String action;
  final String initial;
  final bool optional;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty || widget.optional) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.action)),
      ],
    );
  }
}

/// Confirmation d'une action (souvent destructive). Renvoie vrai si confirmée.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  required String action,
  bool destructive = false,
}) async {
  final l10n = AppLocalizations.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                )
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}
