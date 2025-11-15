import 'package:flutter/foundation.dart';

/// Required acknowledgements before a user can request account deletion.
enum AccountDeletionAcknowledgement {
  dataErasure,
  outstandingOrders,
  exportConfirmed,
}

extension AccountDeletionAcknowledgementKey on AccountDeletionAcknowledgement {
  /// Identifier used by the API payload.
  String get apiKey {
    return switch (this) {
      AccountDeletionAcknowledgement.dataErasure => 'data_erasure',
      AccountDeletionAcknowledgement.outstandingOrders => 'outstanding_orders',
      AccountDeletionAcknowledgement.exportConfirmed => 'export_confirmed',
    };
  }
}

@immutable
class AccountDeletionRequest {
  AccountDeletionRequest({
    required Set<AccountDeletionAcknowledgement> acknowledgements,
    String? feedback,
  }) : acknowledgements = Set.unmodifiable(acknowledgements),
       feedback = _normalize(feedback);

  final Set<AccountDeletionAcknowledgement> acknowledgements;
  final String? feedback;

  static String? _normalize(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'acknowledgements': [for (final ack in acknowledgements) ack.apiKey],
    };
    if (feedback != null) {
      payload['feedback'] = feedback;
    }
    return payload;
  }
}
