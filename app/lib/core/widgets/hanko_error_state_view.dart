import 'package:flutter/material.dart';

import '../../app/localization/app_localization.dart';
import '../errors/core_errors.dart';
import 'hanko_state_view.dart';

class HankoErrorStateView extends StatelessWidget {
  const HankoErrorStateView({
    super.key,
    this.error,
    this.appError,
    this.actionLabel,
    this.onAction,
  });

  final Object? error;
  final HankoAppError? appError;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final resolvedError = appError ?? HankoAppError.fromObject(error);

    return HankoStateView.error(
      title: resolvedError.title(l10n),
      message: resolvedError.message(l10n),
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}
