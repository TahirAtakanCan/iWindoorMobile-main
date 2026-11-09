import '../utils/status.dart';
import 'window_unit.dart';

class Project {
  final int id;
  final String name;
  final String description;
  final double totalPrice;
  /// Satış ara toplamı (KDV hariç). Yoksa [totalPrice] kullanılır.
  final double? saleTotal;
  final List<WindowUnit> windowUnits;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? customerAddress;
  final int? customerId;
  final ProjectStatus status;
  final DateTime? statusChangedAt;
  final DateTime? approvedAt;
  final double? approvedTotal;
  final DateTime? deliveryDate;
  final double paidTotal;
  final double balance;
  final bool priceChangedAfterApproval;

  Project({
    required this.id,
    required this.name,
    required this.description,
    required this.totalPrice,
    required this.windowUnits,
    this.saleTotal,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.customerAddress,
    this.customerId,
    this.status = ProjectStatus.quote,
    this.statusChangedAt,
    this.approvedAt,
    this.approvedTotal,
    this.deliveryDate,
    this.paidTotal = 0,
    this.balance = 0,
    this.priceChangedAfterApproval = false,
  });

  double get displaySaleTotal => saleTotal ?? totalPrice;

  /// Tahsilat hedefi: onaylıysa onaylanan tutar, değilse güncel satış.
  double get collectionTarget => approvedTotal ?? displaySaleTotal;

  factory Project.fromJson(Map<String, dynamic> json) {
    var list = json['windowUnits'] as List? ?? [];
    List<WindowUnit> unitsList = list.map((i) => WindowUnit.fromJson(i)).toList();

    DateTime? parseDate(Object? v) {
      if (v == null) return null;
      if (v is String && v.length >= 10 && !v.contains('T')) {
        // yyyy-MM-dd
        return DateTime.tryParse(v);
      }
      return DateTime.tryParse('$v');
    }

    return Project(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
      saleTotal: (json['saleTotal'] as num?)?.toDouble() ?? (json['salesTotal'] as num?)?.toDouble(),
      windowUnits: unitsList,
      customerName: json['customerName'] as String?,
      customerPhone: json['customerPhone'] as String?,
      customerEmail: json['customerEmail'] as String?,
      customerAddress: json['customerAddress'] as String?,
      customerId: (json['customerId'] as num?)?.toInt(),
      status: ProjectStatus.fromApi(json['status']),
      statusChangedAt: parseDate(json['statusChangedAt']),
      approvedAt: parseDate(json['approvedAt']),
      approvedTotal: (json['approvedTotal'] as num?)?.toDouble() ?? (json['lockedTotal'] as num?)?.toDouble(),
      deliveryDate: parseDate(json['deliveryDate']),
      paidTotal: (json['paidTotal'] as num?)?.toDouble() ?? (json['paid'] as num?)?.toDouble() ?? 0,
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      priceChangedAfterApproval: json['priceChangedAfterApproval'] as bool? ?? false,
    );
  }
}
