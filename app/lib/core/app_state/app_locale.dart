import 'dart:ui';

import 'package:app/core/storage/storage_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLocaleSource { system, user }

class AppLocaleState {
  const AppLocaleState({
    required this.locale,
    required this.systemLocale,
    required this.source,
    this.lastUpdatedAt,
  });

  final Locale locale;
  final Locale systemLocale;
  final AppLocaleSource source;
  final DateTime? lastUpdatedAt;

  AppLocaleState copyWith({
    Locale? locale,
    Locale? systemLocale,
    AppLocaleSource? source,
    DateTime? lastUpdatedAt,
  }) {
    return AppLocaleState(
      locale: locale ?? this.locale,
      systemLocale: systemLocale ?? this.systemLocale,
      source: source ?? this.source,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}

class AppLocaleNotifier extends AsyncNotifier<AppLocaleState> {
  static const _prefsKey = 'app.locale.override';

  SharedPreferences? _preferences;
  VoidCallback? _previousLocaleCallback;

  PlatformDispatcher get _dispatcher => PlatformDispatcher.instance;

  @override
  Future<AppLocaleState> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    _preferences = prefs;
    _subscribeToSystemLocale();

    final systemLocale = _dispatcher.locale;
    final overrideTag = prefs.getString(_prefsKey);
    final overrideLocale = overrideTag == null
        ? null
        : _localeFromTag(overrideTag);
    final resolvedLocale = overrideLocale ?? systemLocale;

    return AppLocaleState(
      locale: resolvedLocale,
      systemLocale: systemLocale,
      source: overrideLocale == null
          ? AppLocaleSource.system
          : AppLocaleSource.user,
      lastUpdatedAt: DateTime.now(),
    );
  }

  Future<void> setLocale(Locale locale) async {
    final prefs = await _ensurePreferences();
    await prefs.setString(_prefsKey, locale.toLanguageTag());
    final base = await _currentState();
    if (!ref.mounted) {
      return;
    }
    state = AsyncData(
      base.copyWith(
        locale: locale,
        source: AppLocaleSource.user,
        lastUpdatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> useSystemLocale() async {
    final prefs = await _ensurePreferences();
    await prefs.remove(_prefsKey);
    final systemLocale = _dispatcher.locale;
    final base = await _currentState();
    if (!ref.mounted) {
      return;
    }
    state = AsyncData(
      base.copyWith(
        locale: systemLocale,
        source: AppLocaleSource.system,
        lastUpdatedAt: DateTime.now(),
      ),
    );
  }

  @visibleForTesting
  Future<void> handleSystemLocaleChanged(Locale newLocale) async {
    final base = await _currentState();
    final shouldAdopt = base.source == AppLocaleSource.system;
    if (!ref.mounted) {
      return;
    }
    state = AsyncData(
      base.copyWith(
        systemLocale: newLocale,
        locale: shouldAdopt ? newLocale : base.locale,
        lastUpdatedAt: DateTime.now(),
      ),
    );
  }

  void _subscribeToSystemLocale() {
    if (_previousLocaleCallback != null) {
      return;
    }
    _previousLocaleCallback = _dispatcher.onLocaleChanged;
    _dispatcher.onLocaleChanged = () {
      _previousLocaleCallback?.call();
      // ignore: discarded_futures
      handleSystemLocaleChanged(_dispatcher.locale);
    };
    ref.onDispose(() {
      _dispatcher.onLocaleChanged = _previousLocaleCallback;
      _previousLocaleCallback = null;
    });
  }

  Locale? _localeFromTag(String tag) {
    try {
      final segments = tag.split('-');
      if (segments.isEmpty) {
        return null;
      }
      final languageCode = segments[0];
      String? scriptCode;
      String? countryCode;
      if (segments.length == 2) {
        countryCode = segments[1];
      } else if (segments.length >= 3) {
        scriptCode = segments[1];
        countryCode = segments[2];
      }
      return Locale.fromSubtags(
        languageCode: languageCode,
        scriptCode: scriptCode,
        countryCode: countryCode,
      );
    } catch (_) {
      return null;
    }
  }

  Future<AppLocaleState> _currentState() async {
    final cached = state.asData?.value;
    if (cached != null) {
      return cached;
    }
    return future;
  }

  Future<SharedPreferences> _ensurePreferences() async {
    final existing = _preferences;
    if (existing != null) {
      return existing;
    }
    final prefs = await ref.read(sharedPreferencesProvider.future);
    _preferences = prefs;
    return prefs;
  }
}

final appLocaleProvider =
    AsyncNotifierProvider<AppLocaleNotifier, AppLocaleState>(
      AppLocaleNotifier.new,
    );
