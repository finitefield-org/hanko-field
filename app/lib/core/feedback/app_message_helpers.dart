// ignore_for_file: public_member_api_docs

import 'package:app/core/feedback/app_message.dart';

AppMessageTone toneForMessage(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('warning') ||
      message.contains('注意') ||
      message.contains('警告')) {
    return AppMessageTone.warning;
  }
  if (lower.contains('error') ||
      lower.contains('failed') ||
      message.contains('失敗') ||
      message.contains('エラー')) {
    return AppMessageTone.alert;
  }
  return AppMessageTone.success;
}

void emitMessageFromText(
  AppMessageSink sink,
  String message, {
  AppMessageTone? tone,
  Duration? duration,
  String? semanticLabel,
}) {
  final resolvedTone = tone ?? toneForMessage(message);
  switch (resolvedTone) {
    case AppMessageTone.success:
      sink.success(message, duration: duration, semanticLabel: semanticLabel);
    case AppMessageTone.warning:
      sink.warning(message, duration: duration, semanticLabel: semanticLabel);
    case AppMessageTone.alert:
      sink.alert(message, duration: duration, semanticLabel: semanticLabel);
  }
}
