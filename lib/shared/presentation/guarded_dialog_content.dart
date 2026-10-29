import 'package:flutter/material.dart';

/// Dialog routes can outlive the page that opened them during a scope change.
class GuardedDialogContent extends StatelessWidget {
  const GuardedDialogContent({
    super.key,
    required this.child,
    required this.message,
    this.changes,
    this.isAuthorized,
  });
  final Widget child;
  final String message;
  final Listenable? changes;
  final bool Function()? isAuthorized;
  @override
  Widget build(BuildContext context) {
    Widget current() => isAuthorized?.call() == false
        ? AlertDialog(
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(MaterialLocalizations.of(context).closeButtonLabel),
              ),
            ],
          )
        : child;
    return changes == null
        ? current()
        : ListenableBuilder(listenable: changes!, builder: (_, _) => current());
  }
}
