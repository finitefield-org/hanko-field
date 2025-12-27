// ignore_for_file: public_member_api_docs

import 'package:flutter/foundation.dart';

enum AppMessageTone { success, warning, alert }

class AppMessage {
  const AppMessage({
    required this.id,
    required this.text,
    required this.tone,
    this.duration,
    this.semanticLabel,
  });

  final int id;
  final String text;
  final AppMessageTone tone;
  final Duration? duration;
  final String? semanticLabel;

  AppMessage copyWith({
    int? id,
    String? text,
    AppMessageTone? tone,
    Duration? duration,
    String? semanticLabel,
  }) {
    return AppMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      tone: tone ?? this.tone,
      duration: duration ?? this.duration,
      semanticLabel: semanticLabel ?? this.semanticLabel,
    );
  }
}

abstract class AppMessageSink {
  ValueListenable<List<AppMessage>> get messages;
  void show(AppMessage message);
  void success(String text, {Duration? duration, String? semanticLabel});
  void warning(String text, {Duration? duration, String? semanticLabel});
  void alert(String text, {Duration? duration, String? semanticLabel});
  void dismiss(int id);
}
