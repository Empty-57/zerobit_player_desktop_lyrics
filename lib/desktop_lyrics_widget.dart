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

/// 沿 [axis] 平移渐变并在该方向上缩放，用于把「已唱 / 未唱」的分界推到字的某个位置。
class _ProgressGradientTransform extends GradientTransform {
  const _ProgressGradientTransform({
    required this.axis,
    required this.offset,
    required this.scale,
  });

  final Axis axis;
  final double offset;
  final double scale;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      axis == Axis.vertical
      ? (Matrix4.diagonal3Values(1, scale, 1)
          ..setTranslationRaw(0, scale * offset, 0))
      : (Matrix4.diagonal3Values(scale, 1, 1)
          ..setTranslationRaw(scale * offset, 0, 0));

  /// 值相等时可跳过重建着色器。
  @override
  bool operator ==(Object other) =>
      other is _ProgressGradientTransform &&
      other.axis == axis &&
      other.offset == offset &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(axis, offset, scale);
}

/// 正在演唱的那个字：在底色文本之上用 [ShaderMask] 推进一条「已唱」的渐变。
class _HighlightedWord extends StatelessWidget {
  const _HighlightedWord({
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
      builder: (context) {
        final value = progress.value;
        return ShaderMask(
          shaderCallback: (bounds) {
            const offsetFactor = -0.666;
            final extent = displayMode == Axis.vertical
                ? bounds.height
                : bounds.width;
            return LinearGradient(
              begin: begin,
              end: end,
              colors: [
                overlayStyle.color!,
                overlayStyle.color!,
                underStyle.color!,
              ],
              stops: const [0.0, 0.333, 0.666],
              transform: _ProgressGradientTransform(
                axis: displayMode,
                offset: extent * offsetFactor * (1 - value),
                scale: scale,
              ),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: maskedText,
        );
      },
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

class _KaraokeLineState extends State<_KaraokeLine> {
  final _scrollController = ScrollController();
  List<GlobalKey> _wordKeys = const [];
  late final EffectCleanup _disposeScrollEffect;

  @override
  void initState() {
    super.initState();
    _wordKeys = _makeKeys(widget.words.length);
    _disposeScrollEffect = effect(() {
      final index = _desktopLyricsController.currentWordIndex.value;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ensureIndexVisible(_wordKeys, index, alignment: 0.4);
      });
    });
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
    _disposeScrollEffect();
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
            buildWord: (index, word) => RepaintBoundary(
              key: _wordKeys[index],
              child: index == currentIndex
                  ? _HighlightedWord(
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
                      text: word.lyricWord,
                      style: index < currentIndex
                          ? widget.overlayStyle
                          : widget.underStyle,
                      strutStyle: widget.strutStyle,
                      displayMode: widget.displayMode,
                      useStroke: useStroke,
                      strokeColor: strokeColor,
                    ),
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

class _TranslateLineState extends State<_TranslateLine> {
  final _scrollController = ScrollController();
  List<GlobalKey> _segmentKeys = const [];
  late final EffectCleanup _disposeScrollEffect;

  @override
  void initState() {
    super.initState();
    _segmentKeys = _makeKeys(widget.segments.length);
    _disposeScrollEffect = effect(() {
      final index = _desktopLyricsController.currentWordIndex.value;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ensureIndexVisible(_segmentKeys, index, alignment: 0.2);
      });
    });
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
    _disposeScrollEffect();
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
                RepaintBoundary(
                  key: _segmentKeys[i],
                  child: TextDisplayWidget(
                    text: widget.segments[i],
                    style: widget.underStyle,
                    displayMode: widget.displayMode,
                    useStroke: useStroke,
                    strokeColor: strokeColor,
                  ),
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
