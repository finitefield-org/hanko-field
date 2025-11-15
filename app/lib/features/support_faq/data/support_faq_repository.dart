import 'package:app/core/domain/entities/user.dart';
import 'package:app/features/support_faq/domain/support_faq.dart';

class FaqContentRequest {
  const FaqContentRequest({required this.localeTag, required this.persona});

  final String localeTag;
  final UserPersona persona;

  FaqContentRequest copyWith({String? localeTag, UserPersona? persona}) {
    return FaqContentRequest(
      localeTag: localeTag ?? this.localeTag,
      persona: persona ?? this.persona,
    );
  }
}

class FaqFeedbackRequest {
  const FaqFeedbackRequest({
    required this.entryId,
    required this.localeTag,
    required this.choice,
  });

  final String entryId;
  final String localeTag;
  final FaqFeedbackChoice choice;

  FaqFeedbackRequest copyWith({
    String? entryId,
    String? localeTag,
    FaqFeedbackChoice? choice,
  }) {
    return FaqFeedbackRequest(
      entryId: entryId ?? this.entryId,
      localeTag: localeTag ?? this.localeTag,
      choice: choice ?? this.choice,
    );
  }
}

abstract class SupportFaqRepository {
  Future<FaqContentResult> fetchFaqs(FaqContentRequest request);
  Future<FaqEntry> submitFeedback(FaqFeedbackRequest request);
}
