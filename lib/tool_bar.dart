import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player_desktop_lyrics/controller/desktop_lyrics_ctrl.dart';
import 'package:zerobit_player_desktop_lyrics/tools/func_extension.dart';
import 'package:zerobit_player_desktop_lyrics/tools/general_style.dart';

import 'desktop_lyrics_client.dart';

final DesktopLyricsController _desktopLyricsController =
    GetIt.I<DesktopLyricsController>();
final DesktopLyricsClient _lyricsClient = GetIt.I<DesktopLyricsClient>();

class _ControllerButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback fn;
  final String? tooltip;

  const _ControllerButton({required this.icon, required this.fn, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final size = getIconSize(size: 'md');
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
      onPressed: () {
        fn();
      },
    );
  }
}

class ToolBar extends StatelessWidget {
  // 2. RxBool 替换为 Signal<bool> (或 ReadonlySignal<bool>)
  final Signal<bool> isHover;

  const ToolBar({super.key, required this.isHover});

  @override
  Widget build(BuildContext context) {
    // 3. 使用 SignalBuilder 包裹整个 Container，确保尺寸、显隐与图标状态全响应
    return SignalBuilder(
      builder: (context) {
        final isVertical =
            _desktopLyricsController.useVerticalDisplayMode.value;
        final isIgnoreMouse =
            _desktopLyricsController.isIgnoreMouseEvents.value;
        final state = _desktopLyricsController.currentState.value;

        final height = MediaQuery.of(context).size.height;
        final width = MediaQuery.of(context).size.width;

        return Container(
          height: isVertical ? height : DesktopLyricsController.toolBarHeight,
          width: isVertical ? DesktopLyricsController.toolBarHeight : width,
          color: Colors.transparent,
          child: Visibility(
            visible: isHover.value && !isIgnoreMouse,
            child: Flex(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              direction: isVertical ? Axis.vertical : Axis.horizontal,
              spacing: 6,
              children: [
                _ControllerButton(
                  icon: PhosphorIconsLight.plus,
                  tooltip: '字号+',
                  fn: () {
                    _desktopLyricsController.addFontSize();
                    _lyricsClient.sendCmd(cmdType: ClientCmdType.addFontSize);
                  },
                ),
                _ControllerButton(
                  icon: PhosphorIconsLight.minus,
                  tooltip: '字号-',
                  fn: () {
                    _desktopLyricsController.decFontSize();
                    _lyricsClient.sendCmd(cmdType: ClientCmdType.decFontSize);
                  },
                ),
                _ControllerButton(
                  icon: PhosphorIconsFill.skipBack,
                  tooltip: '上一首',
                  fn: () async {
                    _lyricsClient.sendCmd(cmdType: ClientCmdType.previous);
                  }.throttle(ms: 500),
                ),
                _ControllerButton(
                  icon: state == AudioState.playing.index
                      ? PhosphorIconsFill.pause
                      : PhosphorIconsFill.play,
                  tooltip: state == AudioState.playing.index ? '暂停' : '播放',
                  fn: () async {
                    _lyricsClient.sendCmd(cmdType: ClientCmdType.toggle);
                  }.throttle(ms: 300),
                ),
                _ControllerButton(
                  icon: PhosphorIconsFill.skipForward,
                  tooltip: '下一首',
                  fn: () async {
                    _lyricsClient.sendCmd(cmdType: ClientCmdType.next);
                  }.throttle(ms: 500),
                ),
                _ControllerButton(
                  icon: PhosphorIconsLight.x,
                  tooltip: '关闭',
                  fn: () {
                    _lyricsClient.close();
                  },
                ),
                _ControllerButton(
                  icon: isIgnoreMouse
                      ? PhosphorIconsFill.lock
                      : PhosphorIconsFill.lockOpen,
                  tooltip: '锁定',
                  fn: () async {
                    // 4. 替换 GetX 的 toggle() 方法
                    final nextLockState =
                        !_desktopLyricsController.isIgnoreMouseEvents.value;
                    _desktopLyricsController.isIgnoreMouseEvents.value =
                        nextLockState;

                    _lyricsClient.sendCmd(
                      cmdType: ClientCmdType.switchLock,
                      cmdData: nextLockState,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
