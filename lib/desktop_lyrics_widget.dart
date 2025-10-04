import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../tools/general_style.dart';
import '../tools/lrcTool/lyric_model.dart';
import 'getx_ctrl/desktop_lyrics_ctrl.dart';

final DesktopLyricsController _desktopLyricsController =
    Get.find<DesktopLyricsController>();

class _HighlightedWord extends StatelessWidget {
  final String text;
  final double progress;
  final TextStyle underStyle;
  final TextStyle overlayStyle;
  final StrutStyle strutStyle;
  final double scale;

  const _HighlightedWord({
    required this.text,
    required this.progress,
    required this.underStyle,
    required this.overlayStyle,
    required this.strutStyle,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        final double dx = (-0.666 * bounds.width) * (1 - progress);
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [overlayStyle.color!, overlayStyle.color!, underStyle.color!],
          stops: [0.0, 0.333, 0.666],
          transform: _ScaledTranslateGradientTransform(dx: dx, scale: scale),
        ).createShader(bounds);
      },
      blendMode: BlendMode.srcIn,
      child: Text(text, style: underStyle, strutStyle: strutStyle),
    );
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

class _LrcLyricWidget extends StatelessWidget {
  final String text;
  final TextStyle overlayStyle;

  const _LrcLyricWidget({required this.text, required this.overlayStyle});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: overlayStyle, softWrap: true);
  }
}

class _KaraOkLyricWidget extends StatefulWidget {
  final List<WordEntry> text;
  final TextStyle underStyle;
  final TextStyle overlayStyle;
  final StrutStyle strutStyle;
  final DesktopLyricsController ctrl;

  const _KaraOkLyricWidget({
    required this.text,
    required this.underStyle,
    required this.overlayStyle,
    required this.strutStyle,
    required this.ctrl,
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
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Obx(() {
        final currWordIndex = widget.ctrl.currentWordIndex.value;
        // 确保布局已完成
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToIndex(currWordIndex);
        });

        // 构造每个字的 Widget
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
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
                  progress: widget.ctrl.wordProgress.value / 100.0,
                  underStyle: widget.underStyle,
                  overlayStyle: widget.overlayStyle,
                  strutStyle: widget.strutStyle,
                  scale: scale,
                ),
              );
            } else if (wordIndex < currWordIndex) {
              child = Text(
                word,
                style: widget.overlayStyle.copyWith(
                  color: widget.overlayStyle.color,
                ),
                strutStyle: widget.strutStyle,
              );
            } else {
              child = Text(
                word,
                style: widget.underStyle,
                strutStyle: widget.strutStyle,
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
  final StrutStyle strutStyle;

  const _TranslateWidget({
    required this.text,
    required this.ctrl,
    required this.underStyle,
    required this.strutStyle,
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
      alignment: 0.4,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Obx(() {
        final currWordIndex = widget.ctrl.currentWordIndex.value;
        // 确保布局已完成
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToIndex(currWordIndex);
        });

        // 构造每个字的 Widget
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: widget.text.asMap().entries.map((entry) {
            final wordIndex = entry.key;
            final word = entry.value;

            Widget child = Text(
              word,
              style: widget.underStyle,
              strutStyle: widget.strutStyle,
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

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final fontSize = _desktopLyricsController.fontSize.value;
      final fontWeight = _desktopLyricsController.fontWeight.value;

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

        if (currentLine == null) {
          return const SizedBox.shrink();
        }
        final currentTranslate =
            _desktopLyricsController.currentTranslate.value;

        return Opacity(
          opacity: _desktopLyricsController.fontOpacity.value,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (lrcType == LyricFormat.lrc)
                _LrcLyricWidget(
                  text: currentLine as String,
                  overlayStyle: overlayStyle,
                )
              else
                _KaraOkLyricWidget(
                  text: currentLine as List<WordEntry>,
                  underStyle: underStyle,
                  overlayStyle: overlayStyle,
                  strutStyle: strutStyle,
                  ctrl: _desktopLyricsController,
                ),
              if (currentTranslate.isNotEmpty)
                _TranslateWidget(
                  text: currentTranslate.split(''),
                  underStyle: underStyle,
                  strutStyle: strutStyle,
                  ctrl: _desktopLyricsController,
                ),
              // Text(currentTranslate, style: underStyle, softWrap: true,strutStyle: strutStyle,),
            ],
          ),
        );
      });
    });
  }
}
