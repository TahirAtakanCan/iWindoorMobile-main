class Customer {
  final int id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? note;
  final int projectCount;
  final double balanceTotal;

  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.note,
    this.projectCount = 0,
    this.balanceTotal = 0,
  });

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String? ?? '',
        phone: j['phone'] as String?,
        email: j['email'] as String?,
        address: j['address'] as String?,
        note: j['note'] as String? ?? j['notes'] as String?,
        projectCount: (j['projectCount'] as num?)?.toInt() ?? (j['projectsCount'] as num?)?.toInt() ?? 0,
        balanceTotal: (j['balanceTotal'] as num?)?.toDouble() ??
            (j['totalBalance'] as num?)?.toDouble() ??
            (j['balance'] as num?)?.toDouble() ??
            0,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'note': note,
      };

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? note,
    int? projectCount,
    double? balanceTotal,
  }) =>
      Customer(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        address: address ?? this.address,
        note: note ?? this.note,
        projectCount: projectCount ?? this.projectCount,
        balanceTotal: balanceTotal ?? this.balanceTotal,
      );
}
