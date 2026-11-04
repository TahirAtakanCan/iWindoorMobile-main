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
      );
}
