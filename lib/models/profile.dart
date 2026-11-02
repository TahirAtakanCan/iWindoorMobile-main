class Profile {
  final int id;
  final String name;
  final String code;
  final double pricePerMeter;

  Profile({required this.id, required this.name, required this.code, required this.pricePerMeter});

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'],
      name: json['name'],
      code: json['code'],
      pricePerMeter: (json['pricePerMeter'] as num).toDouble(),
    );
  }
}

// Cam Modeli
class Glass {
  final int id;
  final String name;
  final String code;
  final double pricePerSquareMeter;

  Glass({required this.id, required this.name, required this.code, required this.pricePerSquareMeter});

  factory Glass.fromJson(Map<String, dynamic> json) {
    return Glass(
      id: json['id'],
      name: json['name'],
      code: json['code'] ?? '',
      pricePerSquareMeter: (json['pricePerSquareMeter'] as num).toDouble(),
    );
  }
}