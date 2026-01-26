import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:window_manager/window_manager.dart';
import 'package:get/get.dart';
import 'package:zerobit_player_desktop_lyrics/tool_bar.dart';
import 'desktop_lyrics_client.dart';
import 'desktop_lyrics_widget.dart';
import 'getx_ctrl/desktop_lyrics_ctrl.dart';

final _isHover = false.obs;

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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      home: LayoutBuilder(
        builder: (_, constraints) => GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (details) => desktopLyricsController.isLock.value
              ? null
              : windowManager.startDragging(),
          child: MouseRegion(
            onEnter: (_) => _isHover.value = true,
            onExit: (_) => _isHover.value = false,
            child: Stack(
              children: [
                Obx(
              () => Container(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                color: _isHover.value && !desktopLyricsController.isLock.value
                    ? Colors.black.withValues(alpha: 0.4)
                    : Colors.transparent,
                child: Flex(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  direction:
                      desktopLyricsController.useVerticalDisplayMode.value
                      ? Axis.horizontal
                      : Axis.vertical,
                  children: [
                    ToolBar(isHover: _isHover),
                    Expanded(child: const LyricsRender()),
                  ],
                ),
              ),
            ),

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
