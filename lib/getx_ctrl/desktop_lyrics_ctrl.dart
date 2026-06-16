import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zerobit_player_desktop_lyrics/tools/lrcTool/lyric_model.dart';

import '../desktop_lyrics_client.dart';

enum AudioState { stop, playing, pause }

class DesktopLyricsController extends GetxController with WindowListener {
  final currentState = AudioState.stop.index.obs;

  final fontFamily = "Microsoft YaHei Light".obs;
  final fontSize = 24.obs; // 16-36
  final fontWeight = 5.obs; // 0-8  w100-w900
  final overlayColor = 0xffff0000.obs;
  final underColor = 0xff0000ff.obs;
  final fontOpacity = 1.0.obs;

  final isLock = false.obs;

  final currentWordIndex = 0.obs;
  final ValueNotifier<double> wordProgress = ValueNotifier<double>(0.0);
  final lrcType = LyricFormat.lrc.obs;
  final currentLine = Rx<dynamic>('ZeroBit Player');
  final currentTranslate = ''.obs;
  final nextLine = Rx<dynamic>('ZeroBit Player');
  final nextTranslate = ''.obs;

  final lrcAlignment = 1.obs;

  final useVerticalDisplayMode = false.obs;

  final useStroke = true.obs;

  final strokeColor = 0xff000000.obs;

  final showDoubleLine = false.obs;

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

  DesktopLyricsClient get _lyricsClient => Get.find<DesktopLyricsClient>();

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

  void addFontSize() async {
    fontSize.value++;
    fontSize.value = fontSize.value.clamp(fontSizeMin, fontSizeMax);
  }

  void decFontSize() async {
    fontSize.value--;
    fontSize.value = fontSize.value.clamp(fontSizeMin, fontSizeMax);
  }

  void setFontSize({required int size}) {
    fontSize.value = size.clamp(fontSizeMin, fontSizeMax);
  }

  void setUseVerticalDisplayMode({required use}) {
    useVerticalDisplayMode.value = use;
    calcSize();
  }

  @override
  void onInit() async {
    windowManager.addListener(this);
    super.onInit();
  }

  @override
  void onClose() {
    windowManager.removeListener(this);
    wordProgress.dispose();
    super.onClose();
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
