import 'package:flutter/material.dart';

/// 抽象出通用的文本展示Widget，避免重复的Flex布局
class TextDisplayWidget extends StatelessWidget {
  final String text;
  final TextStyle style;
  final StrutStyle? strutStyle;
  final Axis displayMode;
  final bool useStroke;
  final int strokeColor;

  const TextDisplayWidget({
    super.key,
    required this.text,
    required this.style,
    this.strutStyle,
    required this.displayMode,
    required this.useStroke,
    required this.strokeColor,
  });

  bool _isAlphanumeric(String input) {
    RegExp regExp = RegExp(
      r'''^[A-Za-z0-9 !"'?.,:;()\[\]\-《》「」（）：/“”]+$''',
    ); //匹配英文字母、数字和空格以及部分标点
    return regExp.hasMatch(input);
  }

  Widget _createText({required String char}) {
    final style_ = useStroke
        ? style.copyWith(
            shadows: [
              Shadow(
                color: Color(strokeColor),
                offset: Offset(-1.2, -1.2),
                blurRadius: 1.5,
              ),
            ],
          )
        : style;
    return Text(char, style: style_, strutStyle: strutStyle);
  }

  @override
  Widget build(BuildContext context) {
    // 单字符直接使用 Text，多字符使用 Flex 拆分

    final isAlphanumeric = _isAlphanumeric(text);
    if ((text.length == 1 && !isAlphanumeric) ||
        displayMode == Axis.horizontal) {
      return _createText(char: text);
    } else {
      return Flex(
        direction: displayMode,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        clipBehavior: Clip.none,
        children: text.split('').map((char) {
          if (_isAlphanumeric(char)) {
            return RotatedBox(quarterTurns: 1, child: _createText(char: char));
          }
          return _createText(char: char);
        }).toList(),
      );
    }
  }
}
