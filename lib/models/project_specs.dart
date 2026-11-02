class ProjectSpecs {
  final String projectName;
  final int totalWindowCount;
  final double totalAreaM2;
  final List<String> usedProfileTypes;
  final List<String> usedGlassTypes;

  ProjectSpecs({
    required this.projectName,
    required this.totalWindowCount,
    required this.totalAreaM2,
    required this.usedProfileTypes,
    required this.usedGlassTypes,
  });

  factory ProjectSpecs.fromJson(Map<String, dynamic> json) {
    return ProjectSpecs(
      projectName: json['projectName'] ?? '',
      totalWindowCount: json['totalWindowCount'] ?? 0,
      totalAreaM2: (json['totalAreaM2'] as num).toDouble(),
      usedProfileTypes: List<String>.from(json['usedProfileTypes'] ?? []),
      usedGlassTypes: List<String>.from(json['usedGlassTypes'] ?? []),
    );
  }
}