import 'package:flutter/material.dart';

import '../lyric_text_style.dart';

/// 一段歌词文本。
///
/// 横排时就是一个 [Text]；竖排时逐字堆叠，并把拉丁字母与标点旋转 90°，
/// 以贴合竖排阅读习惯。
class TextDisplayWidget extends StatelessWidget {
  const TextDisplayWidget({
    super.key,
    required this.text,
    required this.style,
    required this.displayMode,
    required this.useStroke,
    required this.strokeColor,
    this.strutStyle,
  });

  final String text;
  final TextStyle style;
  final StrutStyle? strutStyle;
  final Axis displayMode;
  final bool useStroke;
  final int strokeColor;

  /// 竖排时需要旋转的全角标点。ASCII 与空白按码位区间判断，不列入此集合。
  ///
  /// 比每次跑正则效率高
  static const _rotatedPunctuation = <int>{
    0x2014, 0x2015, // — ―
    0x2018, 0x2019, 0x201C, 0x201D, // ‘ ’ “ ”
    0x2026, // …
    0x3008, 0x3009, 0x300A, 0x300B, // 〈 〉 《 》
    0x300C, 0x300D, 0x300E, 0x300F, // 「 」 『 』
    0x3010, 0x3011, // 【 】
    0x3014, 0x3015, 0x3016, 0x3017, // 〔 〕 〖 〗
    0x30FC, // ー
    0xFF01, // ！
    0xFF08, 0xFF09, // （ ）
    0xFF1A, 0xFF1F, // ： ？
    0xFF3B, 0xFF3D, // ［ ］
    0xFF5B, 0xFF5D, 0xFF5E, // ｛ ｝ ～
  };

  /// 空白区间
  static bool _isWhitespace(int code) =>
      (code >= 0x09 && code <= 0x0D) ||
      code == 0x20 ||
      code == 0xA0 ||
      code == 0x1680 ||
      (code >= 0x2000 && code <= 0x200A) ||
      code == 0x2028 ||
      code == 0x2029 ||
      code == 0x202F ||
      code == 0x205F ||
      code == 0x3000 ||
      code == 0xFEFF;

  /// 竖排时该字符是否需要旋转 90°。
  static bool _needsRotation(String char) {
    // 代理对（emoji 等星平面字符）长度为 2，不旋转
    if (char.length != 1) return false;
    final code = char.codeUnitAt(0);
    // 空格与全部 ASCII 可见字符：字母、数字、半角标点
    if (code >= 0x20 && code <= 0x7E) return true;
    if (_isWhitespace(code)) return true;
    return _rotatedPunctuation.contains(code);
  }

  Widget _char(String value, TextStyle style) {
    final child = Text(value, style: style, strutStyle: strutStyle);
    return _needsRotation(value)
        ? RotatedBox(quarterTurns: 1, child: child)
        : child;
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = useStroke ? withLyricStroke(style, strokeColor) : style;

    if (displayMode != Axis.vertical) {
      return Text(text, style: textStyle, strutStyle: strutStyle);
    }

    final chars = text.split('');
    if (chars.length == 1) return _char(chars.first, textStyle);

    return Flex(
      direction: Axis.vertical,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [for (final char in chars) _char(char, textStyle)],
    );
  }
}
