import 'dart:async';
import 'dart:math';
import 'dart:ui' show Size;

import 'package:get_it/get_it.dart';
import 'package:signals/signals_flutter.dart';
import 'package:window_manager/window_manager.dart';

import '../desktop_lyrics_client.dart';
import '../tools/lrcTool/lyric_model.dart';
import 'display_settings.dart';

/// 歌词窗口的全部显示状态。服务端下发的配置最终都落到这里的信号上。
class DesktopLyricsController with WindowListener {
  DesktopLyricsController() {
    windowManager.addListener(this);
  }

  final currentState = signal(AudioState.stop);

  final fontFamily = signal('Microsoft YaHei Light');

  /// 字号，取值范围 [fontSizeMin] - [fontSizeMax]
  final fontSize = signal(24);

  /// 字重档位 0-8，对应 `FontWeight.w100` - `w900`
  final fontWeight = signal(5);

  final overlayColor = signal(0xffff0000);
  final underColor = signal(0xff0000ff);
  final fontOpacity = signal(1.0);

  final isIgnoreMouseEvents = signal(false);

  /// 当前唱到第几个字，-1 表示整行尚未开始
  final currentWordIndex = signal(-1);

  /// 当前字的演唱进度，0-1
  final wordProgress = signal(0.0);

  final currentLine = signal<LyricLine?>(
    const PlainLyricLine('ZeroBit Player'),
  );
  final currentTranslate = signal('');
  final nextLine = signal<LyricLine?>(const PlainLyricLine('ZeroBit Player'));
  final nextTranslate = signal('');

  final lrcAlignment = signal(LyricAlignment.center);

  final useVerticalDisplayMode = signal(false);
  final useStroke = signal(true);
  final strokeColor = signal(0xff000000);
  final showDoubleLine = signal(false);
  final lyricsSwitchAnimateMode = signal(LyricSwitchAnimation.fade);

  /// 是否显示振り仮名注音
  final showKana = signal(true);

  /// 字号每加一档，默认窗口相应变宽/变高的量
  static const double widthIncrement = 12;
  static const double heightIncrement = 2.5;

  static const int fontSizeMin = 16;
  static const int fontSizeMax = 48;

  static const double windowWidthMin = 450;
  static const double windowHeightMin = 150;
  static const double windowWidthMax =
      (fontSizeMax - fontSizeMin) * widthIncrement + windowWidthMin;
  static const double windowHeightMax =
      (fontSizeMax - fontSizeMin) * heightIncrement + windowHeightMin;

  static const double toolBarHeight = 40;

  /// 窗口几何变化上报服务端的去抖间隔。拖动/缩放过程中系统会逐帧回调，
  /// 不去抖会让 WebSocket 被位置消息淹没。
  static const _geometryReportDelay = Duration(milliseconds: 200);

  Timer? _movedReportTimer;
  Timer? _resizedReportTimer;

  DesktopLyricsClient get _lyricsClient => GetIt.I<DesktopLyricsClient>();

  /// 调整窗口尺寸。
  ///
  /// 同时给出 [w] 与 [h] 时，按当前排版方向把两者分配为长边与短边
  /// （竖排窗口窄而高，横排反之），因此传入顺序无关。
  ///
  /// **不传参时刻意把当前宽高对调** —— 即让窗口旋转 90°，
  /// 这正是切换横竖排时需要的效果。下方 `w ??= size.height` 并非笔误。
  Future<void> calcSize([double? w, double? h]) async {
    final size = await windowManager.getSize();

    if (w != null && h != null) {
      final long = max(w, h);
      final short = min(w, h);
      w = useVerticalDisplayMode.value ? short : long;
      h = useVerticalDisplayMode.value ? long : short;
    }

    // 见上方文档：这里的 height / width 是刻意对调的
    w ??= size.height;
    h ??= size.width;

    await windowManager.setMinimumSize(
      useVerticalDisplayMode.value
          ? const Size(windowHeightMin, windowWidthMin)
          : const Size(windowWidthMin, windowHeightMin),
    );
    await windowManager.setSize(Size(w, h));
  }

  void addFontSize() => setFontSize(size: fontSize.value + 1);

  void decFontSize() => setFontSize(size: fontSize.value - 1);

  void setFontSize({required int size}) =>
      fontSize.value = size.clamp(fontSizeMin, fontSizeMax);

  /// 切换横竖排。
  ///
  /// 值未变时直接返回：[calcSize] 不传参会对调窗口宽高，
  /// 重复下发同一模式会让窗口来回旋转。
  void setUseVerticalDisplayMode({required bool use}) {
    if (useVerticalDisplayMode.value == use) return;
    useVerticalDisplayMode.value = use;
    unawaited(calcSize());
  }

  void dispose() {
    _movedReportTimer?.cancel();
    _resizedReportTimer?.cancel();
    windowManager.removeListener(this);
  }

  @override
  void onWindowClose() {
    windowManager.removeListener(this);
  }

  @override
  void onWindowMoved() {
    _movedReportTimer?.cancel();
    _movedReportTimer = Timer(_geometryReportDelay, () async {
      final position = await windowManager.getPosition();
      _lyricsClient
        ..sendCmd(cmdType: ClientCmdType.setDx, cmdData: position.dx)
        ..sendCmd(cmdType: ClientCmdType.setDy, cmdData: position.dy);
    });
  }

  @override
  void onWindowResized() {
    _resizedReportTimer?.cancel();
    _resizedReportTimer = Timer(_geometryReportDelay, () async {
      final size = await windowManager.getSize();
      _lyricsClient
        ..sendCmd(cmdType: ClientCmdType.setWindowWidth, cmdData: size.width)
        ..sendCmd(cmdType: ClientCmdType.setWindowHeight, cmdData: size.height);
    });
  }
}
