// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:math';

import 'package:app/core/storage/cache_keys.dart';
import 'package:app/core/storage/local_cache.dart';
import 'package:app/core/storage/local_persistence_providers.dart';
import 'package:app/features/support/data/models/support_chat_models.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

abstract class SupportChatRepository {
  static const fallback = Scope<SupportChatRepository>.required(
    'support.chat.repository',
  );

  Stream<SupportChatMessage> get incomingMessages;

  Future<SupportChatSession> fetchSession();

  Future<SupportChatSession> saveSession(SupportChatSession session);

  Future<SupportChatSession> addIncomingMessage(
    String text, {
    required SupportChatSender sender,
    SupportChatStage? stage,
    DateTime? sentAt,
  });

  void dispose();
}

final supportChatRepositoryProvider = Provider<SupportChatRepository>((ref) {
  final cache = ref.watch(supportChatCacheProvider);
  final gates = ref.watch(appExperienceGatesProvider);
  final logger = Logger('SupportChatRepository');
  final repository = LocalSupportChatRepository(
    cache: cache,
    gates: gates,
    logger: logger,
  );
  ref.onDispose(repository.dispose);
  return repository;
});

class LocalSupportChatRepository implements SupportChatRepository {
  LocalSupportChatRepository({
    required LocalCacheStore<JsonMap> cache,
    required AppExperienceGates gates,
    Logger? logger,
    Random? random,
  }) : _cache = cache,
       _gates = gates,
       _logger = logger ?? Logger('LocalSupportChatRepository'),
       _random = random ?? Random();

  final LocalCacheStore<JsonMap> _cache;
  final AppExperienceGates _gates;
  final Logger _logger;
  final Random _random;
  final StreamController<SupportChatMessage> _incomingController =
      StreamController.broadcast();

  late final LocalCacheKey _cacheKey = LocalCacheKeys.supportChat(
    userId: _gates.isAuthenticated ? 'current' : 'guest',
  );

  bool _seeded = false;
  late SupportChatSession _session;

  @override
  Stream<SupportChatMessage> get incomingMessages => _incomingController.stream;

  @override
  Future<SupportChatSession> fetchSession() async {
    await _ensureSeeded();
    return _session;
  }

  @override
  Future<SupportChatSession> saveSession(SupportChatSession session) async {
    _session = session;
    await _persist();
    return _session;
  }

  @override
  Future<SupportChatSession> addIncomingMessage(
    String text, {
    required SupportChatSender sender,
    SupportChatStage? stage,
    DateTime? sentAt,
  }) async {
    await _ensureSeeded();
    final message = SupportChatMessage(
      id: createSupportChatMessageId(_random),
      sender: sender,
      text: text,
      sentAt: sentAt ?? DateTime.now(),
    );
    _session = _session.copyWith(
      messages: [..._session.messages, message],
      stage: stage ?? _session.stage,
      updatedAt: DateTime.now(),
    );
    await _persist();
    _incomingController.add(message);
    return _session;
  }

  @override
  void dispose() {
    _incomingController.close();
  }

  Future<void> _ensureSeeded() async {
    if (_seeded) return;
    _session = _seedSession();
    await _loadFromCache();
    _seeded = true;
  }

  SupportChatSession _seedSession() {
    final prefersEnglish = _gates.prefersEnglish;
    final greeting = prefersEnglish
        ? "Hi! I'm Hana, your support bot. How can I help today?"
        : 'こんにちは。サポートボットのハナです。ご用件を教えてください。';
    final message = SupportChatMessage(
      id: createSupportChatMessageId(_random),
      sender: SupportChatSender.bot,
      text: greeting,
      sentAt: DateTime.now().subtract(const Duration(minutes: 6)),
    );
    return SupportChatSession(
      messages: [message],
      stage: SupportChatStage.bot,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _loadFromCache() async {
    try {
      final hit = await _cache.read(_cacheKey.value);
      if (hit == null) {
        await _persist();
        return;
      }
      _session = SupportChatSession.fromJson(hit.value);
    } catch (e, stack) {
      _logger.warning('Failed to load support chat cache', e, stack);
    }
  }

  Future<void> _persist() async {
    await _cache.write(
      _cacheKey.value,
      _session.toJson(),
      tags: _cacheKey.tags,
    );
  }
}
