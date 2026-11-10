import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pervaz logosu (işaret) + isteğe bağlı yazı ve slogan.
class BrandLogo extends StatelessWidget {
  final double size;
  final bool showName;
  final bool showTagline;
  final Axis direction;
  final Color? textColor;

  const BrandLogo({
    super.key,
    this.size = 40,
    this.showName = true,
    this.showTagline = false,
    this.direction = Axis.horizontal,
    this.textColor,
  });

  /// Sadece işaret (uygulama simgesi).
  const BrandLogo.mark({super.key, this.size = 40})
      : showName = false,
        showTagline = false,
        direction = Axis.horizontal,
        textColor = null;

  @override
  Widget build(BuildContext context) {
    final mark = Image.asset(
      Brand.markAsset,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stack) => Icon(Icons.window, size: size, color: Brand.petrol),
    );
    if (!showName) return mark;

    final color = textColor ?? Brand.petrolDark;
    final vertical = direction == Axis.vertical;
    final nameSize = vertical ? size * 0.42 : size * 0.62;
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: vertical ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          Brand.appName,
          style: TextStyle(
            fontSize: nameSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: color,
            height: 1.1,
          ),
        ),
        if (showTagline)
          Text(
            Brand.tagline,
            style: TextStyle(
              fontSize: nameSize * 0.36,
              letterSpacing: 1.2,
              color: color.withValues(alpha: 0.65),
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
    return vertical
        ? Column(mainAxisSize: MainAxisSize.min, children: [mark, SizedBox(height: size * 0.18), text])
        : Row(mainAxisSize: MainAxisSize.min, children: [mark, SizedBox(width: size * 0.25), text]);
  }
}
