typedef AnalyticsParameters = Map<String, Object>;

abstract class AnalyticsEvent {
  const AnalyticsEvent();

  String get name;
  AnalyticsParameters toParameters();

  /// Override to enforce per-event validation before logging.
  void validate() {}
}

class AppLaunchedEvent extends AnalyticsEvent {
  const AppLaunchedEvent({required this.fromNotification});

  final bool fromNotification;

  @override
  String get name => 'app_launched';

  @override
  AnalyticsParameters toParameters() => {'from_notification': fromNotification};
}

class AuthFlowResultEvent extends AnalyticsEvent {
  const AuthFlowResultEvent({required this.method, required this.success});

  final String method;
  final bool success;

  @override
  String get name => 'auth_flow_result';

  @override
  AnalyticsParameters toParameters() => {'method': method, 'success': success};

  @override
  void validate() {
    if (method.isEmpty || method.length > 36) {
      throw ArgumentError.value(
        method,
        'method',
        'Authentication method must be 1-36 characters.',
      );
    }
  }
}

class DesignExportedEvent extends AnalyticsEvent {
  const DesignExportedEvent({required this.designId, required this.format});

  final String designId;
  final String format;

  @override
  String get name => 'design_exported';

  @override
  AnalyticsParameters toParameters() => {
    'design_id': designId,
    'format': format,
  };

  @override
  void validate() {
    if (designId.isEmpty || designId.length > 64) {
      throw ArgumentError.value(
        designId,
        'designId',
        'Design id must be 1-64 characters.',
      );
    }
    if (format.isEmpty) {
      throw ArgumentError.value(
        format,
        'format',
        'Format is required (e.g. png, svg).',
      );
    }
  }
}

class ScreenViewAnalyticsEvent {
  const ScreenViewAnalyticsEvent({
    required this.screenName,
    required this.screenClass,
  });

  final String screenName;
  final String screenClass;

  void validate() {
    if (screenName.isEmpty || screenName.length > 36) {
      throw ArgumentError.value(
        screenName,
        'screenName',
        'Screen name must be 1-36 characters.',
      );
    }
    if (screenClass.isEmpty || screenClass.length > 64) {
      throw ArgumentError.value(
        screenClass,
        'screenClass',
        'Screen class must be 1-64 characters.',
      );
    }
  }
}

class OnboardingTutorialStepViewedEvent extends AnalyticsEvent {
  const OnboardingTutorialStepViewedEvent({
    required this.stepIndex,
    required this.totalSteps,
  });

  final int stepIndex;
  final int totalSteps;

  @override
  String get name => 'onboarding_tutorial_step_viewed';

  @override
  AnalyticsParameters toParameters() => {
    'step_index': stepIndex,
    'total_steps': totalSteps,
  };

  @override
  void validate() {
    if (totalSteps <= 0) {
      throw ArgumentError.value(
        totalSteps,
        'totalSteps',
        'Total steps must be positive.',
      );
    }
    if (stepIndex <= 0 || stepIndex > totalSteps) {
      throw ArgumentError.value(
        stepIndex,
        'stepIndex',
        'Step index must be within 1..$totalSteps.',
      );
    }
  }
}

class OnboardingTutorialCompletedEvent extends AnalyticsEvent {
  const OnboardingTutorialCompletedEvent({required this.totalSteps});

  final int totalSteps;

  @override
  String get name => 'onboarding_tutorial_completed';

  @override
  AnalyticsParameters toParameters() => {'total_steps': totalSteps};

  @override
  void validate() {
    if (totalSteps <= 0) {
      throw ArgumentError.value(
        totalSteps,
        'totalSteps',
        'Total steps must be positive.',
      );
    }
  }
}

class OnboardingTutorialSkippedEvent extends AnalyticsEvent {
  const OnboardingTutorialSkippedEvent({
    required this.skippedAtStep,
    required this.totalSteps,
  });

  final int skippedAtStep;
  final int totalSteps;

  @override
  String get name => 'onboarding_tutorial_skipped';

  @override
  AnalyticsParameters toParameters() => {
    'skipped_at_step': skippedAtStep,
    'total_steps': totalSteps,
  };

  @override
  void validate() {
    if (totalSteps <= 0) {
      throw ArgumentError.value(
        totalSteps,
        'totalSteps',
        'Total steps must be positive.',
      );
    }
    if (skippedAtStep <= 0 || skippedAtStep > totalSteps) {
      throw ArgumentError.value(
        skippedAtStep,
        'skippedAtStep',
        'Skipped step must be within 1..$totalSteps.',
      );
    }
  }
}
