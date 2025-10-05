import 'dart:ui';

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
  final wordProgress = 0.0.obs;
  final lrcType = LyricFormat.lrc.obs;
  final currentLine = Rx<dynamic>('ZeroBit Player');
  final currentTranslate = ''.obs;

  static const double widthIncrement = 12;
  static const double heightIncrement = 2.5;
  static const int fontSizeMin = 16;
  static const int fontSizeMax = 36;
  static const int windowWidthMin = 400;
  static const int windowHeightMin = 100;

  static const double windowWidthMax =
      (fontSizeMax - fontSizeMin) * widthIncrement + windowWidthMin;
  static const double windowHeightMax =
      (fontSizeMax - fontSizeMin) * heightIncrement + windowHeightMin;


  DesktopLyricsClient get _lyricsClient =>Get.find<DesktopLyricsClient>();

  Future<(double, double)> calcSize([bool setSize = true]) async {
    final w = ((fontSize.value - fontSizeMin) * widthIncrement + windowWidthMin)
        .clamp(windowWidthMin, windowWidthMax)
        .toDouble();
    final h =
        (((fontSize.value - fontSizeMin) * heightIncrement + windowHeightMin)
                .clamp(windowHeightMin, windowHeightMax))
            .toDouble()+40;
    if (setSize) {
      await windowManager.setSize(Size(w, h));
    }

    return (w, h);
  }

  void addFontSize() async {
    fontSize.value++;
    fontSize.value = fontSize.value.clamp(fontSizeMin, fontSizeMax);
    calcSize();
  }

  void decFontSize() async {
    fontSize.value--;
    fontSize.value = fontSize.value.clamp(fontSizeMin, fontSizeMax);
    calcSize();
  }

  void setFontSize({required int size}) {
    fontSize.value = size.clamp(fontSizeMin, fontSizeMax);
    calcSize();
  }


  @override
  void onInit() async {
    await calcSize();
    windowManager.addListener(this);
    super.onInit();
  }

  @override
  void onClose() {
    windowManager.removeListener(this);
    super.onClose();
  }

  @override
  void onWindowClose() async {
    windowManager.removeListener(this);
  }

  @override
  void onWindowMoved() async {
    final position = await windowManager.getPosition();
    _lyricsClient.sendCmd(cmdType: ClientCmdType.setDx,cmdData: position.dx);
    _lyricsClient.sendCmd(cmdType: ClientCmdType.setDy,cmdData: position.dy);
  }
}
