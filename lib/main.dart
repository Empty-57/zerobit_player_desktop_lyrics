import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zerobit_player_desktop_lyrics/tool_bar.dart';

import 'desktop_lyrics_client.dart';
import 'desktop_lyrics_next_widget.dart';
import 'desktop_lyrics_widget.dart';
import 'getx_ctrl/desktop_lyrics_ctrl.dart';

final _isHover = false.obs;
const _lrcCrossAlignment = [
  CrossAxisAlignment.start,
  CrossAxisAlignment.center,
  CrossAxisAlignment.end,
  CrossAxisAlignment.start,
];
void main() async {
  if (!await FlutterSingleInstance().isFirstInstance()) {
    await FlutterSingleInstance().focus();
    exit(0);
  }

  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  Get.put(DesktopLyricsController());
  Get.put(DesktopLyricsClient());

  final DesktopLyricsClient lyricsClient = Get.find<DesktopLyricsClient>();
  final DesktopLyricsController desktopLyricsController =
      Get.find<DesktopLyricsController>();

  WindowOptions windowOptions = WindowOptions(
    size: Size(
      desktopLyricsController.useVerticalDisplayMode.value
          ? DesktopLyricsController.windowHeightMax.toDouble() +
                DesktopLyricsController.toolBarHeight
          : DesktopLyricsController.windowWidthMax.toDouble(),
      desktopLyricsController.useVerticalDisplayMode.value
          ? DesktopLyricsController.windowWidthMax.toDouble()
          : DesktopLyricsController.windowHeightMax.toDouble() +
                DesktopLyricsController.toolBarHeight,
    ),
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    alwaysOnTop: true,
    title: 'ZeroBit Player Lyrics',
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    lyricsClient.connect();
    await windowManager.setAsFrameless();
    await windowManager.setResizable(true);
    await windowManager.setAlwaysOnTop(true);
    // await desktopLyricsController.calcSize();
    await windowManager.show();
  });
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  final double _resizeAreaSize = 10.0;

  @override
  Widget build(BuildContext context) {
    final DesktopLyricsController desktopLyricsController =
        Get.find<DesktopLyricsController>();
    final DesktopLyricsClient lyricsClient = Get.find<DesktopLyricsClient>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      home: LayoutBuilder(
        builder: (_, constraints) => GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (details) =>
              desktopLyricsController.isIgnoreMouseEvents.value
              ? null
              : windowManager.startDragging(),
          child: MouseRegion(
            onEnter: (_) => _isHover.value = true,
            onExit: (_) => _isHover.value = false,
            child: Stack(
              children: [
                Obx(() {
                  final counter = lyricsClient.lyricsCounter.value;
                  final isEven = counter.isEven;
                  final lrcAlignment =
                      desktopLyricsController.lrcAlignment.value;
                  final useVertical =
                      desktopLyricsController.useVerticalDisplayMode.value;
                  final showDoubleLine =
                      desktopLyricsController.showDoubleLine.value;
                  final isIgnoreMouse =
                      desktopLyricsController.isIgnoreMouseEvents.value;
                  final animateMode =
                      desktopLyricsController.lyricsSwitchAnimateMode.value;

                  // 槽位1 在 counter 为 1, 3, 5 时触发动画
                  final currSlotVersion = (counter + 1) ~/ 2;
                  // 槽位2 在 counter 为 0, 2, 4 时触发动画
                  final nextSlotVersion = counter ~/ 2;

                  Alignment getStackAlignment(bool isNextSlot) {
                    if (lrcAlignment == 3) {
                      if (isNextSlot) {
                        return useVertical
                            ? Alignment.bottomCenter
                            : Alignment.centerRight;
                      }
                      return useVertical
                          ? Alignment.topCenter
                          : Alignment.centerLeft;
                    }
                    if (useVertical) {
                      if (lrcAlignment == 0) return Alignment.topCenter;
                      if (lrcAlignment == 2) return Alignment.bottomCenter;
                      return Alignment.center;
                    } else {
                      if (lrcAlignment == 0) return Alignment.centerLeft;
                      if (lrcAlignment == 2) return Alignment.centerRight;
                      return Alignment.center;
                    }
                  }

                  Widget getAnimatedChild(
                    Animation<double> animation,
                    Widget child,
                  ) {
                    if (animateMode == 2) {
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: useVertical
                              ? const Offset(0.1, 0)
                              : const Offset(0, -0.1),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      );
                    }
                    if (animateMode == 3) {
                      return ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.8,
                          end: 1.0,
                        ).animate(animation),
                        child: child,
                      );
                    }
                    return child;
                  }

                  Widget buildAnimatedLyric(
                    Widget child,
                    Key animationKey,
                    bool isNextSlot,
                  ) {
                    if (animateMode == 0) {
                      return child;
                    }

                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      switchInCurve: Curves.easeOutCubic,
                      layoutBuilder:
                          (
                            Widget? currentChild,
                            List<Widget> previousChildren,
                          ) {
                            return Stack(
                              alignment: getStackAlignment(isNextSlot),
                              children: <Widget>[
                                // 抛弃 previousChildren，避免旧文本瞬间的字形闪烁
                                if (currentChild != null) currentChild,
                              ],
                            );
                          },
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: Tween<double>(
                                begin: 0.4,
                                end: 1.0,
                              ).animate(animation),
                              child: getAnimatedChild(animation, child),
                            );
                          },
                      // 用key触发动画
                      child: KeyedSubtree(key: animationKey, child: child),
                    );
                  }

                  Widget currLyrics;
                  Widget nextLyrics;

                  if (!showDoubleLine) {
                    currLyrics = Expanded(
                      child: buildAnimatedLyric(
                        const LyricsRender(),
                        ValueKey('single_$counter'),
                        false,
                      ),
                    );
                    nextLyrics = const SizedBox.shrink();
                  } else {
                    currLyrics = Expanded(
                      child: buildAnimatedLyric(
                        isEven
                            ? const LyricsRender()
                            : const LyricsNextRender(),
                        // 只有奇数次才触发动画
                        ValueKey('curr_$currSlotVersion'),
                        false,
                      ),
                    );

                    Widget nextContent = isEven
                        ? const LyricsNextRender()
                        : const LyricsRender();

                    if (lrcAlignment == 3) {
                      nextLyrics = Expanded(
                        child: Align(
                          alignment: useVertical
                              ? Alignment.bottomCenter
                              : Alignment.centerRight,
                          child: buildAnimatedLyric(
                            nextContent,
                            // 只有偶数次才触发动画
                            ValueKey('next_$nextSlotVersion'),
                            true,
                          ),
                        ),
                      );
                    } else {
                      nextLyrics = Expanded(
                        child: buildAnimatedLyric(
                          nextContent,
                          ValueKey('next_$nextSlotVersion'),
                          true,
                        ),
                      );
                    }
                  }

                  return Container(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    color: _isHover.value && !isIgnoreMouse
                        ? Colors.black.withValues(alpha: 0.4)
                        : Colors.transparent,
                    child: Flex(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment:
                          _lrcCrossAlignment[lrcAlignment == 3
                              ? 0
                              : lrcAlignment],
                      direction: useVertical ? Axis.horizontal : Axis.vertical,
                      children: [
                        ToolBar(isHover: _isHover),
                        currLyrics,
                        nextLyrics,
                      ],
                    ),
                  );
                }),

                // 左侧调整大小热区
                Positioned(
                  left: 0,
                  top: _resizeAreaSize, // 避开顶部标题栏
                  bottom: _resizeAreaSize,
                  width: _resizeAreaSize,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanStart: (_) {
                        windowManager.startResizing(ResizeEdge.left);
                      },
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ),

                // 右侧调整大小热区
                Positioned(
                  right: 0,
                  top: _resizeAreaSize,
                  bottom: _resizeAreaSize,
                  width: _resizeAreaSize,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanStart: (_) {
                        windowManager.startResizing(ResizeEdge.right);
                      },
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ),

                // 顶部调整大小热区（标题栏下方）
                Positioned(
                  top: 0,
                  left: _resizeAreaSize,
                  right: _resizeAreaSize,
                  height: _resizeAreaSize,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeUpDown,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanStart: (_) {
                        windowManager.startResizing(ResizeEdge.top);
                      },
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ),

                // 底部调整大小热区
                Positioned(
                  bottom: 0,
                  left: _resizeAreaSize,
                  right: _resizeAreaSize,
                  height: _resizeAreaSize,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeUpDown,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanStart: (_) {
                        windowManager.startResizing(ResizeEdge.bottom);
                      },
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ),

                // 左上角调整大小热区
                Positioned(
                  left: 0,
                  top: 0,
                  width: _resizeAreaSize,
                  height: _resizeAreaSize,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeUpLeftDownRight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanStart: (_) {
                        windowManager.startResizing(ResizeEdge.topLeft);
                      },
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ),

                // 右上角调整大小热区
                Positioned(
                  right: 0,
                  top: 0,
                  width: _resizeAreaSize,
                  height: _resizeAreaSize,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeUpRightDownLeft,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanStart: (_) {
                        windowManager.startResizing(ResizeEdge.topRight);
                      },
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ),

                // 左下角调整大小热区
                Positioned(
                  left: 0,
                  bottom: 0,
                  width: _resizeAreaSize,
                  height: _resizeAreaSize,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeUpRightDownLeft,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanStart: (_) {
                        windowManager.startResizing(ResizeEdge.bottomLeft);
                      },
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ),

                // 右下角调整大小热区
                Positioned(
                  right: 0,
                  bottom: 0,
                  width: _resizeAreaSize,
                  height: _resizeAreaSize,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeUpLeftDownRight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanStart: (_) {
                        windowManager.startResizing(ResizeEdge.bottomRight);
                      },
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
