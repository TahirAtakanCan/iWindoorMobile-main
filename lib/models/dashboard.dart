import '../utils/status.dart';
import '../utils/format.dart';

/// Dashboard teslim satırı (hafif; Project.fromJson değil).
class DeliveryLine {
  final int id;
  final String name;
  final String? customerName;
  final DateTime? deliveryDate;
  final ProjectStatus status;

  const DeliveryLine({
    required this.id,
    required this.name,
    this.customerName,
    this.deliveryDate,
    this.status = ProjectStatus.quote,
  });

  factory DeliveryLine.fromJson(Map<String, dynamic> j) {
    DateTime? parseDate(Object? v) {
      if (v == null) return null;
      return DateTime.tryParse('$v');
    }

    return DeliveryLine(
      id: (j['id'] as num).toInt(),
      name: j['name'] as String? ?? '',
      customerName: j['customerName'] as String?,
      deliveryDate: parseDate(j['deliveryDate']),
      status: ProjectStatus.fromApi(j['status']),
    );
  }

  String get deliveryLabel => formatDate(deliveryDate);
}

class DashboardSummary {
  final int quoteCount;
  final int productionCount;
  final int installationCount;
  final double totalReceivable;
  final double approvedThisMonth;
  final List<DeliveryLine> upcomingDeliveries;
  final List<DeliveryLine> overdueDeliveries;
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
    List<DeliveryLine> parseDeliveries(Object? raw) {
      if (raw is! List) return const [];
      return [for (final e in raw) DeliveryLine.fromJson(Map<String, dynamic>.from(e as Map))];
    }

    final counts = <ProjectStatus, int>{};
    final rawCounts = j['countsByStatus'] ?? j['statusCounts'] ?? j['counts'];
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
      totalReceivable: (j['receivables'] as num?)?.toDouble() ??
          (j['totalReceivable'] as num?)?.toDouble() ??
          (j['receivableTotal'] as num?)?.toDouble() ??
          (j['totalBalance'] as num?)?.toDouble() ??
          0,
      approvedThisMonth: (j['approvedThisMonth'] as num?)?.toDouble() ??
          (j['monthApprovedTotal'] as num?)?.toDouble() ??
          0,
      upcomingDeliveries: parseDeliveries(j['upcomingDeliveries'] ?? j['upcoming']),
      overdueDeliveries: parseDeliveries(j['overdueDeliveries'] ?? j['overdue']),
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
