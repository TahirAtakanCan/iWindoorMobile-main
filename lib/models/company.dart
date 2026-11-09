/// Fiyatlandırma modu.
enum PricingMode {
  costPlus,
  perM2;

  static PricingMode fromJson(Object? v) {
    final s = '${v ?? ''}'.trim().toUpperCase();
    if (s == 'PER_M2' || s == 'PERM2' || s == 'M2') return PricingMode.perM2;
    return PricingMode.costPlus;
  }

  String get apiValue => this == PricingMode.perM2 ? 'PER_M2' : 'COST_PLUS';

  String get labelTr => this == PricingMode.perM2 ? 'm² fiyatı' : 'Maliyet + kâr';
}

/// GET/PUT /api/v1/company gövdesi.
class CompanyProfile {
  final int? id;
  final String name;
  final String? address;
  final String? taxNumber;
  final String? taxOffice;
  final String? phone;
  final String? email;
  final double vatRate;
  final double defaultDiscountPct;
  final String currency;
  final String? quoteNote;
  final int quoteValidityDays;

  /// Üretim: testere payı (mm).
  final double sawKerfMm;

  /// Üretim: her uç kesim payı (mm).
  final double barTrimMm;

  /// Üretim: kullanılabilir artık alt sınırı (mm).
  final double minOffcutMm;

  final String? glassSupplierName;
  final String? glassSupplierPhone;
  final String? glassSupplierEmail;
  final String? glassOrderNote;

  final PricingMode pricingMode;
  final double profitMarginPct;
  final double laborPerM2;
  final double installPerM2;
  final double minBillableAreaM2;

  const CompanyProfile({
    this.id,
    required this.name,
    this.address,
    this.taxNumber,
    this.taxOffice,
    this.phone,
    this.email,
    this.vatRate = 20,
    this.defaultDiscountPct = 0,
    this.currency = 'TRY',
    this.quoteNote,
    this.quoteValidityDays = 30,
    this.sawKerfMm = 4,
    this.barTrimMm = 10,
    this.minOffcutMm = 500,
    this.glassSupplierName,
    this.glassSupplierPhone,
    this.glassSupplierEmail,
    this.glassOrderNote,
    this.pricingMode = PricingMode.costPlus,
    this.profitMarginPct = 30,
    this.laborPerM2 = 0,
    this.installPerM2 = 0,
    this.minBillableAreaM2 = 0,
  });

  factory CompanyProfile.fromJson(Map<String, dynamic> j) => CompanyProfile(
        id: (j['id'] as num?)?.toInt(),
        name: j['name'] as String? ?? '',
        address: j['address'] as String?,
        taxNumber: j['taxNumber'] as String?,
        taxOffice: j['taxOffice'] as String?,
        phone: j['phone'] as String?,
        email: j['email'] as String?,
        vatRate: (j['vatRate'] as num?)?.toDouble() ?? 20,
        defaultDiscountPct: (j['defaultDiscountPct'] as num?)?.toDouble() ?? 0,
        currency: j['currency'] as String? ?? 'TRY',
        quoteNote: j['quoteNote'] as String?,
        quoteValidityDays: (j['quoteValidityDays'] as num?)?.toInt() ?? 30,
        sawKerfMm: (j['sawKerfMm'] as num?)?.toDouble() ?? (j['kerfMm'] as num?)?.toDouble() ?? 4,
        barTrimMm: (j['barTrimMm'] as num?)?.toDouble() ?? (j['trimMm'] as num?)?.toDouble() ?? 10,
        minOffcutMm: (j['minOffcutMm'] as num?)?.toDouble() ?? (j['minRemnantMm'] as num?)?.toDouble() ?? 500,
        glassSupplierName: j['glassSupplierName'] as String? ?? j['glassVendorName'] as String?,
        glassSupplierPhone: j['glassSupplierPhone'] as String? ?? j['glassVendorPhone'] as String?,
        glassSupplierEmail: j['glassSupplierEmail'] as String? ?? j['glassVendorEmail'] as String?,
        glassOrderNote: j['glassOrderNote'] as String? ?? j['glassNote'] as String?,
        pricingMode: PricingMode.fromJson(j['pricingMode'] ?? j['priceMode']),
        profitMarginPct: (j['profitMarginPct'] as num?)?.toDouble() ?? (j['marginPct'] as num?)?.toDouble() ?? 30,
        laborPerM2: (j['laborPerM2'] as num?)?.toDouble() ?? (j['laborCostPerM2'] as num?)?.toDouble() ?? 0,
        installPerM2: (j['installPerM2'] as num?)?.toDouble() ?? (j['installationPerM2'] as num?)?.toDouble() ?? 0,
        minBillableAreaM2: (j['minBillableAreaM2'] as num?)?.toDouble() ?? (j['minAreaM2'] as num?)?.toDouble() ?? 0,
      );

  /// PUT gövdesi (id hariç).
  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'taxNumber': taxNumber,
        'taxOffice': taxOffice,
        'phone': phone,
        'email': email,
        'vatRate': vatRate,
        'defaultDiscountPct': defaultDiscountPct,
        'currency': currency,
        'quoteNote': quoteNote,
        'quoteValidityDays': quoteValidityDays,
        'sawKerfMm': sawKerfMm,
        'barTrimMm': barTrimMm,
        'minOffcutMm': minOffcutMm,
        'glassSupplierName': glassSupplierName,
        'glassSupplierPhone': glassSupplierPhone,
        'glassSupplierEmail': glassSupplierEmail,
        'glassOrderNote': glassOrderNote,
        'pricingMode': pricingMode.apiValue,
        'profitMarginPct': profitMarginPct,
        'laborPerM2': laborPerM2,
        'installPerM2': installPerM2,
        'minBillableAreaM2': minBillableAreaM2,
      };

  CompanyProfile copyWith({
    int? id,
    String? name,
    String? address,
    String? taxNumber,
    String? taxOffice,
    String? phone,
    String? email,
    double? vatRate,
    double? defaultDiscountPct,
    String? currency,
    String? quoteNote,
    int? quoteValidityDays,
    double? sawKerfMm,
    double? barTrimMm,
    double? minOffcutMm,
    String? glassSupplierName,
    String? glassSupplierPhone,
    String? glassSupplierEmail,
    String? glassOrderNote,
    PricingMode? pricingMode,
    double? profitMarginPct,
    double? laborPerM2,
    double? installPerM2,
    double? minBillableAreaM2,
  }) =>
      CompanyProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        address: address ?? this.address,
        taxNumber: taxNumber ?? this.taxNumber,
        taxOffice: taxOffice ?? this.taxOffice,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        vatRate: vatRate ?? this.vatRate,
        defaultDiscountPct: defaultDiscountPct ?? this.defaultDiscountPct,
        currency: currency ?? this.currency,
        quoteNote: quoteNote ?? this.quoteNote,
        quoteValidityDays: quoteValidityDays ?? this.quoteValidityDays,
        sawKerfMm: sawKerfMm ?? this.sawKerfMm,
        barTrimMm: barTrimMm ?? this.barTrimMm,
        minOffcutMm: minOffcutMm ?? this.minOffcutMm,
        glassSupplierName: glassSupplierName ?? this.glassSupplierName,
        glassSupplierPhone: glassSupplierPhone ?? this.glassSupplierPhone,
        glassSupplierEmail: glassSupplierEmail ?? this.glassSupplierEmail,
        glassOrderNote: glassOrderNote ?? this.glassOrderNote,
        pricingMode: pricingMode ?? this.pricingMode,
        profitMarginPct: profitMarginPct ?? this.profitMarginPct,
        laborPerM2: laborPerM2 ?? this.laborPerM2,
        installPerM2: installPerM2 ?? this.installPerM2,
        minBillableAreaM2: minBillableAreaM2 ?? this.minBillableAreaM2,
      );
}
