import 'dart:ui';

import 'package:flutter/material.dart';

abstract final class ReaderVisualTokens {
  static const paper = Color(0xfff8f5ef);
  static const contentHorizontal = 28.0;
  static const bodyFontSize = 21.0;
  static const bodyLineHeight = 31 / 21;
  static const topBlurHeight = 148.0;
  static const bottomBlurHeight = 98.0;
  static const edgeBlurOffset = -8.0;
  static const blurSigma = 9.1;
  static const edgeGradientStops = <double>[0, .22, .5, .72, 1];

  static List<Color> edgeGradientColors(Color surface) => <Color>[
    surface.withValues(alpha: .196),
    surface.withValues(alpha: .188),
    surface.withValues(alpha: .16),
    surface.withValues(alpha: .084),
    surface.withValues(alpha: 0),
  ];
}

enum ReaderEdgeBlurPlacement { top, bottom }

class ReaderEdgeBlur extends StatelessWidget {
  const ReaderEdgeBlur({required this.placement, super.key});

  final ReaderEdgeBlurPlacement placement;

  @override
  Widget build(BuildContext context) {
    final isTop = placement == ReaderEdgeBlurPlacement.top;
    final surface = Theme.of(context).scaffoldBackgroundColor;
    return Positioned(
      key: Key('reader-${isTop ? 'top' : 'bottom'}-edge-blur'),
      top: isTop ? ReaderVisualTokens.edgeBlurOffset : null,
      bottom: isTop ? null : ReaderVisualTokens.edgeBlurOffset,
      left: 0,
      right: 0,
      height: isTop
          ? ReaderVisualTokens.topBlurHeight
          : ReaderVisualTokens.bottomBlurHeight,
      child: IgnorePointer(
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: ReaderVisualTokens.blurSigma,
              sigmaY: ReaderVisualTokens.blurSigma,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: isTop ? Alignment.bottomCenter : Alignment.topCenter,
                  end: isTop ? Alignment.topCenter : Alignment.bottomCenter,
                  colors: ReaderVisualTokens.edgeGradientColors(surface),
                  stops: ReaderVisualTokens.edgeGradientStops,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
