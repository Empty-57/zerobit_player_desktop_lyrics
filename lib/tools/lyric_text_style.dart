import 'package:flutter/widgets.dart';

/// 歌词文本样式。
///
/// 行高固定为 1.0：竖排模式下正文逐字堆叠，额外行距会在字间撑出空隙。
TextStyle lyricTextStyle({
  required double size,
  required Color color,
  required FontWeight weight,
  required String fontFamily,
}) => TextStyle(
  color: color,
  fontSize: size,
  fontWeight: weight,
  fontFamily: fontFamily,
  decoration: TextDecoration.none,
  height: 1.0,
);

/// 描边效果
int? _cachedStrokeColor;
List<Shadow> _cachedStrokeShadows = const [];

List<Shadow> _strokeShadows(int strokeColor) {
  if (_cachedStrokeColor != strokeColor) {
    _cachedStrokeColor = strokeColor;
    _cachedStrokeShadows = [
      Shadow(
        color: Color(strokeColor),
        offset: const Offset(-1.2, -1.2),
        blurRadius: 1.5,
      ),
    ];
  }
  return _cachedStrokeShadows;
}

TextStyle withLyricStroke(TextStyle style, int strokeColor) =>
    style.copyWith(shadows: _strokeShadows(strokeColor));

/// 工具栏图标尺寸档位。
enum IconSize {
  sm(18.0),
  md(20.0),
  lg(22.0);

  const IconSize(this.px);

  final double px;
}
