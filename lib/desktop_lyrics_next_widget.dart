import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals/signals_flutter.dart';

import 'controller/desktop_lyrics_ctrl.dart';
import 'desktop_lyrics_client.dart';
import 'tools/lrcTool/furigana_line.dart';
import 'tools/lrcTool/lyric_model.dart';
import 'tools/lrcTool/lyrics_text_display_widget.dart';
import 'tools/lyric_text_style.dart';

final DesktopLyricsController _desktopLyricsController =
    GetIt.I<DesktopLyricsController>();
final DesktopLyricsClient _lyricsClient = GetIt.I<DesktopLyricsClient>();

/// 下一行的逐字歌词
class _NextKaraokeLine extends StatelessWidget {
  const _NextKaraokeLine({
    required this.words,
    required this.underStyle,
    required this.strutStyle,
    required this.displayMode,
    required this.showFurigana,
    required this.useStroke,
    required this.strokeColor,
  });

  final List<WordEntry> words;
  final TextStyle underStyle;
  final StrutStyle? strutStyle;
  final Axis displayMode;
  final bool showFurigana;
  final bool useStroke;
  final int strokeColor;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: displayMode,
    clipBehavior: Clip.none,
    child: FuriganaLine(
      words: words,
      direction: displayMode,
      showFurigana: showFurigana,
      furiganaStyle: furiganaTextStyle(
        underStyle,
        useStroke: useStroke,
        strokeColor: strokeColor,
      ),
      buildWord: (_, word) => TextDisplayWidget(
        text: word.lyricWord,
        style: underStyle,
        strutStyle: strutStyle,
        displayMode: displayMode,
        useStroke: useStroke,
        strokeColor: strokeColor,
      ),
    ),
  );
}

/// 下一行歌词
class LyricsNextRender extends StatelessWidget {
  const LyricsNextRender({super.key});

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final ctrl = _desktopLyricsController;

        final line = ctrl.nextLine.value;
        if (line == null) return const SizedBox.shrink();

        final vertical = ctrl.useVerticalDisplayMode.value;
        final displayMode = vertical ? Axis.vertical : Axis.horizontal;
        final fontSize = ctrl.fontSize.value.toDouble();
        final useStroke = ctrl.useStroke.value;
        final strokeColor = ctrl.strokeColor.value;

        final underStyle = lyricTextStyle(
          size: fontSize,
          color: Color(ctrl.underColor.value),
          weight:
              FontWeight.values[ctrl.fontWeight.value.clamp(
                0,
                FontWeight.values.length - 1,
              )],
          fontFamily: ctrl.fontFamily.value,
        );

        final translate = ctrl.nextTranslate.value;
        final translateLine = TextDisplayWidget(
          text: translate,
          style: underStyle,
          displayMode: displayMode,
          useStroke: useStroke,
          strokeColor: strokeColor,
        );

        return Opacity(
          opacity: ctrl.fontOpacity.value,
          child: Flex(
            direction: vertical ? Axis.horizontal : Axis.vertical,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: ctrl.lrcAlignment.value.resolve(
              isNextLine: true,
              showDoubleLine: ctrl.showDoubleLine.value,
              lineCounter: _lyricsClient.lyricsCounter.value,
            ),
            children: [
              if (vertical && translate.isNotEmpty) translateLine,
              switch (line) {
                PlainLyricLine(:final text) => TextDisplayWidget(
                  text: text,
                  style: underStyle,
                  displayMode: displayMode,
                  useStroke: useStroke,
                  strokeColor: strokeColor,
                ),
                KaraokeLyricLine(:final words) => _NextKaraokeLine(
                  words: words,
                  underStyle: underStyle,
                  // 竖排时逐字堆叠，strut 的行高会在字间撑出空隙
                  strutStyle: vertical
                      ? null
                      : StrutStyle(
                          fontSize: fontSize,
                          height: 1,
                          forceStrutHeight: false,
                        ),
                  displayMode: displayMode,
                  showFurigana: ctrl.showKana.value,
                  useStroke: useStroke,
                  strokeColor: strokeColor,
                ),
              },
              if (!vertical && translate.isNotEmpty) translateLine,
            ],
          ),
        );
      },
    );
  }
}
