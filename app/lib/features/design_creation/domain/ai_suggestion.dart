import 'package:app/core/domain/entities/design.dart';
import 'package:flutter/foundation.dart';

/// Status of an AI-generated suggestion.
enum DesignAiSuggestionStatus { queued, ready, applied, rejected }

@immutable
class DesignAiSuggestion {
  DesignAiSuggestion({
    required this.id,
    required this.title,
    required this.summary,
    required this.score,
    required List<String> tags,
    required this.status,
    required this.baselinePreviewUrl,
    required this.proposedPreviewUrl,
    required this.shape,
    required this.style,
    required this.requestedAt,
    this.readyAt,
    this.completedAt,
    this.appliedAt,
    this.jobRef,
  }) : tags = List.unmodifiable(tags);

  final String id;
  final String title;
  final String summary;
  final double score;
  final List<String> tags;
  final DesignAiSuggestionStatus status;
  final String baselinePreviewUrl;
  final String proposedPreviewUrl;
  final DesignShape shape;
  final DesignStyle style;
  final DateTime requestedAt;
  final DateTime? readyAt;
  final DateTime? completedAt;
  final DateTime? appliedAt;
  final String? jobRef;

  bool get isActionable => status == DesignAiSuggestionStatus.ready;

  DesignAiSuggestion copyWith({
    String? id,
    String? title,
    String? summary,
    double? score,
    List<String>? tags,
    DesignAiSuggestionStatus? status,
    String? baselinePreviewUrl,
    String? proposedPreviewUrl,
    DesignShape? shape,
    DesignStyle? style,
    DateTime? requestedAt,
    DateTime? readyAt,
    bool clearReadyAt = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? appliedAt,
    bool clearAppliedAt = false,
    String? jobRef,
    bool clearJobRef = false,
  }) {
    return DesignAiSuggestion(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      score: score ?? this.score,
      tags: tags ?? this.tags,
      status: status ?? this.status,
      baselinePreviewUrl: baselinePreviewUrl ?? this.baselinePreviewUrl,
      proposedPreviewUrl: proposedPreviewUrl ?? this.proposedPreviewUrl,
      shape: shape ?? this.shape,
      style: style ?? this.style,
      requestedAt: requestedAt ?? this.requestedAt,
      readyAt: clearReadyAt ? null : readyAt ?? this.readyAt,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      appliedAt: clearAppliedAt ? null : appliedAt ?? this.appliedAt,
      jobRef: clearJobRef ? null : jobRef ?? this.jobRef,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is DesignAiSuggestion &&
            other.id == id &&
            other.title == title &&
            other.summary == summary &&
            other.score == score &&
            listEquals(other.tags, tags) &&
            other.status == status &&
            other.baselinePreviewUrl == baselinePreviewUrl &&
            other.proposedPreviewUrl == proposedPreviewUrl &&
            other.shape == shape &&
            other.style == style &&
            other.requestedAt == requestedAt &&
            other.readyAt == readyAt &&
            other.completedAt == completedAt &&
            other.appliedAt == appliedAt &&
            other.jobRef == jobRef);
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    summary,
    score,
    Object.hashAll(tags),
    status,
    baselinePreviewUrl,
    proposedPreviewUrl,
    shape,
    style,
    requestedAt,
    readyAt,
    completedAt,
    appliedAt,
    jobRef,
  );
}
