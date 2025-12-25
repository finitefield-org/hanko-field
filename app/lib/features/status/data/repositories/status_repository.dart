// ignore_for_file: public_member_api_docs

import 'dart:math';

import 'package:app/features/status/data/models/status_models.dart';
import 'package:miniriverpod/miniriverpod.dart';

abstract class StatusRepository {
  static const fallback = Scope<StatusRepository>.required('status.repository');

  Future<StatusSnapshot> fetchStatus();
}

final statusRepositoryProvider = Provider<StatusRepository>((ref) {
  return LocalStatusRepository();
});

class LocalStatusRepository implements StatusRepository {
  bool _seeded = false;
  late StatusSnapshot _snapshot;

  @override
  Future<StatusSnapshot> fetchStatus() async {
    _ensureSeeded();
    await Future<void>.delayed(const Duration(milliseconds: 220));
    return _snapshot;
  }

  void _ensureSeeded() {
    if (_seeded) return;
    _snapshot = _seedSnapshot();
    _seeded = true;
  }

  StatusSnapshot _seedSnapshot() {
    final now = DateTime.now();
    final incidents = <StatusIncident>[
      StatusIncident(
        id: 'incident-api-latency',
        service: StatusService.api,
        title: const StatusMessage(
          en: 'Elevated API error rate',
          ja: 'APIエラー率の上昇',
        ),
        summary: const StatusMessage(
          en: 'Some checkout calls return 5xx errors. Mitigation in progress.',
          ja: '一部のチェックアウトAPIで5xxが発生しています。復旧対応中です。',
        ),
        severity: StatusIncidentSeverity.major,
        stage: StatusIncidentStage.monitoring,
        startedAt: now.subtract(const Duration(hours: 2, minutes: 20)),
        updatedAt: now.subtract(const Duration(minutes: 35)),
        resolvedAt: null,
        updates: [
          StatusIncidentUpdate(
            timestamp: now.subtract(const Duration(hours: 2)),
            message: const StatusMessage(
              en: 'A cache cluster reboot reduced error rates.',
              ja: 'キャッシュクラスタ再起動でエラー率が低下しました。',
            ),
          ),
          StatusIncidentUpdate(
            timestamp: now.subtract(const Duration(minutes: 35)),
            message: const StatusMessage(
              en: 'Monitoring metrics; recovery expected soon.',
              ja: '監視中です。まもなく復旧見込みです。',
            ),
          ),
        ],
      ),
      StatusIncident(
        id: 'incident-admin-login',
        service: StatusService.admin,
        title: const StatusMessage(en: 'Admin login latency', ja: '管理画面ログイン遅延'),
        summary: const StatusMessage(
          en: 'Admin sign-in takes longer than usual for some regions.',
          ja: '一部地域で管理画面のログインに時間がかかっています。',
        ),
        severity: StatusIncidentSeverity.minor,
        stage: StatusIncidentStage.investigating,
        startedAt: now.subtract(const Duration(hours: 6, minutes: 10)),
        updatedAt: now.subtract(const Duration(hours: 1, minutes: 20)),
        resolvedAt: null,
        updates: [
          StatusIncidentUpdate(
            timestamp: now.subtract(const Duration(hours: 6)),
            message: const StatusMessage(
              en: 'We are checking authentication latency.',
              ja: '認証遅延の原因を調査しています。',
            ),
          ),
        ],
      ),
      StatusIncident(
        id: 'incident-app-notifications',
        service: StatusService.app,
        title: const StatusMessage(
          en: 'Push notifications delayed',
          ja: 'プッシュ通知の遅延',
        ),
        summary: const StatusMessage(
          en: 'Notifications were delayed for about 45 minutes.',
          ja: '通知配信に45分ほど遅延がありました。',
        ),
        severity: StatusIncidentSeverity.minor,
        stage: StatusIncidentStage.resolved,
        startedAt: now.subtract(const Duration(days: 1, hours: 3)),
        updatedAt: now.subtract(const Duration(days: 1, hours: 2)),
        resolvedAt: now.subtract(const Duration(days: 1, hours: 2)),
        updates: [
          StatusIncidentUpdate(
            timestamp: now.subtract(const Duration(days: 1, hours: 2)),
            message: const StatusMessage(
              en: 'Backlog cleared and delivery restored.',
              ja: '滞留分を解消し、配信が復旧しました。',
            ),
          ),
        ],
      ),
    ];

    final history = <StatusService, List<StatusUptimeWeek>>{
      StatusService.api: _seedUptimeHistory(
        now,
        [
          99.98,
          99.92,
          99.76,
          99.88,
          99.97,
          100.0,
          99.95,
          99.91,
          99.99,
          100.0,
          99.98,
          99.93,
          99.99,
          99.85,
        ],
        [0, 1, 2, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0, 2],
      ),
      StatusService.app: _seedUptimeHistory(
        now,
        [
          100.0,
          99.99,
          99.98,
          99.99,
          100.0,
          100.0,
          99.97,
          99.98,
          99.99,
          100.0,
          99.99,
          100.0,
          100.0,
          99.96,
        ],
        [0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1],
      ),
      StatusService.admin: _seedUptimeHistory(
        now,
        [
          99.91,
          99.88,
          99.92,
          99.96,
          99.98,
          100.0,
          99.94,
          99.89,
          99.97,
          99.98,
          99.96,
          99.93,
          99.97,
          99.9,
        ],
        [1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0, 1],
      ),
    };

    return StatusSnapshot(
      updatedAt: now.subtract(const Duration(minutes: 8)),
      incidents: incidents,
      uptimeHistory: history,
    );
  }

  List<StatusUptimeWeek> _seedUptimeHistory(
    DateTime now,
    List<double> uptime,
    List<int> incidentCounts,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(uptime.length, (index) {
      final date = today.subtract(Duration(days: uptime.length - 1 - index));
      return StatusUptimeDay(
        date: date,
        uptimePercent: uptime[index],
        incidentCount: incidentCounts[index],
      );
    });

    final weeks = <StatusUptimeWeek>[];
    for (var i = 0; i < days.length; i += 7) {
      final slice = days.sublist(i, min(i + 7, days.length));
      weeks.add(StatusUptimeWeek(weekStart: slice.first.date, days: slice));
    }
    return weeks;
  }
}
