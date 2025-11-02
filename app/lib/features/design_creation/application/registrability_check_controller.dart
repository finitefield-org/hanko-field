import 'dart:async';

import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/storage/cache_policy.dart';
import 'package:app/features/design_creation/application/design_creation_controller.dart';
import 'package:app/features/design_creation/application/registrability_check_repository_provider.dart';
import 'package:app/features/design_creation/application/registrability_check_state.dart';
import 'package:app/features/design_creation/data/registrability_check_repository.dart';
import 'package:app/features/design_creation/domain/design_creation_state.dart';
import 'package:app/features/design_creation/domain/registrability_check.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final registrabilityCheckControllerProvider =
    NotifierProvider<RegistrabilityCheckController, RegistrabilityCheckState>(
      RegistrabilityCheckController.new,
      name: 'registrabilityCheckControllerProvider',
    );

class RegistrabilityCheckController extends Notifier<RegistrabilityCheckState> {
  static const _initialState = RegistrabilityCheckState(isLoading: true);

  late final RegistrabilityCheckRepository _repository;
  RegistrabilityCheckRequest? _currentRequest;
  bool _initialized = false;
  bool _isRunning = false;

  @override
  RegistrabilityCheckState build() {
    _repository = ref.read(registrabilityCheckRepositoryProvider);
    final creation = ref.read(designCreationControllerProvider);
    _currentRequest = _buildRequest(creation);

    ref.listen<DesignCreationState>(
      designCreationControllerProvider,
      (_, next) => _handleDesignUpdate(next),
    );

    if (!_initialized) {
      _initialized = true;
      Future.microtask(_loadInitial);
      return _initialState.copyWith(
        currentFingerprint: _currentRequest?.fingerprint,
      );
    }

    return state.copyWith(currentFingerprint: _currentRequest?.fingerprint);
  }

  Future<void> refresh() async {
    if (_isRunning) {
      return;
    }
    final request = _currentRequest;
    if (request == null) {
      state = state.copyWith(
        errorMessage: 'Complete the design details before running checks.',
      );
      return;
    }

    state = state.copyWith(
      isLoading: !state.hasResult,
      isRefreshing: state.hasResult,
      clearError: true,
      isOfflineFallback: false,
    );

    _isRunning = true;
    try {
      final result = await _repository.runCheck(request);
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        result: result,
        cachedFingerprint: request.fingerprint,
        cacheState: CacheState.fresh,
        clearError: true,
        isOfflineFallback: false,
        lastAttemptAt: result.checkedAt,
      );
    } on RegistrabilityCheckException catch (error) {
      if (!ref.mounted) {
        rethrow;
      }
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: error.message,
        isOfflineFallback: state.hasResult && !state.isOutdated,
      );
      rethrow;
    } catch (error) {
      if (!ref.mounted) {
        throw RegistrabilityCheckException(error.toString());
      }
      final message = error.toString();
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: message,
        isOfflineFallback: state.hasResult && !state.isOutdated,
      );
      throw RegistrabilityCheckException(message);
    } finally {
      _isRunning = false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<void> _loadInitial() async {
    final cached = await _repository.loadCachedSnapshot();
    if (!ref.mounted) {
      return;
    }
    final snapshot = cached.value;
    if (snapshot != null) {
      state = state.copyWith(
        isLoading: false,
        result: snapshot.result,
        cachedFingerprint: snapshot.designFingerprint,
        cacheState: cached.state,
        clearError: true,
        isOfflineFallback: cached.state != CacheState.fresh,
        lastAttemptAt: snapshot.result.checkedAt,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        clearResult: true,
        clearCacheState: true,
        isOfflineFallback: false,
      );
    }

    final request = _currentRequest;
    final shouldRefresh =
        request != null &&
        (!cached.hasValue ||
            snapshot!.designFingerprint != request.fingerprint ||
            cached.state == CacheState.stale);
    if (shouldRefresh) {
      await refresh();
    }
  }

  void _handleDesignUpdate(DesignCreationState stateSnapshot) {
    final nextRequest = _buildRequest(stateSnapshot);
    _currentRequest = nextRequest;
    final nextFingerprint = nextRequest?.fingerprint;
    final maintainOfflineFlag =
        state.isOfflineFallback && state.cachedFingerprint == nextFingerprint;
    state = state.copyWith(
      currentFingerprint: nextFingerprint,
      isOfflineFallback: maintainOfflineFlag,
    );
  }

  RegistrabilityCheckRequest? _buildRequest(DesignCreationState creation) {
    final input = creation.pendingInput;
    final draft = creation.nameDraft;
    final style = creation.styleDraft;
    final shape = creation.selectedShape;
    if (style == null || shape == null) {
      return null;
    }

    final displayName =
        input?.kanji?.value ?? input?.rawName ?? draft?.combined ?? '';
    if (displayName.trim().isEmpty) {
      return null;
    }

    final persona = draft?.persona ?? UserPersona.japanese;
    final strokeWeight = style.stroke?.weight ?? 3.0;
    final layout = style.layout;
    final margin = layout?.margin ?? 6.0;
    final alignment = layout?.alignment ?? DesignCanvasAlignment.center;
    final grid = layout?.grid ?? 'none';

    return RegistrabilityCheckRequest(
      displayName: displayName,
      persona: persona,
      shape: shape,
      writingStyle: style.writing,
      alignment: alignment,
      strokeWeight: strokeWeight,
      margin: margin,
      grid: grid,
    );
  }
}
