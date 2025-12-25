// ignore_for_file: public_member_api_docs

enum StatusService { api, app, admin }

extension StatusServiceX on StatusService {
  String label({required bool prefersEnglish}) {
    switch (this) {
      case StatusService.api:
        return prefersEnglish ? 'API' : 'API';
      case StatusService.app:
        return prefersEnglish ? 'App' : 'アプリ';
      case StatusService.admin:
        return prefersEnglish ? 'Admin' : '管理画面';
    }
  }
}

enum StatusIncidentSeverity { minor, major, critical, maintenance }

extension StatusIncidentSeverityX on StatusIncidentSeverity {
  String label({required bool prefersEnglish}) {
    switch (this) {
      case StatusIncidentSeverity.minor:
        return prefersEnglish ? 'Minor' : '軽微';
      case StatusIncidentSeverity.major:
        return prefersEnglish ? 'Major' : '重大';
      case StatusIncidentSeverity.critical:
        return prefersEnglish ? 'Critical' : '重大障害';
      case StatusIncidentSeverity.maintenance:
        return prefersEnglish ? 'Maintenance' : 'メンテナンス';
    }
  }
}

enum StatusIncidentStage { investigating, identified, monitoring, resolved }

extension StatusIncidentStageX on StatusIncidentStage {
  String label({required bool prefersEnglish}) {
    switch (this) {
      case StatusIncidentStage.investigating:
        return prefersEnglish ? 'Investigating' : '調査中';
      case StatusIncidentStage.identified:
        return prefersEnglish ? 'Identified' : '原因特定';
      case StatusIncidentStage.monitoring:
        return prefersEnglish ? 'Monitoring' : '監視中';
      case StatusIncidentStage.resolved:
        return prefersEnglish ? 'Resolved' : '解決済み';
    }
  }
}

class StatusMessage {
  const StatusMessage({required this.en, required this.ja});

  final String en;
  final String ja;

  String resolve(bool prefersEnglish) => prefersEnglish ? en : ja;
}

class StatusIncidentUpdate {
  const StatusIncidentUpdate({required this.timestamp, required this.message});

  final DateTime timestamp;
  final StatusMessage message;
}

class StatusIncident {
  const StatusIncident({
    required this.id,
    required this.service,
    required this.title,
    required this.summary,
    required this.severity,
    required this.stage,
    required this.startedAt,
    required this.updatedAt,
    required this.resolvedAt,
    required this.updates,
  });

  final String id;
  final StatusService service;
  final StatusMessage title;
  final StatusMessage summary;
  final StatusIncidentSeverity severity;
  final StatusIncidentStage stage;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final List<StatusIncidentUpdate> updates;

  bool get isActive => resolvedAt == null;
}

class StatusUptimeDay {
  const StatusUptimeDay({
    required this.date,
    required this.uptimePercent,
    required this.incidentCount,
  });

  final DateTime date;
  final double uptimePercent;
  final int incidentCount;
}

class StatusUptimeWeek {
  const StatusUptimeWeek({required this.weekStart, required this.days});

  final DateTime weekStart;
  final List<StatusUptimeDay> days;
}

class StatusSnapshot {
  const StatusSnapshot({
    required this.updatedAt,
    required this.incidents,
    required this.uptimeHistory,
  });

  final DateTime updatedAt;
  final List<StatusIncident> incidents;
  final Map<StatusService, List<StatusUptimeWeek>> uptimeHistory;
}
