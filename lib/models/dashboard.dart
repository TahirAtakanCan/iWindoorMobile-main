import 'project.dart';
import '../utils/status.dart';

class DashboardSummary {
  final int quoteCount;
  final int productionCount;
  final int installationCount;
  final double totalReceivable;
  final double approvedThisMonth;
  final List<Project> upcomingDeliveries;
  final List<Project> overdueDeliveries;
  final Map<ProjectStatus, int> statusCounts;

  const DashboardSummary({
    required this.quoteCount,
    required this.productionCount,
    required this.installationCount,
    required this.totalReceivable,
    required this.approvedThisMonth,
    this.upcomingDeliveries = const [],
    this.overdueDeliveries = const [],
    this.statusCounts = const {},
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> j) {
    List<Project> parseProjects(Object? raw) {
      if (raw is! List) return const [];
      return [for (final e in raw) Project.fromJson(Map<String, dynamic>.from(e as Map))];
    }

    final counts = <ProjectStatus, int>{};
    final rawCounts = j['statusCounts'] ?? j['counts'];
    if (rawCounts is Map) {
      for (final e in rawCounts.entries) {
        counts[ProjectStatus.fromApi(e.key)] = (e.value as num?)?.toInt() ?? 0;
      }
    }

    return DashboardSummary(
      quoteCount: (j['quoteCount'] as num?)?.toInt() ??
          (j['pendingQuotes'] as num?)?.toInt() ??
          counts[ProjectStatus.quote] ??
          0,
      productionCount: (j['productionCount'] as num?)?.toInt() ??
          (j['inProduction'] as num?)?.toInt() ??
          counts[ProjectStatus.production] ??
          0,
      installationCount: (j['installationCount'] as num?)?.toInt() ??
          (j['inInstallation'] as num?)?.toInt() ??
          counts[ProjectStatus.installation] ??
          0,
      totalReceivable: (j['totalReceivable'] as num?)?.toDouble() ??
          (j['receivableTotal'] as num?)?.toDouble() ??
          (j['totalBalance'] as num?)?.toDouble() ??
          0,
      approvedThisMonth: (j['approvedThisMonth'] as num?)?.toDouble() ??
          (j['monthApprovedTotal'] as num?)?.toDouble() ??
          0,
      upcomingDeliveries: parseProjects(j['upcomingDeliveries'] ?? j['upcoming']),
      overdueDeliveries: parseProjects(j['overdueDeliveries'] ?? j['overdue']),
      statusCounts: counts,
    );
  }
}

class StatusHistoryEntry {
  final DateTime at;
  final String? byName;
  final ProjectStatus? from;
  final ProjectStatus to;
  final String? note;

  const StatusHistoryEntry({
    required this.at,
    required this.to,
    this.byName,
    this.from,
    this.note,
  });

  factory StatusHistoryEntry.fromJson(Map<String, dynamic> j) => StatusHistoryEntry(
        at: DateTime.tryParse('${j['at'] ?? j['createdAt'] ?? j['changedAt'] ?? ''}') ?? DateTime.now(),
        byName: j['byName'] as String? ?? j['userName'] as String? ?? j['changedBy'] as String?,
        from: j['from'] != null || j['fromStatus'] != null
            ? ProjectStatus.fromApi(j['from'] ?? j['fromStatus'])
            : null,
        to: ProjectStatus.fromApi(j['to'] ?? j['toStatus'] ?? j['status']),
        note: j['note'] as String?,
      );
}
