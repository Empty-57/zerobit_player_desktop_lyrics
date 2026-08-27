import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:signals/signals_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zerobit_player_desktop_lyrics/tools/lrcTool/lyric_model.dart';

import '../desktop_lyrics_client.dart';

enum AudioState { stop, playing, pause }

class DesktopLyricsController with WindowListener {
  DesktopLyricsController() {
    windowManager.addListener(this);
  }

  final currentState = signal(AudioState.stop.index);

  final fontFamily = signal("Microsoft YaHei Light");
  final fontSize = signal(24); // 16-36
  final fontWeight = signal(5); // 0-8  w100-w900
  final overlayColor = signal(0xffff0000);
  final underColor = signal(0xff0000ff);
  final fontOpacity = signal(1.0);

  final isIgnoreMouseEvents = signal(false);

  final currentWordIndex = signal(0);

  final wordProgress = signal(0.0); // ValueNotifier

  final lrcType = signal(LyricFormat.lrc);
  final currentLine = signal<dynamic>('ZeroBit Player');
  final currentTranslate = signal('');
  final nextLine = signal<dynamic>('ZeroBit Player');
  final nextTranslate = signal('');

  final lrcAlignment = signal(1);

  final useVerticalDisplayMode = signal(false);

  final useStroke = signal(true);

  final strokeColor = signal(0xff000000);

  final showDoubleLine = signal(false);

  final lyricsSwitchAnimateMode = signal(1); // 0 无动画 1 淡入淡出 2滑动 3 缩放

  static const double widthIncrement = 12;
  static const double heightIncrement = 2.5;
  static const int fontSizeMin = 16;
  static const int fontSizeMax = 48;
  static const int windowWidthMin = 450;
  static const int windowHeightMin = 150;

  static const double windowWidthMax =
      (fontSizeMax - fontSizeMin) * widthIncrement + windowWidthMin;
  static const double windowHeightMax =
      (fontSizeMax - fontSizeMin) * heightIncrement + windowHeightMin;

  static const double toolBarHeight = 40;

  DesktopLyricsClient get _lyricsClient => GetIt.I<DesktopLyricsClient>();

  Future<void> calcSize([double? w, double? h]) async {
    final size = await windowManager.getSize();
    if (w != null && h != null) {
      double hh = h;
      double ww = w;
      if (useVerticalDisplayMode.value) {
        //判断窄边
        w = min(hh, ww);
        h = max(hh, ww);
      } else {
        w = max(hh, ww);
        h = min(hh, ww);
      }
    }

    w ??= size.height;
    h ??= size.width;
    if (useVerticalDisplayMode.value) {
      await windowManager.setMinimumSize(
        Size(windowHeightMin.toDouble(), windowWidthMin.toDouble()),
      );
    } else {
      await windowManager.setMinimumSize(
        Size(windowWidthMin.toDouble(), windowHeightMin.toDouble()),
      );
    }
    await windowManager.setSize(Size(w, h));
  }

  void addFontSize() {
    fontSize.value++;
    fontSize.value = fontSize.value.clamp(fontSizeMin, fontSizeMax);
  }

  void decFontSize() {
    fontSize.value--;
    fontSize.value = fontSize.value.clamp(fontSizeMin, fontSizeMax);
  }

  void setFontSize({required int size}) {
    fontSize.value = size.clamp(fontSizeMin, fontSizeMax);
  }

  void setUseVerticalDisplayMode({required bool use}) {
    useVerticalDisplayMode.value = use;
    calcSize();
  }

  void dispose() {
    windowManager.removeListener(this);
  }

  @override
  void onWindowClose() async {
    windowManager.removeListener(this);
  }

  @override
  void onWindowMoved() async {
    final position = await windowManager.getPosition();
    _lyricsClient.sendCmd(cmdType: ClientCmdType.setDx, cmdData: position.dx);
    _lyricsClient.sendCmd(cmdType: ClientCmdType.setDy, cmdData: position.dy);
  }

  @override
  void onWindowResized() async {
    final size = await windowManager.getSize();
    _lyricsClient.sendCmd(
      cmdType: ClientCmdType.setWindowWidth,
      cmdData: size.width,
    );
    _lyricsClient.sendCmd(
      cmdType: ClientCmdType.setWindowHeight,
      cmdData: size.height,
    );
  }
}
