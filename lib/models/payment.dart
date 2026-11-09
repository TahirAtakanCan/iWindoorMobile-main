enum PaymentKind { payment, refund }

enum PaymentMethod { cash, card, transfer, check, other }

PaymentKind paymentKindFromApi(Object? v) {
  final s = '${v ?? ''}'.trim().toUpperCase();
  if (s == 'REFUND' || s == 'RETURN' || s == 'IADE') return PaymentKind.refund;
  return PaymentKind.payment;
}

String paymentKindApi(PaymentKind k) => k == PaymentKind.refund ? 'REFUND' : 'PAYMENT';

PaymentMethod paymentMethodFromApi(Object? v) {
  final s = '${v ?? ''}'.trim().toUpperCase();
  return switch (s) {
    'CARD' || 'KART' => PaymentMethod.card,
    'TRANSFER' || 'HAVALE' || 'EFT' => PaymentMethod.transfer,
    'CHECK' || 'CHEQUE' || 'CEK' || 'ÇEK' => PaymentMethod.check,
    'OTHER' || 'DIGER' || 'DİĞER' => PaymentMethod.other,
    _ => PaymentMethod.cash,
  };
}

String paymentMethodApi(PaymentMethod m) => switch (m) {
      PaymentMethod.cash => 'CASH',
      PaymentMethod.card => 'CARD',
      PaymentMethod.transfer => 'TRANSFER',
      PaymentMethod.check => 'CHECK',
      PaymentMethod.other => 'OTHER',
    };

String paymentMethodTr(PaymentMethod m) => switch (m) {
      PaymentMethod.cash => 'Nakit',
      PaymentMethod.card => 'Kart',
      PaymentMethod.transfer => 'Havale',
      PaymentMethod.check => 'Çek',
      PaymentMethod.other => 'Diğer',
    };

class Payment {
  final int id;
  final PaymentKind kind;
  final double amount;
  final DateTime paidAt;
  final PaymentMethod method;
  final String? note;

  const Payment({
    required this.id,
    required this.kind,
    required this.amount,
    required this.paidAt,
    required this.method,
    this.note,
  });

  bool get isRefund => kind == PaymentKind.refund;
  double get signedAmount => isRefund ? -amount.abs() : amount.abs();

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: (j['id'] as num).toInt(),
        kind: paymentKindFromApi(j['kind'] ?? j['type']),
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        paidAt: DateTime.tryParse('${j['paidAt'] ?? j['date'] ?? ''}') ?? DateTime.now(),
        method: paymentMethodFromApi(j['method'] ?? j['paymentMethod']),
        note: j['note'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'kind': paymentKindApi(kind),
        'amount': amount.abs(),
        'paidAt': paidAt.toIso8601String(),
        'method': paymentMethodApi(method),
        if (note != null && note!.isNotEmpty) 'note': note,
      };
}

class PaymentsSummary {
  final List<Payment> items;
  final double paidTotal;
  final double targetTotal;
  final double balance;

  const PaymentsSummary({
    required this.items,
    required this.paidTotal,
    required this.targetTotal,
    required this.balance,
  });

  factory PaymentsSummary.fromJson(Map<String, dynamic> j) {
    final list = j['items'] as List? ?? j['payments'] as List? ?? const [];
    return PaymentsSummary(
      items: [for (final e in list) Payment.fromJson(Map<String, dynamic>.from(e as Map))],
      paidTotal: (j['paid'] as num?)?.toDouble() ?? (j['paidTotal'] as num?)?.toDouble() ?? 0,
      targetTotal: (j['target'] as num?)?.toDouble() ?? (j['targetTotal'] as num?)?.toDouble() ?? 0,
      balance: (j['balance'] as num?)?.toDouble() ?? 0,
    );
  }
}
