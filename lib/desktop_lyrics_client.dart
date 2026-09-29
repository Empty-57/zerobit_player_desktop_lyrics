import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:signals/signals_core.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:window_manager/window_manager.dart';
import 'package:zerobit_player_desktop_lyrics/tools/lrcTool/lyric_model.dart';

import 'controller/desktop_lyrics_ctrl.dart';

final DesktopLyricsController _desktopLyricsController =
    GetIt.I<DesktopLyricsController>();

abstract class _SeverMessageType {
  static const data = 'data';
  static const nextData = 'nextData';
  static const position = 'position';
  static const cmd = 'cmd';
}

abstract class DesktopSharedPreferencesKey {
  static const fontSize = 'desk_fontSize';
  static const fontWeight = 'desk_fontWeight';
  static const fontFamily = 'desk_fontFamily';
  static const overlayColor = 'desk_overlayColor';
  static const underColor = 'desk_underColor';
  static const fontOpacity = 'desk_fontOpacity';
  static const dx = 'desk_dx';
  static const dy = 'desk_dy';
  static const windowWidth = 'desk_windowWidth';
  static const windowHeight = 'desk_windowHeight';
  static const isIgnoreMouseEvents = 'desk_isIgnoreMouseEvents';
  static const lrcAlignment = 'desk_lrcAlignment';
  static const displayMode = 'desk_displayMode';
  static const useStroke = 'desk_useStroke';
  static const strokeColor = 'desk_strokeColor';
  static const showDoubleLine = 'desk_showDoubleLine';
  static const useDynamicOverlayColor = 'desk_useDynamicOverlayColor';
  static const lyricsSwitchAnimateMode = 'desk_lyricsSwitchAnimateMode';
  static const showKana = 'desk_showKana';
}

abstract class _SeverCmdType {
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
  static const setLrcAlignment = 'setLrcAlignment';
  static const setDisplayMode = 'setDisplayMode';
  static const setStrokeEnable = 'setStrokeEnable';
  static const setStrokeColor = 'setStrokeColor';
  static const heartBeat = 'heartBeat';
  static const showDoubleLine = 'showDoubleLine';
  static const setLyricsSwitchAnimateMode = 'setLyricsSwitchAnimateMode';
  static const setShowKana = 'setShowKana';
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
  static const heartBeat = 'heartBeat';
  static const setWindowWidth = 'setWindowWidth';
  static const setWindowHeight = 'setWindowHeight';
}

class DesktopLyricsClient {
  final _wsUrl = Uri.parse('ws://127.0.0.1:7070');
  IOWebSocketChannel? _channel;
  StreamSubscription? _listen;

  final _heartbeatInterval = const Duration(seconds: 10);
  final _heartbeatTimeout = const Duration(seconds: 5);
  final _alwaysOnTopTimeInterval = const Duration(seconds: 1);

  Timer? _heartbeatTimer;
  Timer? _heartbeatTimeoutTimer;
  Timer? _alwaysOnTopTimer;

  int _reconnectCounter = 0;

  final lyricsCounter = signal(0);

  void connect() async {
    _channel = IOWebSocketChannel.connect(_wsUrl);

    try {
      await _channel!.ready;
    } catch (e) {
      debugPrint(e.toString());
      Timer(Duration(seconds: 2), () async {
        _reconnectCounter++;
        if (_reconnectCounter > 15) {
          debugPrint('Reconnect failed!');
          await windowManager.close();
          return;
        }
        debugPrint('reconnect on $_reconnectCounter');
        connect();
      });
      return;
    }

    _add('ok');
    _listen = _channel!.stream.listen((message) async {
      _messageHandle(message);
    });
    _startHeartbeat();
    _startAlwaysOnTop();
  }

  void _startAlwaysOnTop() {
    _alwaysOnTopTimer?.cancel();
    _alwaysOnTopTimer = Timer.periodic(_alwaysOnTopTimeInterval, (_) async {
      await windowManager.setAlwaysOnTop(true);
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimeoutTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _sendHeartbeat();
      _startHeartbeatTimeout();
    });
  }

  void _sendHeartbeat() {
    try {
      final jsonData = jsonEncode({
        'type': 'clientCmd',
        'cmdType': ClientCmdType.heartBeat,
        'cmdData': 'ping',
      });
      _add(jsonData);
    } catch (_) {}
  }

  void _startHeartbeatTimeout() {
    _heartbeatTimeoutTimer?.cancel();
    _heartbeatTimeoutTimer = Timer(_heartbeatTimeout, () async {
      await windowManager.close();
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
          try {
            return _dataHandle(data);
          } catch (_) {}
        case _SeverMessageType.nextData:
          try {
            return _nextDataHandle(data);
          } catch (_) {}
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _cmdHandle(Map<String, dynamic> data) async {
    final cmdType = data['cmdType'];
    final cmdData = data['cmdData'];
    switch (cmdType) {
      case _SeverCmdType.shutdown:
        close(sendCmd_: false);
        return;
      case _SeverCmdType.changeStatus:
        _desktopLyricsController.currentState.value = cmdData as int;
        return;
      case _SeverCmdType.setFontSize:
        _desktopLyricsController.setFontSize(size: cmdData);
        return;
      case _SeverCmdType.setFontWeight:
        _desktopLyricsController.fontWeight.value = cmdData.clamp(0, 8);
        return;
      case _SeverCmdType.setFontFamily:
        _desktopLyricsController.fontFamily.value = cmdData;
        return;
      case _SeverCmdType.setOverlayColor:
        _desktopLyricsController.overlayColor.value = cmdData;
        return;
      case _SeverCmdType.setUnderColor:
        _desktopLyricsController.underColor.value = cmdData;
        return;
      case _SeverCmdType.setFontOpacity:
        _desktopLyricsController.fontOpacity.value = cmdData.clamp(0.0, 1.0);
        return;
      case _SeverCmdType.setIgnoreMouseEvents:
        _desktopLyricsController.isIgnoreMouseEvents.value = cmdData;
        await windowManager.setIgnoreMouseEvents(cmdData);
        return;
      case _SeverCmdType.setLrcAlignment:
        _desktopLyricsController.lrcAlignment.value = cmdData;
        return;
      case _SeverCmdType.setDisplayMode:
        _desktopLyricsController.setUseVerticalDisplayMode(use: cmdData);
        return;
      case _SeverCmdType.setStrokeEnable:
        _desktopLyricsController.useStroke.value = cmdData;
        return;
      case _SeverCmdType.setStrokeColor:
        _desktopLyricsController.strokeColor.value = cmdData;
        return;
      case _SeverCmdType.showDoubleLine:
        _desktopLyricsController.showDoubleLine.value = cmdData;
        return;
      case _SeverCmdType.setLyricsSwitchAnimateMode:
        _desktopLyricsController.lyricsSwitchAnimateMode.value = cmdData;
        return;
      case _SeverCmdType.setShowKana:
        _desktopLyricsController.showKana.value = cmdData;
        return;
      case _SeverCmdType.heartBeat:
        return _heartbeatTimeoutTimer?.cancel();
      case _SeverCmdType.putConfig:
        _desktopLyricsController.fontFamily.value =
            cmdData[DesktopSharedPreferencesKey.fontFamily];
        _desktopLyricsController.fontSize.value =
            cmdData[DesktopSharedPreferencesKey.fontSize];
        _desktopLyricsController.fontWeight.value =
            cmdData[DesktopSharedPreferencesKey.fontWeight];
        _desktopLyricsController.overlayColor.value =
            cmdData[DesktopSharedPreferencesKey.overlayColor];
        _desktopLyricsController.underColor.value =
            cmdData[DesktopSharedPreferencesKey.underColor];
        _desktopLyricsController.fontOpacity.value =
            cmdData[DesktopSharedPreferencesKey.fontOpacity];
        await windowManager.setPosition(
          Offset(
            cmdData[DesktopSharedPreferencesKey.dx] ?? 50.0,
            cmdData[DesktopSharedPreferencesKey.dy] ?? 50.0,
          ),
        );
        _desktopLyricsController.isIgnoreMouseEvents.value =
            cmdData[DesktopSharedPreferencesKey.isIgnoreMouseEvents] ?? false;
        await windowManager.setIgnoreMouseEvents(
          _desktopLyricsController.isIgnoreMouseEvents.value,
          forward: false,
        );
        _desktopLyricsController.lrcAlignment.value =
            cmdData[DesktopSharedPreferencesKey.lrcAlignment];
        _desktopLyricsController.useVerticalDisplayMode.value =
            cmdData[DesktopSharedPreferencesKey.displayMode];
        _desktopLyricsController.useStroke.value =
            cmdData[DesktopSharedPreferencesKey.useStroke];
        _desktopLyricsController.strokeColor.value =
            cmdData[DesktopSharedPreferencesKey.strokeColor];
        await _desktopLyricsController.calcSize(
          cmdData[DesktopSharedPreferencesKey.windowWidth] ??
              DesktopLyricsController.windowWidthMin,
          cmdData[DesktopSharedPreferencesKey.windowHeight] ??
              DesktopLyricsController.windowHeightMin,
        );
        _desktopLyricsController.showDoubleLine.value =
            cmdData[DesktopSharedPreferencesKey.showDoubleLine];
        _desktopLyricsController.lyricsSwitchAnimateMode.value =
            cmdData[DesktopSharedPreferencesKey.lyricsSwitchAnimateMode];
        _desktopLyricsController.showKana.value =
            cmdData[DesktopSharedPreferencesKey.showKana];
        return;
    }
  }

  void _positionHandle(Map<String, dynamic> data) {
    _desktopLyricsController.currentWordIndex.value = data['wordIndex'];
    _desktopLyricsController.wordProgress.value = data['progress'];
  }

  void _dataHandle(Map<String, dynamic> data) {
    final lrcType = data['lyricsType'];
    final rawLyrics = data['lyrics'];
    final translate = data['translate'];

    dynamic parsedLine;
    if (lrcType != '.lrc' && rawLyrics is List) {
      parsedLine = rawLyrics.map((v) {
        if (v == null) {
          return WordEntry(
            start: 0.0,
            duration: 0.0,
            lyricWord: '',
            furigana: '',
          );
        }
        return WordEntry(
          start: (v['start'] as num?)?.toDouble() ?? 0.0,
          duration: (v['duration'] as num?)?.toDouble() ?? 0.0,
          lyricWord: v['lyricWord']?.toString() ?? '',
          furigana: v['furigana']?.toString() ?? '',
          furiganaGroupLength: (v['furiganaGroupLength'] as num?)?.toInt() ?? 1,
        );
      }).toList();
    } else {
      parsedLine = rawLyrics;
    }

    batch(() {
      _desktopLyricsController.currentWordIndex.value = -1;
      _desktopLyricsController.lrcType.value = lrcType;
      _desktopLyricsController.currentLine.value = parsedLine;
      _desktopLyricsController.currentTranslate.value = translate;
      lyricsCounter.value++;
    });
  }

  void _nextDataHandle(Map<String, dynamic> data) {
    final lrcType = data['lyricsType'];
    final rawLyrics = data['lyrics'];
    final translate = data['translate'];

    dynamic parsedLine;
    if (lrcType != '.lrc' && rawLyrics is List) {
      parsedLine = rawLyrics.map((v) {
        if (v == null) {
          return WordEntry(
            start: 0.0,
            duration: 0.0,
            lyricWord: '',
            furigana: '',
          );
        }
        return WordEntry(
          start: (v['start'] as num?)?.toDouble() ?? 0.0,
          duration: (v['duration'] as num?)?.toDouble() ?? 0.0,
          lyricWord: v['lyricWord']?.toString() ?? '',
          furigana: v['furigana']?.toString() ?? '',
          furiganaGroupLength: (v['furiganaGroupLength'] as num?)?.toInt() ?? 1,
        );
      }).toList();
    } else {
      parsedLine = rawLyrics;
    }

    batch(() {
      _desktopLyricsController.currentWordIndex.value = -1;
      _desktopLyricsController.lrcType.value = lrcType;
      _desktopLyricsController.nextLine.value = parsedLine;
      _desktopLyricsController.nextTranslate.value = translate;
    });
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
      if (sendCmd_) {
        sendCmd(cmdType: ClientCmdType.close);
      }

      _alwaysOnTopTimer?.cancel();

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
      _alwaysOnTopTimer?.cancel();
      await windowManager.close();
    }
  }
}
