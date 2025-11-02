import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class AuditEvent {
  const AuditEvent({
    required this.action,
    required this.targetRef,
    this.metadata = const <String, Object?>{},
  });

  final String action;
  final String targetRef;
  final Map<String, Object?> metadata;
}

class AuditLogger {
  const AuditLogger();

  Future<void> record(AuditEvent event) async {
    await Future<void>.delayed(const Duration(milliseconds: 16));
    debugPrint(
      '[AUDIT] action=${event.action} target=${event.targetRef} metadata=${event.metadata}',
    );
  }
}

final auditLoggerProvider = Provider<AuditLogger>((ref) {
  return const AuditLogger();
});
