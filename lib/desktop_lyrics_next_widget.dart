import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player_desktop_lyrics/controller/desktop_lyrics_ctrl.dart';
import 'package:zerobit_player_desktop_lyrics/tools/lrcTool/lyrics_text_display_widget.dart';

import '../tools/general_style.dart';
import '../tools/lrcTool/lyric_model.dart';
import 'desktop_lyrics_client.dart';

final DesktopLyricsController _desktopLyricsController =
    GetIt.I<DesktopLyricsController>();
final DesktopLyricsClient _lyricsClient = GetIt.I<DesktopLyricsClient>();

const _lrcCrossAlignment = [
  CrossAxisAlignment.start,
  CrossAxisAlignment.center,
  CrossAxisAlignment.end,
  CrossAxisAlignment.end,
];

class _LrcLyricWidget extends StatelessWidget {
  final String text;
  final TextStyle overlayStyle;
  final Axis displayMode;
  final bool useStroke;
  final int strokeColor;

  const _LrcLyricWidget({
    required this.text,
    required this.overlayStyle,
    required this.displayMode,
    required this.useStroke,
    required this.strokeColor,
  });

  @override
  Widget build(BuildContext context) {
    return TextDisplayWidget(
      text: text,
      showFurigana: false,
      furigana: '',
      style: overlayStyle,
      displayMode: displayMode,
      strutStyle: null,
      useStroke: useStroke,
      strokeColor: strokeColor,
    );
  }
}

class _KaraOkLyricWidget extends StatefulWidget {
  final List<WordEntry> text;
  final TextStyle underStyle;
  final StrutStyle? strutStyle;
  final DesktopLyricsController ctrl;
  final Axis displayMode;
  final Alignment begin;
  final Alignment end;
  final bool showFurigana;

  const _KaraOkLyricWidget({
    required this.text,
    required this.underStyle,
    required this.strutStyle,
    required this.ctrl,
    required this.displayMode,
    required this.begin,
    required this.end,
    required this.showFurigana,
  });

  @override
  State<_KaraOkLyricWidget> createState() => _KaraOkLyricWidgetState();
}

class _KaraOkLyricWidgetState extends State<_KaraOkLyricWidget> {
  Widget _buildFuriganaLine(Widget Function(int, WordEntry) build) {
    final vertical = widget.displayMode == Axis.vertical;
    final List<Widget> lineChildren = [];
    int i = 0;

    final furiganaBaseStyle = widget.underStyle.copyWith(
      fontSize: (widget.underStyle.fontSize ?? 32) * 0.6,
      height: 1,
    );

    final furiganaStyle = widget.ctrl.useStroke.value
        ? furiganaBaseStyle.copyWith(
            shadows: [
              Shadow(
                color: Color(widget.ctrl.strokeColor.value),
                offset: const Offset(-1.2, -1.2),
                blurRadius: 1.5,
              ),
            ],
          )
        : furiganaBaseStyle;

    while (i < widget.text.length) {
      final entry = widget.text[i];

      final groupLen =
          (entry.furigana.isNotEmpty && entry.furiganaGroupLength > 1)
          ? entry.furiganaGroupLength
          : 1;

      final end = (i + groupLen).clamp(0, widget.text.length);

      final words = [for (int j = i; j < end; j++) build(j, widget.text[j])];

      final wordWidget = words.length == 1
          ? words.first
          : Flex(
              direction: widget.displayMode,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: vertical
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: words,
            );

      final furiganaContent = vertical
          ? Flex(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: vertical
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              direction: vertical ? Axis.vertical : Axis.horizontal,
              children: [
                for (final char in entry.furigana.split(''))
                  Text(char, style: furiganaStyle),
              ],
            )
          : Text(
              entry.furigana,
              style: furiganaStyle,
              textAlign: TextAlign.center,
            );

      lineChildren.add(
        entry.furigana.isEmpty || !widget.showFurigana
            ? wordWidget
            : Flex(
                direction: vertical ? Axis.horizontal : Axis.vertical,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: vertical
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (!vertical) furiganaContent,
                  wordWidget,
                  if (vertical) furiganaContent,
                ],
              ),
      );

      i = end;
    }

    return Flex(
      direction: widget.displayMode,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: vertical
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: lineChildren,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: widget.displayMode,
      clipBehavior: Clip.none,
      child: SignalBuilder(
        builder: (context) {
          return _buildFuriganaLine((wordIndex, wordEntry) {
            final word = wordEntry.lyricWord;

            return TextDisplayWidget(
              text: word,
              showFurigana: false,
              furigana: '',
              style: widget.underStyle,
              strutStyle: widget.strutStyle,
              displayMode: widget.displayMode,
              useStroke: widget.ctrl.useStroke.value,
              strokeColor: widget.ctrl.strokeColor.value,
            );
          });
        },
      ),
    );
  }
}

class LyricsNextRender extends StatelessWidget {
  const LyricsNextRender({super.key});

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final isVertical =
            _desktopLyricsController.useVerticalDisplayMode.value;
        final fontSize = _desktopLyricsController.fontSize.value;
        final fontWeight = _desktopLyricsController.fontWeight.value;

        final displayMode = isVertical ? Axis.vertical : Axis.horizontal;
        final begin = isVertical ? Alignment.topCenter : Alignment.centerLeft;
        final end = isVertical ? Alignment.bottomCenter : Alignment.centerRight;

        final underStyle = generalTextStyle(
          ctx: context,
          size: fontSize,
          color: Color(_desktopLyricsController.underColor.value),
          weight: FontWeight.values[fontWeight],
        );

        final strutStyle = StrutStyle(
          fontSize: fontSize.toDouble(),
          forceStrutHeight: false,
          height: 1,
        );

        final lrcType = _desktopLyricsController.lrcType.value;
        final currentLine = _desktopLyricsController.nextLine.value;

        CrossAxisAlignment lrcAlignment =
            _lrcCrossAlignment[_desktopLyricsController.lrcAlignment.value];

        if (_desktopLyricsController.lrcAlignment.value == 3 &&
            _desktopLyricsController.showDoubleLine.value) {
          if (_lyricsClient.lyricsCounter.value.isEven) {
            lrcAlignment = _lrcCrossAlignment[2];
          } else {
            lrcAlignment = _lrcCrossAlignment[0];
          }
        }

        if (currentLine == null) {
          return const SizedBox.shrink();
        }

        final currentTranslate = _desktopLyricsController.nextTranslate.value;

        final tr = _LrcLyricWidget(
          text: currentTranslate,
          overlayStyle: underStyle,
          displayMode: displayMode,
          useStroke: _desktopLyricsController.useStroke.value,
          strokeColor: _desktopLyricsController.strokeColor.value,
        );

        return Opacity(
          opacity: _desktopLyricsController.fontOpacity.value,
          child: Flex(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: lrcAlignment,
            direction: isVertical ? Axis.horizontal : Axis.vertical,
            children: [
              if (isVertical && currentTranslate.isNotEmpty) tr,
              if (lrcType == LyricFormat.lrc)
                _LrcLyricWidget(
                  text: currentLine is String ? currentLine : '',
                  overlayStyle: underStyle,
                  displayMode: displayMode,
                  useStroke: _desktopLyricsController.useStroke.value,
                  strokeColor: _desktopLyricsController.strokeColor.value,
                )
              else
                _KaraOkLyricWidget(
                  text: currentLine is List<WordEntry>
                      ? currentLine
                      : [
                          WordEntry(
                            start: 0.0,
                            duration: 0.0,
                            lyricWord: '',
                            furigana: '',
                          ),
                        ],
                  underStyle: underStyle,
                  strutStyle: displayMode == Axis.vertical ? null : strutStyle,
                  ctrl: _desktopLyricsController,
                  displayMode: displayMode,
                  begin: begin,
                  end: end,
                  showFurigana: _desktopLyricsController.showKana.value,
                ),
              if (!isVertical && currentTranslate.isNotEmpty) tr,
            ],
          ),
        );
      },
    );
  }
}
