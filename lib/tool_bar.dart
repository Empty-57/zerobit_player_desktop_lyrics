import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';

import 'controller/desktop_lyrics_ctrl.dart';
import 'controller/display_settings.dart';
import 'desktop_lyrics_client.dart';
import 'tools/lyric_text_style.dart';
import 'tools/throttle.dart';

final DesktopLyricsController _desktopLyricsController =
    GetIt.I<DesktopLyricsController>();
final DesktopLyricsClient _lyricsClient = GetIt.I<DesktopLyricsClient>();

// 节流闭包只创建一次
final _previousTrack = throttle(
  () => _lyricsClient.sendCmd(cmdType: ClientCmdType.previous),
);
final _nextTrack = throttle(
  () => _lyricsClient.sendCmd(cmdType: ClientCmdType.next),
);
final _togglePlayback = throttle(
  () => _lyricsClient.sendCmd(cmdType: ClientCmdType.toggle),
  duration: const Duration(milliseconds: 300),
);

void _addFontSize() {
  _desktopLyricsController.addFontSize();
  _lyricsClient.sendCmd(cmdType: ClientCmdType.addFontSize);
}

void _decFontSize() {
  _desktopLyricsController.decFontSize();
  _lyricsClient.sendCmd(cmdType: ClientCmdType.decFontSize);
}

void _switchLock() {
  final locked = !_desktopLyricsController.isIgnoreMouseEvents.value;
  _desktopLyricsController.isIgnoreMouseEvents.value = locked;
  _lyricsClient.sendCmd(cmdType: ClientCmdType.switchLock, cmdData: locked);
}

class _ControllerButton extends StatelessWidget {
  const _ControllerButton({required this.icon, required this.fn, this.tooltip});

  final IconData icon;
  final VoidCallback fn;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    // 枚举实例上的字段访问不是常量表达式，这里只能是 final
    final size = IconSize.md.px;
    return IconButton(
      icon: Icon(icon),
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
      tooltip: tooltip,
      iconSize: size,
      style: ButtonStyle(
        padding: WidgetStateProperty.all<EdgeInsetsGeometry>(
          const EdgeInsets.all(4),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: WidgetStateProperty.all<Size>(Size(size, size)),
        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      onPressed: fn,
    );
  }
}

/// 悬停时浮现的播放控制条。锁定鼠标穿透后即使悬停也不显示。
class ToolBar extends StatelessWidget {
  const ToolBar({super.key, required this.isHover});

  final ReadonlySignal<bool> isHover;

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final ctrl = _desktopLyricsController;
        final isVertical = ctrl.useVerticalDisplayMode.value;
        final isIgnoreMouse = ctrl.isIgnoreMouseEvents.value;
        final isPlaying = ctrl.currentState.value == AudioState.playing;

        final size = MediaQuery.sizeOf(context);

        return SizedBox(
          height: isVertical
              ? size.height
              : DesktopLyricsController.toolBarHeight,
          width: isVertical
              ? DesktopLyricsController.toolBarHeight
              : size.width,
          child: Visibility(
            visible: isHover.value && !isIgnoreMouse,
            child: Flex(
              direction: isVertical ? Axis.vertical : Axis.horizontal,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 6,
              children: [
                _ControllerButton(
                  icon: PhosphorIconsLight.plus,
                  tooltip: '字号+',
                  fn: _addFontSize,
                ),
                _ControllerButton(
                  icon: PhosphorIconsLight.minus,
                  tooltip: '字号-',
                  fn: _decFontSize,
                ),
                _ControllerButton(
                  icon: PhosphorIconsFill.skipBack,
                  tooltip: '上一首',
                  fn: _previousTrack,
                ),
                _ControllerButton(
                  icon: isPlaying
                      ? PhosphorIconsFill.pause
                      : PhosphorIconsFill.play,
                  tooltip: isPlaying ? '暂停' : '播放',
                  fn: _togglePlayback,
                ),
                _ControllerButton(
                  icon: PhosphorIconsFill.skipForward,
                  tooltip: '下一首',
                  fn: _nextTrack,
                ),
                _ControllerButton(
                  icon: PhosphorIconsLight.x,
                  tooltip: '关闭',
                  fn: () => unawaited(_lyricsClient.close()),
                ),
                _ControllerButton(
                  icon: isIgnoreMouse
                      ? PhosphorIconsFill.lock
                      : PhosphorIconsFill.lockOpen,
                  tooltip: '锁定',
                  fn: _switchLock,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
