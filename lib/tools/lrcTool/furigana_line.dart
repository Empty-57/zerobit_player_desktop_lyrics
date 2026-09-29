import 'package:flutter/material.dart';

import '../lyric_text_style.dart';
import 'lyric_model.dart';

/// 注音样式
TextStyle furiganaTextStyle(
  TextStyle base, {
  required bool useStroke,
  required int strokeColor,
}) {
  final style = base.copyWith(fontSize: (base.fontSize ?? 32) * 0.6, height: 1);
  return useStroke ? withLyricStroke(style, strokeColor) : style;
}

/// 一行逐字歌词的注音排版。
///
/// 连续 [WordEntry.furiganaGroupLength] 个字共享**组首字**上的那段注音，
/// 用于熟字训与复合词——例如「今日」整体注作「きょう」，而不是逐字拆开。
class FuriganaLine extends StatelessWidget {
  const FuriganaLine({
    super.key,
    required this.words,
    required this.direction,
    required this.furiganaStyle,
    required this.showFurigana,
    required this.buildWord,
  });

  final List<WordEntry> words;
  final Axis direction;
  final TextStyle furiganaStyle;
  final bool showFurigana;
  final Widget Function(int index, WordEntry word) buildWord;

  @override
  Widget build(BuildContext context) {
    final vertical = direction == Axis.vertical;
    final groups = <Widget>[];

    var i = 0;
    while (i < words.length) {
      final entry = words[i];
      final groupLength =
          (entry.furigana.isNotEmpty && entry.furiganaGroupLength > 1)
          ? entry.furiganaGroupLength
          : 1;

      final end = (i + groupLength).clamp(0, words.length);

      final built = [for (var j = i; j < end; j++) buildWord(j, words[j])];
      final wordWidget = built.length == 1
          ? built.first
          : Flex(
              direction: direction,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: vertical
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: built,
            );

      groups.add(
        entry.furigana.isEmpty || !showFurigana
            ? wordWidget
            : Flex(
                direction: vertical ? Axis.horizontal : Axis.vertical,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: vertical
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (!vertical) _furigana(entry.furigana, vertical: vertical),
                  wordWidget,
                  if (vertical) _furigana(entry.furigana, vertical: vertical),
                ],
              ),
      );

      i = end;
    }

    return Flex(
      direction: direction,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: vertical
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: groups,
    );
  }

  Widget _furigana(String furigana, {required bool vertical}) => vertical
      ? Flex(
          direction: Axis.vertical,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final char in furigana.split(''))
              Text(char, style: furiganaStyle),
          ],
        )
      : Text(furigana, style: furiganaStyle, textAlign: TextAlign.center);
}
