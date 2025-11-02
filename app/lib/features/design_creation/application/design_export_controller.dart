import 'package:app/features/design_creation/application/design_export_state.dart';
import 'package:app/features/design_creation/application/design_export_types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final designExportControllerProvider =
    NotifierProvider<DesignExportController, DesignExportState>(
      DesignExportController.new,
      name: 'designExportControllerProvider',
    );

class DesignExportController extends Notifier<DesignExportState> {
  @override
  DesignExportState build() => const DesignExportState();

  void selectFormat(DesignExportFormat format) {
    if (state.format == format) {
      return;
    }
    state = state.copyWith(format: format);
  }

  void toggleTransparentBackground(bool value) {
    state = state.copyWith(transparentBackground: value);
  }

  void toggleBleed(bool value) {
    state = state.copyWith(includeBleed: value);
  }

  void toggleMetadata(bool value) {
    state = state.copyWith(includeMetadata: value);
  }

  void toggleWatermark(bool value) {
    state = state.copyWith(watermarkOnShare: value);
  }

  void beginProcessing() {
    state = state.copyWith(isProcessing: true, clearError: true);
  }

  void completeProcessing(DesignExportResult result) {
    state = state.copyWith(
      isProcessing: false,
      lastResult: result,
      clearError: true,
    );
  }

  void failProcessing(String message) {
    state = state.copyWith(isProcessing: false, errorMessage: message);
  }

  void beginSharing() {
    state = state.copyWith(isSharing: true, clearShareError: true);
  }

  void completeSharing(DateTime timestamp) {
    state = state.copyWith(
      isSharing: false,
      lastSharedAt: timestamp,
      clearShareError: true,
    );
  }

  void failSharing(String message) {
    state = state.copyWith(isSharing: false, shareErrorMessage: message);
  }

  void clearErrors() {
    state = state.copyWith(clearError: true, clearShareError: true);
  }
}
