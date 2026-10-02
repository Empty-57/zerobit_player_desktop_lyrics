import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:get_it/get_it.dart';
import 'package:signals/signals_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'controller/desktop_lyrics_ctrl.dart';
import 'controller/display_settings.dart';
import 'desktop_lyrics_client.dart';
import 'desktop_lyrics_next_widget.dart';
import 'desktop_lyrics_widget.dart';
import 'tool_bar.dart';

final _isHover = signal(false);

/// 窗口边缘可拖拽缩放的热区厚度
const _resizeAreaSize = 10.0;

const _horizontalWindowSize = Size(
  DesktopLyricsController.windowWidthMax,
  DesktopLyricsController.windowHeightMax +
      DesktopLyricsController.toolBarHeight,
);

const _verticalWindowSize = Size(
  DesktopLyricsController.windowHeightMax +
      DesktopLyricsController.toolBarHeight,
  DesktopLyricsController.windowWidthMax,
);

Future<void> main() async {
  if (!await FlutterSingleInstance().isFirstInstance()) {
    await FlutterSingleInstance().focus();
    exit(0);
  }

  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  GetIt.I.registerSingleton<DesktopLyricsController>(
    DesktopLyricsController(),
    dispose: (controller) => controller.dispose(),
  );
  GetIt.I.registerSingleton<DesktopLyricsClient>(DesktopLyricsClient());

  final windowOptions = WindowOptions(
    size: GetIt.I<DesktopLyricsController>().useVerticalDisplayMode.value
        ? _verticalWindowSize
        : _horizontalWindowSize,
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    alwaysOnTop: true,
    title: 'ZeroBit Player Lyrics',
  );

  unawaited(
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      unawaited(GetIt.I<DesktopLyricsClient>().connect());
      await windowManager.setAsFrameless();
      await windowManager.setResizable(true);
      await windowManager.setAlwaysOnTop(true);
      await windowManager.show();
    }),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        scrollbars: false,
      ),
      home: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) {
          if (GetIt.I<DesktopLyricsController>().isIgnoreMouseEvents.value) {
            return;
          }
          windowManager.startDragging();
        },
        child: MouseRegion(
          onEnter: (_) => _isHover.value = true,
          onExit: (_) => _isHover.value = false,
          child: Stack(
            children: [
              const Positioned.fill(child: _HoverBackground()),
              const Positioned.fill(child: _LyricsLayer()),
              ..._resizeHandleWidgets,
            ],
          ),
        ),
      ),
    );
  }
}

/// 悬停时的半透明底色
class _HoverBackground extends StatelessWidget {
  const _HoverBackground();

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final dimmed =
            _isHover.value &&
            !GetIt.I<DesktopLyricsController>().isIgnoreMouseEvents.value;
        return ColoredBox(
          color: dimmed
              ? Colors.black.withValues(alpha: 0.4)
              : Colors.transparent,
        );
      },
    );
  }
}

/// 工具栏 + 歌词。
class _LyricsLayer extends StatelessWidget {
  const _LyricsLayer();

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final ctrl = GetIt.I<DesktopLyricsController>();
        final counter = GetIt.I<DesktopLyricsClient>().lyricsCounter.value;
        final alignment = ctrl.lrcAlignment.value;
        final animation = ctrl.lyricsSwitchAnimateMode.value;
        final vertical = ctrl.useVerticalDisplayMode.value;

        final Widget currSlot;
        Widget nextSlot;

        if (!ctrl.showDoubleLine.value) {
          currSlot = _AnimatedLyricSlot(
            version: 'single_$counter',
            isNextSlot: false,
            alignment: alignment,
            animation: animation,
            vertical: vertical,
            child: const LyricsRender(),
          );
          nextSlot = const SizedBox.shrink();
        } else {
          // 两个渲染器在两个槽位间轮换：counter 为偶数时当前行在前一个槽位，
          // 奇数时换到后一个。槽位的版本号只在轮到自己时递增，
          currSlot = _AnimatedLyricSlot(
            version: 'curr_${(counter + 1) ~/ 2}',
            isNextSlot: false,
            alignment: alignment,
            animation: animation,
            vertical: vertical,
            child: counter.isEven
                ? const LyricsRender()
                : const LyricsNextRender(),
          );
          nextSlot = _AnimatedLyricSlot(
            version: 'next_${counter ~/ 2}',
            isNextSlot: true,
            alignment: alignment,
            animation: animation,
            vertical: vertical,
            child: counter.isEven
                ? const LyricsNextRender()
                : const LyricsRender(),
          );
          if (alignment == LyricAlignment.alternate) {
            // 交替对齐下容器取 start（见 containerAlignment），
            // 下一行得自己贴到对面那一端去
            nextSlot = Align(
              alignment: vertical
                  ? Alignment.bottomCenter
                  : Alignment.centerRight,
              child: nextSlot,
            );
          }
          nextSlot = Expanded(child: nextSlot);
        }

        return Flex(
          direction: vertical ? Axis.horizontal : Axis.vertical,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: alignment.containerAlignment,
          children: [
            ToolBar(isHover: _isHover),
            Expanded(child: currSlot),
            nextSlot,
          ],
        );
      },
    );
  }
}

/// 一个歌词槽位。[version] 变化即播放一次切换动画。
class _AnimatedLyricSlot extends StatelessWidget {
  const _AnimatedLyricSlot({
    required this.child,
    required this.version,
    required this.isNextSlot,
    required this.alignment,
    required this.animation,
    required this.vertical,
  });

  final Widget child;
  final String version;
  final bool isNextSlot;

  final LyricAlignment alignment;
  final LyricSwitchAnimation animation;
  final bool vertical;

  /// 动画期间新旧文本叠放的位置：与歌词自身的对齐方向一致，
  /// 否则滑动 / 缩放会从错误的一侧进入。
  Alignment get _stackAlignment => switch (alignment) {
    LyricAlignment.alternate when isNextSlot =>
      vertical ? Alignment.bottomCenter : Alignment.centerRight,
    LyricAlignment.alternate || LyricAlignment.start =>
      vertical ? Alignment.topCenter : Alignment.centerLeft,
    LyricAlignment.end =>
      vertical ? Alignment.bottomCenter : Alignment.centerRight,
    LyricAlignment.center => Alignment.center,
  };

  Widget _applyMotion(Animation<double> value, Widget child) =>
      switch (animation) {
        LyricSwitchAnimation.slide => SlideTransition(
          position: Tween<Offset>(
            begin: vertical ? const Offset(0.1, 0) : const Offset(0, -0.1),
            end: Offset.zero,
          ).animate(value),
          child: child,
        ),
        LyricSwitchAnimation.scale => ScaleTransition(
          filterQuality: .low,
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(value),
          child: child,
        ),
        // 淡入淡出由下面那层 FadeTransition 统一负责
        LyricSwitchAnimation.none || LyricSwitchAnimation.fade => child,
      };

  @override
  Widget build(BuildContext context) {
    if (animation == LyricSwitchAnimation.none) return child;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOutCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: _stackAlignment,
        // 抛弃 previousChildren，避免旧文本瞬间的字形闪烁
        children: [if (currentChild != null) currentChild],
      ),
      transitionBuilder: (child, value) => FadeTransition(
        opacity: Tween<double>(begin: 0.4, end: 1.0).animate(value),
        child: _applyMotion(value, child),
      ),
      // 用 key 触发动画
      child: KeyedSubtree(key: ValueKey(version), child: child),
    );
  }
}

/// 一个缩放热区的位置描述。某个方向为 null 表示不在该方向定位。
class _ResizeHandleSpec {
  const _ResizeHandleSpec({
    required this.edge,
    required this.cursor,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.width,
    this.height,
  });

  final ResizeEdge edge;
  final MouseCursor cursor;
  final double? left;
  final double? top;
  final double? right;
  final double? bottom;
  final double? width;
  final double? height;
}

/// 四条边 + 四个角。四条边各让出角上的 [_resizeAreaSize]，
/// 保证角落触发的是斜向缩放。
const _resizeHandles = <_ResizeHandleSpec>[
  _ResizeHandleSpec(
    edge: ResizeEdge.left,
    cursor: SystemMouseCursors.resizeLeftRight,
    left: 0,
    top: _resizeAreaSize,
    bottom: _resizeAreaSize,
    width: _resizeAreaSize,
  ),
  _ResizeHandleSpec(
    edge: ResizeEdge.right,
    cursor: SystemMouseCursors.resizeLeftRight,
    right: 0,
    top: _resizeAreaSize,
    bottom: _resizeAreaSize,
    width: _resizeAreaSize,
  ),
  _ResizeHandleSpec(
    edge: ResizeEdge.top,
    cursor: SystemMouseCursors.resizeUpDown,
    top: 0,
    left: _resizeAreaSize,
    right: _resizeAreaSize,
    height: _resizeAreaSize,
  ),
  _ResizeHandleSpec(
    edge: ResizeEdge.bottom,
    cursor: SystemMouseCursors.resizeUpDown,
    bottom: 0,
    left: _resizeAreaSize,
    right: _resizeAreaSize,
    height: _resizeAreaSize,
  ),
  _ResizeHandleSpec(
    edge: ResizeEdge.topLeft,
    cursor: SystemMouseCursors.resizeUpLeftDownRight,
    top: 0,
    left: 0,
    width: _resizeAreaSize,
    height: _resizeAreaSize,
  ),
  _ResizeHandleSpec(
    edge: ResizeEdge.topRight,
    cursor: SystemMouseCursors.resizeUpRightDownLeft,
    top: 0,
    right: 0,
    width: _resizeAreaSize,
    height: _resizeAreaSize,
  ),
  _ResizeHandleSpec(
    edge: ResizeEdge.bottomLeft,
    cursor: SystemMouseCursors.resizeUpRightDownLeft,
    bottom: 0,
    left: 0,
    width: _resizeAreaSize,
    height: _resizeAreaSize,
  ),
  _ResizeHandleSpec(
    edge: ResizeEdge.bottomRight,
    cursor: SystemMouseCursors.resizeUpLeftDownRight,
    bottom: 0,
    right: 0,
    width: _resizeAreaSize,
    height: _resizeAreaSize,
  ),
];

/// 热区不随状态变化，构建一次即可。
final _resizeHandleWidgets = <Widget>[
  for (final spec in _resizeHandles) _ResizeHandle(spec),
];

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle(this.spec);

  final _ResizeHandleSpec spec;

  @override
  Widget build(BuildContext context) => Positioned(
    left: spec.left,
    top: spec.top,
    right: spec.right,
    bottom: spec.bottom,
    width: spec.width,
    height: spec.height,
    child: MouseRegion(
      cursor: spec.cursor,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => windowManager.startResizing(spec.edge),
        // 把热区撑满的空盒子
        child: const SizedBox.expand(),
      ),
    ),
  );
}
