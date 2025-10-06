import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:window_manager/window_manager.dart';
import 'package:zerobit_player_desktop_lyrics/tools/lrcTool/lyric_model.dart';

import 'getx_ctrl/desktop_lyrics_ctrl.dart';

final DesktopLyricsController _desktopLyricsController =
    Get.find<DesktopLyricsController>();

abstract class _SeverMessageType {
  static const data = 'data';
  static const position = 'position';
  static const cmd = 'cmd';
}

abstract class SeverCmdType {
  static const shutdown = 'shutdown';
  static const changeStatus = 'changeStatus';
  static const setFontSize = 'setFontSize';
  static const setFontWeight = 'setFontWeight';
  static const setFontFamily = 'setFontFamily';
  static const setOverlayColor = 'setOverlayColor';
  static const setUnderColor = 'setUnderColor';
  static const setFontOpacity = 'setFontOpacity';
  static const putConfig = 'putConfig';
  static const setIgnoreMouseEvents = 'setIgnoreMouseEvents';
}

abstract class ClientCmdType {
  static const toggle = 'toggle';
  static const next = 'next';
  static const previous = 'previous';
  static const close = 'close';
  static const addFontSize = 'addFontSize';
  static const decFontSize = 'decFontSize';
  static const switchLock = 'switchLock';
  static const setDx = 'setDx';
  static const setDy = 'setDy';
}

class DesktopLyricsClient {
  final _wsUrl = Uri.parse('ws://127.0.0.1:7070');
  IOWebSocketChannel? _channel;
  StreamSubscription? _listen;

  int reconnectCounter = 0;

  void connect() async {
    _channel = IOWebSocketChannel.connect(_wsUrl);

    try {
      await _channel!.ready;
    } catch (e) {
      debugPrint(e.toString());
      Timer(Duration(seconds: 2), () async {
        reconnectCounter++;
        if (reconnectCounter > 15) {
          debugPrint('Reconnect failed!');
          await windowManager.close();
          return;
        }
        debugPrint('reconnect on $reconnectCounter');
        connect();
      });
      return;
    }

    _add('ok');
    _listen = _channel!.stream.listen((message) async {
      _messageHandle(message);
    });
  }

  void _messageHandle(dynamic msg) {
    try {
      final data = jsonDecode(msg) as Map<String, dynamic>;
      final type = data['type'] as String;
      switch (type) {
        case _SeverMessageType.cmd:
          return _cmdHandle(data);
        case _SeverMessageType.position:
          return _positionHandle(data);
        case _SeverMessageType.data:
          return _dataHandle(data);
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _cmdHandle(Map<String, dynamic> data) async {
    final cmdType = data['cmdType'];
    final cmdData = data['cmdData'];
    switch (cmdType) {
      case SeverCmdType.shutdown:
        close(sendCmd_: false);
        return;
      case SeverCmdType.changeStatus:
        _desktopLyricsController.currentState.value = cmdData as int;
        return;
      case SeverCmdType.setFontSize:
        _desktopLyricsController.setFontSize(size: cmdData);
        return;
      case SeverCmdType.setFontWeight:
        _desktopLyricsController.fontWeight.value = cmdData.clamp(0, 8);
        return;
      case SeverCmdType.setFontFamily:
        _desktopLyricsController.fontFamily.value = cmdData;
        return;
      case SeverCmdType.setOverlayColor:
        _desktopLyricsController.overlayColor.value = cmdData;
        return;
      case SeverCmdType.setUnderColor:
        _desktopLyricsController.underColor.value = cmdData;
        return;
      case SeverCmdType.setFontOpacity:
        _desktopLyricsController.fontOpacity.value = cmdData.clamp(0.0, 1.0);
        return;
      case SeverCmdType.setIgnoreMouseEvents:
        await windowManager.setIgnoreMouseEvents(cmdData);
        return;
      case SeverCmdType.putConfig:
        _desktopLyricsController.fontFamily.value = cmdData['fontFamily'];
        _desktopLyricsController.fontSize.value = cmdData['fontSize'];
        _desktopLyricsController.fontWeight.value = cmdData['fontWeight'];
        _desktopLyricsController.overlayColor.value = cmdData['overlayColor'];
        _desktopLyricsController.underColor.value = cmdData['underColor'];
        _desktopLyricsController.fontOpacity.value = cmdData['fontOpacity'];
        _desktopLyricsController.isLock.value = cmdData['isLock'];
        await windowManager.setPosition(
          Offset(
            cmdData['dx']??50.0,
            cmdData['dy']??50.0,
          ),
        );
        await windowManager.setIgnoreMouseEvents(cmdData['isIgnoreMouseEvents']??false);
        return;
    }
  }

  void _positionHandle(Map<String, dynamic> data) {
    _desktopLyricsController.currentWordIndex.value = data['wordIndex'];
    _desktopLyricsController.wordProgress.value = data['progress'];
  }

  void _dataHandle(Map<String, dynamic> data) {
    _desktopLyricsController.lrcType.value = data['lyricsType'];

    if (_desktopLyricsController.lrcType.value != '.lrc') {
      final line = (data['lyrics'] as List<dynamic>).map((v) {
        return WordEntry(
          start: v['start'],
          duration: v['duration'],
          lyricWord: v['lyricWord'],
        );
      }).toList();

      _desktopLyricsController.currentLine.value = line;
    } else {
      _desktopLyricsController.currentLine.value = data['lyrics'];
    }

    _desktopLyricsController.currentTranslate.value = data['translate'];
  }

  void _add(dynamic msg) {
    if (_channel == null) {
      return;
    }

    try {
      _channel!.sink.add(msg);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void sendCmd({required String cmdType, dynamic cmdData}) {
    try {
      final jsonData = jsonEncode({
        'type': 'clientCmd',
        'cmdType': cmdType,
        'cmdData': cmdData,
      });
      _add(jsonData);
    } catch (_) {}
  }

  void close({bool sendCmd_ = true}) async {
    try {
      if(sendCmd_){
        sendCmd(cmdType: ClientCmdType.close);
      }

      if (_listen != null) {
        await _listen!.cancel();
        _listen = null;
      }

      if (_channel != null) {
        await _channel!.sink.close(status.normalClosure);
        _channel = null;
      }
      await windowManager.close();
    } catch (e) {
      debugPrint(e.toString());
      await windowManager.close();
    }
  }
}
