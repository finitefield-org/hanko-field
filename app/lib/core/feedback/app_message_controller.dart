// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/core/feedback/app_message.dart';
import 'package:flutter/foundation.dart';

class AppMessageController implements AppMessageSink {
  AppMessageController({
    this.maxMessages = 3,
    Duration? successDuration,
    Duration? warningDuration,
    Duration? alertDuration,
  }) : _defaultDurations = {
         AppMessageTone.success: successDuration ?? const Duration(seconds: 3),
         AppMessageTone.warning: warningDuration ?? const Duration(seconds: 4),
         AppMessageTone.alert: alertDuration ?? const Duration(seconds: 5),
       };

  final int maxMessages;
  final Map<AppMessageTone, Duration> _defaultDurations;
  final ValueNotifier<List<AppMessage>> _messages =
      ValueNotifier<List<AppMessage>>([]);
  final Map<int, Timer> _timers = {};
  int _counter = 0;

  @override
  ValueListenable<List<AppMessage>> get messages => _messages;

  @override
  void show(AppMessage message) {
    final duration = message.duration ?? _defaultDurations[message.tone]!;
    final entry = message.copyWith(duration: duration);
    final next = [..._messages.value, entry];
    if (next.length > maxMessages) {
      final overflow = next.length - maxMessages;
      for (var i = 0; i < overflow; i++) {
        dismiss(next[i].id);
      }
      _messages.value = next.skip(overflow).toList();
    } else {
      _messages.value = next;
    }
    _scheduleDismiss(entry);
  }

  @override
  void success(String text, {Duration? duration, String? semanticLabel}) {
    show(
      AppMessage(
        id: ++_counter,
        text: text,
        tone: AppMessageTone.success,
        duration: duration,
        semanticLabel: semanticLabel,
      ),
    );
  }

  @override
  void warning(String text, {Duration? duration, String? semanticLabel}) {
    show(
      AppMessage(
        id: ++_counter,
        text: text,
        tone: AppMessageTone.warning,
        duration: duration,
        semanticLabel: semanticLabel,
      ),
    );
  }

  @override
  void alert(String text, {Duration? duration, String? semanticLabel}) {
    show(
      AppMessage(
        id: ++_counter,
        text: text,
        tone: AppMessageTone.alert,
        duration: duration,
        semanticLabel: semanticLabel,
      ),
    );
  }

  @override
  void dismiss(int id) {
    _timers.remove(id)?.cancel();
    if (_messages.value.isEmpty) return;
    _messages.value = _messages.value.where((msg) => msg.id != id).toList();
  }

  void _scheduleDismiss(AppMessage message) {
    _timers.remove(message.id)?.cancel();
    _timers[message.id] = Timer(message.duration!, () => dismiss(message.id));
  }

  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _messages.dispose();
  }
}
