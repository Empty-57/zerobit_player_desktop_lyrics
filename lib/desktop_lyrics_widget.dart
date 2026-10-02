import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals/signals_flutter.dart';

import 'controller/desktop_lyrics_ctrl.dart';
import 'desktop_lyrics_client.dart';
import 'tools/lrcTool/furigana_line.dart';
import 'tools/lrcTool/lyric_model.dart';
import 'tools/lrcTool/lyrics_text_display_widget.dart';
import 'tools/lrcTool/progress_shader_mask.dart';
import 'tools/lyric_text_style.dart';

final DesktopLyricsController _desktopLyricsController =
    GetIt.I<DesktopLyricsController>();
final DesktopLyricsClient _lyricsClient = GetIt.I<DesktopLyricsClient>();

/// 正在演唱的那个字：在底色文本之上推进一条「已唱」的渐变。
class _HighlightedWord extends StatelessWidget {
  const _HighlightedWord({
    super.key,
    required this.text,
    required this.progress,
    required this.underStyle,
    required this.overlayStyle,
    required this.strutStyle,
    required this.scale,
    required this.begin,
    required this.end,
    required this.displayMode,
    required this.useStroke,
    required this.strokeColor,
  });

  final String text;
  final ReadonlySignal<double> progress;
  final TextStyle underStyle;
  final TextStyle overlayStyle;
  final StrutStyle? strutStyle;
  final double scale;
  final Alignment begin;
  final Alignment end;
  final Axis displayMode;
  final bool useStroke;
  final int strokeColor;

  @override
  Widget build(BuildContext context) {
    final maskedText = TextDisplayWidget(
      text: text,
      style: underStyle,
      strutStyle: strutStyle,
      displayMode: displayMode,
      useStroke: false,
      strokeColor: strokeColor,
    );

    final shaderText = SignalBuilder(
      builder: (context) => ProgressShaderMask(
        progress: progress.value,
        axis: displayMode,
        scale: scale,
        begin: begin,
        end: end,
        overlayColor: overlayStyle.color!,
        underColor: underStyle.color!,
        child: maskedText,
      ),
    );

    if (!useStroke) return shaderText;

    return Stack(
      children: [
        // 底层只负责描边：正文透明，只有阴影透出来
        TextDisplayWidget(
          text: text,
          style: underStyle.copyWith(color: Colors.transparent),
          strutStyle: strutStyle,
          displayMode: displayMode,
          useStroke: true,
          strokeColor: strokeColor,
        ),
        shaderText,
      ],
    );
  }
}

List<GlobalKey> _makeKeys(int count) =>
    List.generate(count, (_) => GlobalKey(), growable: false);

/// 把第 [index] 个字滚进视野。[alignment] 是它在视口中的落点比例。
Future<void> _ensureIndexVisible(
  List<GlobalKey> keys,
  int index, {
  required double alignment,
}) async {
  if (index < 0 || index >= keys.length) return;
  final context = keys[index].currentContext;
  if (context == null) return;
  await Scrollable.ensureVisible(
    context,
    duration: const Duration(milliseconds: 200),
    curve: Curves.linear,
    alignment: alignment,
  );
}

/// 让当前字始终留在视野内。
///
/// 真正滚动时再取用最新的下标。
mixin _FollowCurrentWord<T extends StatefulWidget> on State<T> {
  /// 下标对应元素所挂的 key，由使用方在 [initState] 调用 `super.initState()`
  /// 之前准备好。
  List<GlobalKey> get followKeys;

  /// 当前字在视口中的落点比例
  double get followAlignment;

  late final EffectCleanup _disposeFollowEffect;
  int _pendingIndex = -1;
  bool _followScheduled = false;

  @override
  void initState() {
    super.initState();
    _disposeFollowEffect = effect(() {
      _pendingIndex = _desktopLyricsController.currentWordIndex.value;
      if (_followScheduled) return;
      _followScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _followScheduled = false;
        if (!mounted) return;
        unawaited(
          _ensureIndexVisible(
            followKeys,
            _pendingIndex,
            alignment: followAlignment,
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _disposeFollowEffect();
    super.dispose();
  }
}

class _KaraokeLine extends StatefulWidget {
  const _KaraokeLine({
    required this.words,
    required this.underStyle,
    required this.overlayStyle,
    required this.strutStyle,
    required this.displayMode,
    required this.begin,
    required this.end,
  });

  final List<WordEntry> words;
  final TextStyle underStyle;
  final TextStyle overlayStyle;
  final StrutStyle? strutStyle;
  final Axis displayMode;
  final Alignment begin;
  final Alignment end;

  @override
  State<_KaraokeLine> createState() => _KaraokeLineState();
}

class _KaraokeLineState extends State<_KaraokeLine>
    with _FollowCurrentWord<_KaraokeLine> {
  final _scrollController = ScrollController();
  List<GlobalKey> _wordKeys = const [];

  @override
  List<GlobalKey> get followKeys => _wordKeys;

  @override
  double get followAlignment => 0.4;

  @override
  void initState() {
    _wordKeys = _makeKeys(widget.words.length);
    super.initState();
  }

  @override
  void didUpdateWidget(_KaraokeLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.words.length != widget.words.length) {
      _wordKeys = _makeKeys(widget.words.length);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: widget.displayMode,
      clipBehavior: Clip.none,
      child: SignalBuilder(
        builder: (context) {
          final ctrl = _desktopLyricsController;
          final currentIndex = ctrl.currentWordIndex.value;
          final useStroke = ctrl.useStroke.value;
          final strokeColor = ctrl.strokeColor.value;

          return FuriganaLine(
            words: widget.words,
            direction: widget.displayMode,
            showFurigana: ctrl.showKana.value,
            furiganaStyle: furiganaTextStyle(
              widget.underStyle,
              useStroke: useStroke,
              strokeColor: strokeColor,
            ),
            buildWord: (index, word) => index == currentIndex
                ? _HighlightedWord(
                    key: _wordKeys[index],
                    text: word.lyricWord,
                    progress: ctrl.wordProgress,
                    underStyle: widget.underStyle,
                    overlayStyle: widget.overlayStyle,
                    strutStyle: widget.strutStyle,
                    scale: word.duration >= 1.0 ? 3 : 2,
                    begin: widget.begin,
                    end: widget.end,
                    displayMode: widget.displayMode,
                    useStroke: useStroke,
                    strokeColor: strokeColor,
                  )
                : TextDisplayWidget(
                    key: _wordKeys[index],
                    text: word.lyricWord,
                    style: index < currentIndex
                        ? widget.overlayStyle
                        : widget.underStyle,
                    strutStyle: widget.strutStyle,
                    displayMode: widget.displayMode,
                    useStroke: useStroke,
                    strokeColor: strokeColor,
                  ),
          );
        },
      ),
    );
  }
}

/// 当前行的翻译。逐段渲染只为了能跟着当前字一起滚动 —— 内容本身与进度无关。
class _TranslateLine extends StatefulWidget {
  const _TranslateLine({
    required this.segments,
    required this.underStyle,
    required this.displayMode,
  });

  final List<String> segments;
  final TextStyle underStyle;
  final Axis displayMode;

  @override
  State<_TranslateLine> createState() => _TranslateLineState();
}

class _TranslateLineState extends State<_TranslateLine>
    with _FollowCurrentWord<_TranslateLine> {
  final _scrollController = ScrollController();
  List<GlobalKey> _segmentKeys = const [];

  @override
  List<GlobalKey> get followKeys => _segmentKeys;

  @override
  double get followAlignment => 0.2;

  @override
  void initState() {
    _segmentKeys = _makeKeys(widget.segments.length);
    super.initState();
  }

  @override
  void didUpdateWidget(_TranslateLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segments.length != widget.segments.length) {
      _segmentKeys = _makeKeys(widget.segments.length);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vertical = widget.displayMode == Axis.vertical;
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: widget.displayMode,
      clipBehavior: Clip.none,
      child: SignalBuilder(
        builder: (context) {
          final ctrl = _desktopLyricsController;
          final useStroke = ctrl.useStroke.value;
          final strokeColor = ctrl.strokeColor.value;

          return Flex(
            direction: widget.displayMode,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: vertical
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < widget.segments.length; i++)
                TextDisplayWidget(
                  key: _segmentKeys[i],
                  text: widget.segments[i],
                  style: widget.underStyle,
                  displayMode: widget.displayMode,
                  useStroke: useStroke,
                  strokeColor: strokeColor,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 当前行歌词。
class LyricsRender extends StatelessWidget {
  const LyricsRender({super.key});

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final ctrl = _desktopLyricsController;

        final line = ctrl.currentLine.value;
        if (line == null) return const SizedBox.shrink();

        final vertical = ctrl.useVerticalDisplayMode.value;
        final displayMode = vertical ? Axis.vertical : Axis.horizontal;
        final fontSize = ctrl.fontSize.value.toDouble();
        final fontFamily = ctrl.fontFamily.value;
        final weight =
            FontWeight.values[ctrl.fontWeight.value.clamp(
              0,
              FontWeight.values.length - 1,
            )];

        final underStyle = lyricTextStyle(
          size: fontSize,
          color: Color(ctrl.underColor.value),
          weight: weight,
          fontFamily: fontFamily,
        );
        final overlayStyle = lyricTextStyle(
          size: fontSize,
          color: Color(ctrl.overlayColor.value),
          weight: weight,
          fontFamily: fontFamily,
        );

        final translate = ctrl.currentTranslate.value;
        final translateLine = _TranslateLine(
          segments: splitTranslate(translate, line.segmentCount),
          underStyle: underStyle,
          displayMode: displayMode,
        );

        return Opacity(
          opacity: ctrl.fontOpacity.value,
          child: Flex(
            direction: vertical ? Axis.horizontal : Axis.vertical,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: ctrl.lrcAlignment.value.resolve(
              isNextLine: false,
              showDoubleLine: ctrl.showDoubleLine.value,
              lineCounter: _lyricsClient.lyricsCounter.value,
            ),
            children: [
              // 竖排时翻译在歌词右侧，横排时在下方
              if (vertical && translate.isNotEmpty) translateLine,
              switch (line) {
                PlainLyricLine(:final text) => TextDisplayWidget(
                  text: text,
                  style: overlayStyle,
                  displayMode: displayMode,
                  useStroke: ctrl.useStroke.value,
                  strokeColor: ctrl.strokeColor.value,
                ),
                KaraokeLyricLine(:final words) => _KaraokeLine(
                  words: words,
                  underStyle: underStyle,
                  overlayStyle: overlayStyle,
                  // 竖排时逐字堆叠，strut 的行高会在字间撑出空隙
                  strutStyle: vertical
                      ? null
                      : StrutStyle(
                          fontSize: fontSize,
                          height: 1,
                          forceStrutHeight: false,
                        ),
                  displayMode: displayMode,
                  begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
                  end: vertical
                      ? Alignment.bottomCenter
                      : Alignment.centerRight,
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
