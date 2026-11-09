import 'package:flutter/material.dart';

/// Proje iş durumu.
enum ProjectStatus {
  quote,
  approved,
  production,
  installation,
  delivered,
  cancelled;

  static ProjectStatus fromApi(Object? v) {
    final s = '${v ?? ''}'.trim().toUpperCase();
    return switch (s) {
      'APPROVED' => ProjectStatus.approved,
      'PRODUCTION' => ProjectStatus.production,
      'INSTALLATION' || 'INSTALL' => ProjectStatus.installation,
      'DELIVERED' || 'DONE' => ProjectStatus.delivered,
      'CANCELLED' || 'CANCELED' => ProjectStatus.cancelled,
      _ => ProjectStatus.quote,
    };
  }

  String get apiValue => switch (this) {
        ProjectStatus.quote => 'QUOTE',
        ProjectStatus.approved => 'APPROVED',
        ProjectStatus.production => 'PRODUCTION',
        ProjectStatus.installation => 'INSTALLATION',
        ProjectStatus.delivered => 'DELIVERED',
        ProjectStatus.cancelled => 'CANCELLED',
      };

  String get labelTr => switch (this) {
        ProjectStatus.quote => 'Teklif',
        ProjectStatus.approved => 'Onaylandı',
        ProjectStatus.production => 'Üretimde',
        ProjectStatus.installation => 'Montajda',
        ProjectStatus.delivered => 'Teslim edildi',
        ProjectStatus.cancelled => 'İptal',
      };

  Color get color => switch (this) {
        ProjectStatus.quote => Colors.grey,
        ProjectStatus.approved => Colors.blue,
        ProjectStatus.production => Colors.orange,
        ProjectStatus.installation => Colors.purple,
        ProjectStatus.delivered => Colors.green,
        ProjectStatus.cancelled => Colors.red,
      };

  /// İleri geçiş (Sonraki adım). İptal / geri ayrı.
  ProjectStatus? get nextForward => switch (this) {
        ProjectStatus.quote => ProjectStatus.approved,
        ProjectStatus.approved => ProjectStatus.production,
        ProjectStatus.production => ProjectStatus.installation,
        ProjectStatus.installation => ProjectStatus.delivered,
        _ => null,
      };

  String? get nextForwardActionLabel => switch (nextForward) {
        ProjectStatus.approved => 'Onayla',
        ProjectStatus.production => 'Üretime al',
        ProjectStatus.installation => 'Montaja çıkar',
        ProjectStatus.delivered => 'Teslim et',
        _ => null,
      };

  /// Bir adım geri (iptal hariç).
  ProjectStatus? get previous => switch (this) {
        ProjectStatus.approved => ProjectStatus.quote,
        ProjectStatus.production => ProjectStatus.approved,
        ProjectStatus.installation => ProjectStatus.production,
        ProjectStatus.delivered => ProjectStatus.installation,
        _ => null,
      };

  static const allOrdered = [
    ProjectStatus.quote,
    ProjectStatus.approved,
    ProjectStatus.production,
    ProjectStatus.installation,
    ProjectStatus.delivered,
    ProjectStatus.cancelled,
  ];
}

/// İzinli ileri geçiş haritası (testler için).
Map<ProjectStatus, ProjectStatus?> get statusForwardMap => {
      for (final s in ProjectStatus.values) s: s.nextForward,
    };
