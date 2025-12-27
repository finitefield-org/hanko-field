// ignore_for_file: public_member_api_docs

import 'package:app/core/feedback/app_message_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/overlays/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class AppMessageOverlay extends ConsumerWidget {
  const AppMessageOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = DesignTokensTheme.of(context);
    final sink = ref.watch(appMessageSinkProvider);

    return Stack(
      children: [
        child,
        Positioned(
          left: tokens.spacing.lg,
          right: tokens.spacing.lg,
          bottom: tokens.spacing.xl,
          child: SafeArea(
            top: false,
            child: ValueListenableBuilder(
              valueListenable: sink.messages,
              builder: (context, messages, _) {
                if (messages.isEmpty) {
                  return const SizedBox.shrink();
                }
                return AnimatedSwitcher(
                  duration: tokens.durations.regular,
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0, 0.2),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: Column(
                    key: ValueKey(messages.map((msg) => msg.id).join(',')),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final message in messages)
                        Padding(
                          padding: EdgeInsets.only(bottom: tokens.spacing.sm),
                          child: AppToast(
                            message: message,
                            onDismiss: () => sink.dismiss(message.id),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
