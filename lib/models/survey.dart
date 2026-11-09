import '../utils/survey_helpers.dart';

class SurveyPhoto {
  final int id;
  final String? url;
  final String? thumbUrl;

  const SurveyPhoto({required this.id, this.url, this.thumbUrl});

  factory SurveyPhoto.fromJson(Map<String, dynamic> j) => SurveyPhoto(
        id: (j['id'] as num).toInt(),
        url: j['url'] as String? ?? j['path'] as String?,
        thumbUrl: j['thumbUrl'] as String? ?? j['thumbnailUrl'] as String? ?? j['url'] as String?,
      );
}

class SurveyItem {
  final int id;
  final String room;
  final SurveyProductType productType;
  final double openingWidthMm;
  final double openingHeightMm;
  final double suggestedWidthMm;
  final double suggestedHeightMm;
  final int quantity;
  final String? note;
  final int? linkedWindowId;
  final String? linkedWindowName;
  final List<SurveyPhoto> photos;

  const SurveyItem({
    required this.id,
    required this.room,
    required this.productType,
    required this.openingWidthMm,
    required this.openingHeightMm,
    required this.suggestedWidthMm,
    required this.suggestedHeightMm,
    this.quantity = 1,
    this.note,
    this.linkedWindowId,
    this.linkedWindowName,
    this.photos = const [],
  });

  bool get isLinked => linkedWindowId != null;

  factory SurveyItem.fromJson(Map<String, dynamic> j) {
    final gap = (j['gapMm'] as num?)?.toDouble();
    final ow = (j['openingWidthMm'] as num?)?.toDouble() ??
        (j['widthMm'] as num?)?.toDouble() ??
        (j['width'] as num?)?.toDouble() ??
        0;
    final oh = (j['openingHeightMm'] as num?)?.toDouble() ??
        (j['heightMm'] as num?)?.toDouble() ??
        (j['height'] as num?)?.toDouble() ??
        0;
    var sw = (j['suggestedWidthMm'] as num?)?.toDouble() ?? (j['windowWidthMm'] as num?)?.toDouble();
    var sh = (j['suggestedHeightMm'] as num?)?.toDouble() ?? (j['windowHeightMm'] as num?)?.toDouble();
    if (sw == null || sh == null) {
      final s = suggestedWindowSize(ow, oh, gap ?? 10);
      sw ??= s.$1;
      sh ??= s.$2;
    }
    return SurveyItem(
      id: (j['id'] as num).toInt(),
      room: j['room'] as String? ?? j['roomName'] as String? ?? '',
      productType: surveyProductFromApi(j['productType'] ?? j['type'] ?? j['kind']),
      openingWidthMm: ow,
      openingHeightMm: oh,
      suggestedWidthMm: sw,
      suggestedHeightMm: sh,
      quantity: (j['quantity'] as num?)?.toInt() ?? 1,
      note: j['note'] as String? ?? j['notes'] as String?,
      linkedWindowId: (j['linkedWindowId'] as num?)?.toInt() ?? (j['windowId'] as num?)?.toInt(),
      linkedWindowName: j['linkedWindowName'] as String? ?? j['windowName'] as String?,
      photos: [
        for (final p in (j['photos'] as List? ?? const []))
          SurveyPhoto.fromJson(Map<String, dynamic>.from(p as Map)),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
        'room': room,
        'productType': surveyProductApi(productType),
        'openingWidthMm': openingWidthMm,
        'openingHeightMm': openingHeightMm,
        'quantity': quantity,
        if (note != null && note!.isNotEmpty) 'note': note,
      };
}
