import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zerobit_player_desktop_lyrics/tools/lrcTool/lyrics_text_display_widget.dart';
import '../tools/general_style.dart';
import '../tools/lrcTool/lyric_model.dart';
import 'desktop_lyrics_client.dart';
import 'getx_ctrl/desktop_lyrics_ctrl.dart';

final DesktopLyricsController _desktopLyricsController =
    Get.find<DesktopLyricsController>();
final DesktopLyricsClient _lyricsClient = Get.find<DesktopLyricsClient>();
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
  final TextStyle overlayStyle;
  final StrutStyle? strutStyle;
  final DesktopLyricsController ctrl;
  final Axis displayMode;
  final Alignment begin;
  final Alignment end;

  const _KaraOkLyricWidget({
    required this.text,
    required this.underStyle,
    required this.overlayStyle,
    required this.strutStyle,
    required this.ctrl,
    required this.displayMode,
    required this.begin,
    required this.end,
  });

  @override
  State<_KaraOkLyricWidget> createState() => _KaraOkLyricWidgetState();
}

class _KaraOkLyricWidgetState extends State<_KaraOkLyricWidget> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: widget.displayMode,
      clipBehavior: Clip.none,
      child: Obx(() {
        // 构造每个字的 Widget
        return Flex(
          direction: widget.displayMode,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: widget.text.asMap().entries.map((entry) {
            final wordEntry = entry.value;
            final word = wordEntry.lyricWord;

            return TextDisplayWidget(
              text: word,
              style: widget.underStyle,
              strutStyle: widget.strutStyle,
              displayMode: widget.displayMode,
              useStroke: widget.ctrl.useStroke.value,
              strokeColor: widget.ctrl.strokeColor.value,
            );
          }).toList(),
        );
      }),
    );
  }
}

class LyricsNextRender extends StatelessWidget {
  const LyricsNextRender({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final fontSize = _desktopLyricsController.fontSize.value;
      final fontWeight = _desktopLyricsController.fontWeight.value;
      final displayMode = _desktopLyricsController.useVerticalDisplayMode.value
          ? Axis.vertical
          : Axis.horizontal;
      final begin = _desktopLyricsController.useVerticalDisplayMode.value
          ? Alignment.topCenter
          : Alignment.centerLeft;
      final end = _desktopLyricsController.useVerticalDisplayMode.value
          ? Alignment.bottomCenter
          : Alignment.centerRight;

      final underStyle = generalTextStyle(
        ctx: context,
        size: fontSize,
        color: Color(_desktopLyricsController.underColor.value),
        weight: FontWeight.values[fontWeight],
      );

      final overlayStyle = generalTextStyle(
        ctx: context,
        size: fontSize,
        color: Color(_desktopLyricsController.overlayColor.value),
        weight: FontWeight.values[fontWeight],
      );

      final strutStyle = StrutStyle(
        fontSize: fontSize.toDouble(),
        forceStrutHeight: true,
      );
      return Obx(() {
        final lrcType = _desktopLyricsController.lrcType.value;
        final currentLine = _desktopLyricsController.nextLine.value;
        CrossAxisAlignment lrcAlignment =
            _lrcCrossAlignment[_desktopLyricsController.lrcAlignment.value];

        if (_desktopLyricsController.lrcAlignment.value == 3&&_desktopLyricsController.showDoubleLine.value) {
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

        return Opacity(
          opacity: _desktopLyricsController.fontOpacity.value,
          child: Flex(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: lrcAlignment, // 切换对齐方式
            direction: _desktopLyricsController.useVerticalDisplayMode.value
                ? Axis.horizontal
                : Axis.vertical,
            children: [
              if (lrcType == LyricFormat.lrc)
                _LrcLyricWidget(
                  text: currentLine as String,
                  overlayStyle: overlayStyle,
                  displayMode: displayMode,
                  useStroke: _desktopLyricsController.useStroke.value,
                  strokeColor: _desktopLyricsController.strokeColor.value,
                )
              else
                _KaraOkLyricWidget(
                  text: currentLine as List<WordEntry>,
                  underStyle: underStyle,
                  overlayStyle: overlayStyle,
                  strutStyle: displayMode == Axis.vertical ? null : strutStyle,
                  ctrl: _desktopLyricsController,
                  displayMode: displayMode,
                  begin: begin,
                  end: end,
                ),
              if (currentTranslate.isNotEmpty)
                _LrcLyricWidget(
                  text: currentTranslate,
                  overlayStyle: underStyle,
                  displayMode: displayMode,
                  useStroke: _desktopLyricsController.useStroke.value,
                  strokeColor: _desktopLyricsController.strokeColor.value,
                ),
            ],
          ),
        );
      });
    });
  }
}
