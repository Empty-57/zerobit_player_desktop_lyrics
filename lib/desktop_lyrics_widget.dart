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
  CrossAxisAlignment.start,
];

class _HighlightedWord extends StatelessWidget {
  final String text;
  final double progress;
  final TextStyle underStyle;
  final TextStyle overlayStyle;
  final StrutStyle? strutStyle;
  final double scale;
  final Alignment begin;
  final Alignment end;
  final Axis displayMode;
  final bool useStroke;
  final int strokeColor;

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

  @override
  Widget build(BuildContext context) {
    final shaderText = ShaderMask(
      shaderCallback: (bounds) {
        const double offsetFactor = -0.666;
        final double offset =
            (displayMode == Axis.vertical ? bounds.height : bounds.width) *
            (offsetFactor * (1 - progress));
        return LinearGradient(
          begin: begin,
          end: end,
          colors: [overlayStyle.color!, overlayStyle.color!, underStyle.color!],
          stops: [0.0, 0.333, 0.666],
          transform: displayMode == Axis.vertical
              ? _ScaledVerticalTranslateGradientTransform(
                  dy: offset,
                  scale: scale,
                )
              : _ScaledTranslateGradientTransform(dx: offset, scale: scale),
        ).createShader(bounds);
      },
      blendMode: BlendMode.srcIn,
      child: TextDisplayWidget(
        text: text,
        style: underStyle,
        strutStyle: strutStyle,
        displayMode: displayMode,
        useStroke: false,
        strokeColor: strokeColor,
      ),
    );

    return useStroke
        ? Stack(
            children: [
              // --- 第一层：负责显示阴影 ---
              TextDisplayWidget(
                text: text,
                style: underStyle.copyWith(color: Colors.transparent),
                strutStyle: strutStyle,
                displayMode: displayMode,
                useStroke: true,
                strokeColor: strokeColor,
              ),

              // --- 第二层：负责显示渐变 (ShaderMask) ---
              shaderText,
            ],
          )
        : shaderText;
  }
}

class _ScaledTranslateGradientTransform extends GradientTransform {
  final double dx;
  final double scale;
  const _ScaledTranslateGradientTransform({
    required this.dx,
    required this.scale,
  });
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.identity()
      ..scale(scale, 1.0, 1.0)
      ..translate(dx, 0.0, 0.0);
  }
}

class _ScaledVerticalTranslateGradientTransform extends GradientTransform {
  final double dy;
  final double scale;
  const _ScaledVerticalTranslateGradientTransform({
    required this.dy,
    required this.scale,
  });
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.identity()
      ..scale(1.0, scale, 1.0)
      ..translate(0.0, dy, 0.0);
  }
}

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
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _wordKeys = [];

  @override
  void initState() {
    super.initState();
    _ensureKeys();
  }

  @override
  void didUpdateWidget(covariant _KaraOkLyricWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text.length != widget.text.length) {
      _ensureKeys();
    }
  }

  void _ensureKeys() {
    // 保证每个字都有一个 GlobalKey（尽量复用已有 key）
    if (_wordKeys.length != widget.text.length) {
      _wordKeys
        ..clear()
        ..addAll(List.generate(widget.text.length, (_) => GlobalKey()));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 将目标字滚到可见（居中 alignment 可调整）
  Future<void> _scrollToIndex(int index) async {
    if (index < 0 || index >= _wordKeys.length) return;
    final ctx = _wordKeys[index].currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 200),
      curve: Curves.linear,
      alignment: 0.4,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: widget.displayMode,
      clipBehavior: Clip.none,
      child: Obx(() {
        final currWordIndex = widget.ctrl.currentWordIndex.value;
        // 确保布局已完成
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToIndex(currWordIndex);
        });

        // 构造每个字的 Widget
        return Flex(
          direction: widget.displayMode,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: widget.text.asMap().entries.map((entry) {
            final wordIndex = entry.key;
            final wordEntry = entry.value;
            final word = wordEntry.lyricWord;
            final double scale = wordEntry.duration >= 1.0 ? 3 : 2;
            final isCurrent = wordIndex == currWordIndex;

            Widget child;
            if (isCurrent) {
              child = Obx(
                () => _HighlightedWord(
                  text: word,
                  progress: widget.ctrl.wordProgress.value,
                  underStyle: widget.underStyle,
                  overlayStyle: widget.overlayStyle,
                  strutStyle: widget.strutStyle,
                  scale: scale,
                  begin: widget.begin,
                  end: widget.end,
                  displayMode: widget.displayMode,
                  useStroke: widget.ctrl.useStroke.value,
                  strokeColor: widget.ctrl.strokeColor.value,
                ),
              );
            } else if (wordIndex < currWordIndex) {
              child = TextDisplayWidget(
                text: word,
                style: widget.overlayStyle.copyWith(
                  color: widget.overlayStyle.color,
                ),
                strutStyle: widget.strutStyle,
                displayMode: widget.displayMode,
                useStroke: widget.ctrl.useStroke.value,
                strokeColor: widget.ctrl.strokeColor.value,
              );
            } else {
              child = TextDisplayWidget(
                text: word,
                style: widget.underStyle,
                strutStyle: widget.strutStyle,
                displayMode: widget.displayMode,
                useStroke: widget.ctrl.useStroke.value,
                strokeColor: widget.ctrl.strokeColor.value,
              );
            }

            // 用 RepaintBoundary 降低局部重绘开销
            return RepaintBoundary(key: _wordKeys[wordIndex], child: child);
          }).toList(),
        );
      }),
    );
  }
}

class _TranslateWidget extends StatefulWidget {
  final List<String> text;
  final DesktopLyricsController ctrl;
  final TextStyle underStyle;
  final StrutStyle? strutStyle;
  final Axis displayMode;

  const _TranslateWidget({
    required this.text,
    required this.ctrl,
    required this.underStyle,
    required this.strutStyle,
    required this.displayMode,
  });

  @override
  State<StatefulWidget> createState() => _TranslateWidgetState();
}

class _TranslateWidgetState extends State<_TranslateWidget> {
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _wordKeys = [];

  @override
  void initState() {
    super.initState();
    _ensureKeys();
  }

  @override
  void didUpdateWidget(covariant _TranslateWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text.length != widget.text.length) {
      _ensureKeys();
    }
  }

  void _ensureKeys() {
    // 保证每个字都有一个 GlobalKey（尽量复用已有 key）
    if (_wordKeys.length != widget.text.length) {
      _wordKeys
        ..clear()
        ..addAll(List.generate(widget.text.length, (_) => GlobalKey()));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 将目标字滚到可见（居中 alignment 可调整）
  Future<void> _scrollToIndex(int index) async {
    if (index < 0 || index >= _wordKeys.length) return;
    final ctx = _wordKeys[index].currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 200),
      curve: Curves.linear,
      alignment: 0.2,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: widget.displayMode,
      clipBehavior: Clip.none,
      child: Obx(() {
        final currWordIndex = widget.ctrl.currentWordIndex.value;
        // 确保布局已完成
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToIndex(currWordIndex);
        });

        // 构造每个字的 Widget
        return Flex(
          direction: widget.displayMode,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: widget.text.asMap().entries.map((entry) {
            final wordIndex = entry.key;
            final word = entry.value;

            Widget child = TextDisplayWidget(
              text: word,
              style: widget.underStyle,
              strutStyle: widget.strutStyle,
              displayMode: widget.displayMode,
              useStroke: widget.ctrl.useStroke.value,
              strokeColor: widget.ctrl.strokeColor.value,
            );

            // 用 RepaintBoundary 降低局部重绘开销
            return RepaintBoundary(key: _wordKeys[wordIndex], child: child);
          }).toList(),
        );
      }),
    );
  }
}

class LyricsRender extends StatelessWidget {
  const LyricsRender({super.key});

  List<String> _splitString(String str, int n) {
    if (n <= 0) return str.split('');

    return n >= str.length
        ? str.split('')
        : [...List.generate(n - 1, (i) => str[i]), str.substring(n - 1)];
  }

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
        final currentLine = _desktopLyricsController.currentLine.value;
        CrossAxisAlignment lrcAlignment =
            _lrcCrossAlignment[_desktopLyricsController.lrcAlignment.value];

        if (_desktopLyricsController.lrcAlignment.value == 3&&_desktopLyricsController.showDoubleLine.value) {
          if (_lyricsClient.lyricsCounter.value.isEven) {
            lrcAlignment = _lrcCrossAlignment[0];
          } else {
            lrcAlignment = _lrcCrossAlignment[2];
          }
        }

        if (currentLine == null) {
          return const SizedBox.shrink();
        }
        final currentTranslate =
            _desktopLyricsController.currentTranslate.value;

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
                _TranslateWidget(
                  text: _splitString(currentTranslate, currentLine.length),
                  underStyle: underStyle,
                  strutStyle: null,
                  ctrl: _desktopLyricsController,
                  displayMode: displayMode,
                ),
            ],
          ),
        );
      });
    });
  }
}
