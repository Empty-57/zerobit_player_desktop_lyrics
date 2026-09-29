import 'package:flutter/material.dart';

class TextDisplayWidget extends StatelessWidget {
  const TextDisplayWidget({
    super.key,
    required this.text,
    required this.furigana,
    required this.style,
    this.strutStyle,
    required this.displayMode,
    required this.useStroke,
    required this.strokeColor,
    required this.showFurigana,
  });

  // 匹配英文字母、数字和空格以及部分标点
  static final _alphanumericRegExp = RegExp(
    r'''^[A-Za-z0-9\s!"#$%&'()*+,-./:：;<=>?@[\]^_`{|}~“”‘’《》〈〉「」『』【】〔〕〖〗（）［］｛｝?？!！—―ー～…]+$''',
  );

  final String text;
  final String furigana;
  final TextStyle style;
  final StrutStyle? strutStyle;
  final Axis displayMode;
  final bool useStroke;
  final int strokeColor;
  final bool showFurigana;

  bool _isAlphanumeric(String value) => _alphanumericRegExp.hasMatch(value);

  Text _text(String value, TextStyle style) =>
      Text(value, style: style, strutStyle: strutStyle);

  @override
  Widget build(BuildContext context) {
    final textStyle = useStroke
        ? style.copyWith(
            shadows: [
              Shadow(
                color: Color(strokeColor),
                offset: const Offset(-1.2, -1.2),
                blurRadius: 1.5,
              ),
            ],
          )
        : style;

    final vertical = displayMode == Axis.vertical;

    final Widget mainText = !vertical
        ? _text(text, textStyle)
        : Flex(
            direction: Axis.vertical,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: .center,
            crossAxisAlignment: .end,
            children: [
              for (final char in text.split(''))
                _isAlphanumeric(char)
                    ? RotatedBox(quarterTurns: 1, child: _text(char, textStyle))
                    : _text(char, textStyle),
            ],
          );

    if (furigana.isEmpty || !showFurigana) {
      return mainText;
    }

    final furiganaStyle = textStyle.copyWith(
      fontSize: (textStyle.fontSize ?? 32) * 0.6,
      height: 1,
    );

    final furiFlex = Flex(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: .center,
      crossAxisAlignment: vertical ? .start : .end,
      direction: vertical ? .vertical : .horizontal,
      children: [
        for (final char in furigana.split('')) _text(char, furiganaStyle),
      ],
    );

    return Flex(
      direction: vertical ? .horizontal : .vertical,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: vertical ? .start : .end,
      crossAxisAlignment: .center,
      children: [if (!vertical) furiFlex, mainText, if (vertical) furiFlex],
    );
  }
}
