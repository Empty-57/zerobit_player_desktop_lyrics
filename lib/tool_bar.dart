import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:zerobit_player_desktop_lyrics/tools/general_style.dart';

import 'desktop_lyrics_client.dart';
import 'getx_ctrl/desktop_lyrics_ctrl.dart';

final DesktopLyricsController _desktopLyricsController =
    Get.find<DesktopLyricsController>();
final DesktopLyricsClient _lyricsClient = Get.find<DesktopLyricsClient>();

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
        // visualDensity: VisualDensity.compact,
        padding: WidgetStateProperty.all<EdgeInsetsGeometry>(EdgeInsets.all(4)),
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
  final RxBool isHover;
  const ToolBar({super.key, required this.isHover});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width: context.width,
      color: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 6,
        children: [
          Obx(
            () => Visibility(
              visible: isHover.value && !_desktopLyricsController.isLock.value,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
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
                    },
                  ),
                  Obx(
                    () => _ControllerButton(
                      icon:
                          _desktopLyricsController.currentState.value ==
                              AudioState.playing.index
                          ? PhosphorIconsFill.pause
                          : PhosphorIconsFill.play,
                      tooltip:
                          _desktopLyricsController.currentState.value ==
                              AudioState.playing.index
                          ? '暂停'
                          : '播放',
                      fn: () async {
                        _lyricsClient.sendCmd(cmdType: ClientCmdType.toggle);
                      },
                    ),
                  ),
                  _ControllerButton(
                    icon: PhosphorIconsFill.skipForward,
                    tooltip: '下一首',
                    fn: () async {
                      _lyricsClient.sendCmd(cmdType: ClientCmdType.next);
                    },
                  ),
                  _ControllerButton(
                    icon: PhosphorIconsLight.x,
                    tooltip: '关闭',
                    fn: () {
                      _lyricsClient.close();
                    },
                  ),
                ],
              ),
            ),
          ),
          Obx(
            () => Visibility(
              visible: isHover.value,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: _ControllerButton(
                icon: _desktopLyricsController.isLock.value
                    ? PhosphorIconsLight.lock
                    : PhosphorIconsLight.lockOpen,
                tooltip: _desktopLyricsController.isLock.value ? '解锁' : '锁定',
                fn: () async {
                  _desktopLyricsController.isLock.value =
                      !_desktopLyricsController.isLock.value;
                  _lyricsClient.sendCmd(cmdType: ClientCmdType.switchLock,cmdData: _desktopLyricsController.isLock.value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
