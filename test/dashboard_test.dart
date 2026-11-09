import 'package:flutter_test/flutter_test.dart';
import 'package:iwindoor_mobil/models/dashboard.dart';
import 'package:iwindoor_mobil/utils/status.dart';

void main() {
  test('dashboard countsByStatus ve receivables okunur', () {
    final dash = DashboardSummary.fromJson({
      'countsByStatus': {
        'QUOTE': 3,
        'APPROVED': 1,
        'PRODUCTION': 1,
        'INSTALLATION': 1,
        'DELIVERED': 1,
        'CANCELLED': 1,
      },
      'approvedThisMonth': 12500.5,
      'receivables': 42000.75,
      'upcomingDeliveries': [
        {
          'id': 10,
          'name': 'Villa A',
          'customerName': 'Ali',
          'deliveryDate': '2026-11-20',
          'status': 'PRODUCTION',
        },
      ],
      'overdueDeliveries': [
        {
          'id': 11,
          'name': 'Dükkan',
          'customerName': 'Ayşe',
          'deliveryDate': '2026-11-01',
          'status': 'INSTALLATION',
        },
      ],
    });

    expect(dash.quoteCount, 3);
    expect(dash.productionCount, 1);
    expect(dash.installationCount, 1);
    expect(dash.totalReceivable, 42000.75);
    expect(dash.approvedThisMonth, 12500.5);
    expect(dash.statusCounts[ProjectStatus.quote], 3);
    expect(dash.upcomingDeliveries.single.name, 'Villa A');
    expect(dash.upcomingDeliveries.single.customerName, 'Ali');
    expect(dash.overdueDeliveries.single.status, ProjectStatus.installation);
  });
}
