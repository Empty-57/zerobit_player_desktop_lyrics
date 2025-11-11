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
    await windowManager.setResizable(false);
    await windowManager.setAlwaysOnTop(true);
    await desktopLyricsController.calcSize();
    await windowManager.show();
  });
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
            child: Obx(
              () => Container(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                color: _isHover.value && !desktopLyricsController.isLock.value
                    ? Colors.black.withValues(alpha: 0.2)
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
          ),
        ),
      ),
    );
  }
}
