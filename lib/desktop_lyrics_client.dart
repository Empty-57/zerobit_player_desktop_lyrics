import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:signals/signals_core.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:window_manager/window_manager.dart';

import 'controller/desktop_lyrics_ctrl.dart';
import 'controller/display_settings.dart';
import 'tools/lrcTool/lyric_model.dart';

final DesktopLyricsController _desktopLyricsController =
    GetIt.I<DesktopLyricsController>();

abstract final class _ServerMessageType {
  static const data = 'data';
  static const nextData = 'nextData';
  static const position = 'position';
  static const cmd = 'cmd';
}

abstract final class DesktopSharedPreferencesKey {
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

abstract final class _ServerCmdType {
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

abstract final class ClientCmdType {
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

// 类型解析方法
double? _asDouble(Object? value) => value is num ? value.toDouble() : null;

int? _asInt(Object? value) => value is num ? value.round() : null;

bool? _asBool(Object? value) => value is bool ? value : null;

String? _asString(Object? value) => value is String ? value : null;

/// 与播放器主进程的 WebSocket 连接：接收歌词与配置，回传用户在歌词窗口上的操作。
class DesktopLyricsClient {
  final _wsUrl = Uri.parse('ws://127.0.0.1:7070');

  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _listen;

  final _heartbeatInterval = const Duration(seconds: 10);
  final _heartbeatTimeout = const Duration(seconds: 5);
  final _alwaysOnTopTimeInterval = const Duration(seconds: 1);
  final _reconnectDelay = const Duration(seconds: 2);

  static const _maxReconnectAttempts = 15;

  Timer? _heartbeatTimer;
  Timer? _heartbeatTimeoutTimer;
  Timer? _alwaysOnTopTimer;
  Timer? _reconnectTimer;

  int _reconnectCounter = 0;

  /// 已切换的歌词行数。双行模式据此在两个槽位间轮换，也用于触发切换动画。
  final lyricsCounter = signal(0);

  /// 连接服务端。首次连接失败会按 [_reconnectDelay] 重试，
  /// 超过 [_maxReconnectAttempts] 次后关闭窗口。
  Future<void> connect() async {
    await _closeConnection();

    final channel = IOWebSocketChannel.connect(_wsUrl);
    _channel = channel;

    try {
      await channel.ready;
    } catch (e) {
      debugPrint('connect failed: $e');
      _scheduleReconnect();
      return;
    }

    // 连上即清零
    _reconnectCounter = 0;

    _add('ok');
    _listen = channel.stream.listen(
      _messageHandle,
      // 断线不自动重连：交给心跳超时关闭窗口，
      onError: (Object e) => debugPrint('socket error: $e'),
      onDone: () => debugPrint('socket closed: ${channel.closeCode}'),
    );

    _startHeartbeat();
    _startAlwaysOnTop();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () async {
      _reconnectCounter++;
      if (_reconnectCounter > _maxReconnectAttempts) {
        debugPrint('Reconnect failed!');
        await windowManager.close();
        return;
      }
      debugPrint('reconnect on $_reconnectCounter');
      await connect();
    });
  }

  /// 歌词窗口需要始终压在其它窗口之上，定期重申一次置顶。
  void _startAlwaysOnTop() {
    _alwaysOnTopTimer?.cancel();
    _alwaysOnTopTimer = Timer.periodic(_alwaysOnTopTimeInterval, (_) async {
      await windowManager.setAlwaysOnTop(true);
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      sendCmd(cmdType: ClientCmdType.heartBeat, cmdData: 'ping');
      _startHeartbeatTimeout();
    });
  }

  /// 心跳发出后若在 [_heartbeatTimeout] 内没收到回应，视作播放器已退出。
  /// 服务端的 `heartBeat` 命令会取消这个定时器。
  void _startHeartbeatTimeout() {
    _heartbeatTimeoutTimer?.cancel();
    _heartbeatTimeoutTimer = Timer(_heartbeatTimeout, () async {
      debugPrint('heartbeat timeout');
      await windowManager.close();
    });
  }

  void _messageHandle(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      switch (data['type']) {
        case _ServerMessageType.cmd:
          unawaited(_cmdHandle(data));
        case _ServerMessageType.position:
          _positionHandle(data);
        case _ServerMessageType.data:
          _lyricLineHandle(data, isNextLine: false);
        case _ServerMessageType.nextData:
          _lyricLineHandle(data, isNextLine: true);
      }
    } catch (e) {
      debugPrint('message handle failed: $e');
    }
  }

  Future<void> _cmdHandle(Map<String, dynamic> data) async {
    final ctrl = _desktopLyricsController;
    final Object? cmdData = data['cmdData'];

    switch (data['cmdType']) {
      case _ServerCmdType.shutdown:
        await close(notifyServer: false);
      case _ServerCmdType.heartBeat:
        _heartbeatTimeoutTimer?.cancel();
      case _ServerCmdType.putConfig:
        await _putConfig(cmdData);
      case _ServerCmdType.changeStatus:
        ctrl.currentState.value = AudioState.fromIndex(_asInt(cmdData) ?? 0);
      case _ServerCmdType.setFontSize:
        ctrl.setFontSize(size: _asInt(cmdData) ?? ctrl.fontSize.value);
      case _ServerCmdType.setFontWeight:
        ctrl.fontWeight.value = (_asInt(cmdData) ?? ctrl.fontWeight.value)
            .clamp(0, 8);
      case _ServerCmdType.setFontFamily:
        ctrl.fontFamily.value = _asString(cmdData) ?? ctrl.fontFamily.value;
      case _ServerCmdType.setOverlayColor:
        ctrl.overlayColor.value = _asInt(cmdData) ?? ctrl.overlayColor.value;
      case _ServerCmdType.setUnderColor:
        ctrl.underColor.value = _asInt(cmdData) ?? ctrl.underColor.value;
      case _ServerCmdType.setFontOpacity:
        ctrl.fontOpacity.value = (_asDouble(cmdData) ?? ctrl.fontOpacity.value)
            .clamp(0.0, 1.0);
      case _ServerCmdType.setIgnoreMouseEvents:
        final ignore = _asBool(cmdData) ?? false;
        ctrl.isIgnoreMouseEvents.value = ignore;
        await windowManager.setIgnoreMouseEvents(ignore);
      case _ServerCmdType.setLrcAlignment:
        ctrl.lrcAlignment.value = LyricAlignment.fromIndex(
          _asInt(cmdData) ?? 1,
        );
      case _ServerCmdType.setDisplayMode:
        ctrl.setUseVerticalDisplayMode(use: _asBool(cmdData) ?? false);
      case _ServerCmdType.setStrokeEnable:
        ctrl.useStroke.value = _asBool(cmdData) ?? ctrl.useStroke.value;
      case _ServerCmdType.setStrokeColor:
        ctrl.strokeColor.value = _asInt(cmdData) ?? ctrl.strokeColor.value;
      case _ServerCmdType.showDoubleLine:
        ctrl.showDoubleLine.value =
            _asBool(cmdData) ?? ctrl.showDoubleLine.value;
      case _ServerCmdType.setLyricsSwitchAnimateMode:
        ctrl.lyricsSwitchAnimateMode.value = LyricSwitchAnimation.fromIndex(
          _asInt(cmdData) ?? 1,
        );
      case _ServerCmdType.setShowKana:
        ctrl.showKana.value = _asBool(cmdData) ?? ctrl.showKana.value;
    }
  }

  /// 应用播放器保存的整套配置。
  Future<void> _putConfig(Object? raw) async {
    if (raw is! Map) {
      debugPrint('putConfig: unexpected payload ($raw)');
      return;
    }

    final ctrl = _desktopLyricsController;

    ctrl.fontFamily.value =
        _asString(raw[DesktopSharedPreferencesKey.fontFamily]) ??
        ctrl.fontFamily.value;
    ctrl.setFontSize(
      size:
          _asInt(raw[DesktopSharedPreferencesKey.fontSize]) ??
          ctrl.fontSize.value,
    );
    ctrl.fontWeight.value =
        (_asInt(raw[DesktopSharedPreferencesKey.fontWeight]) ??
                ctrl.fontWeight.value)
            .clamp(0, 8);
    ctrl.overlayColor.value =
        _asInt(raw[DesktopSharedPreferencesKey.overlayColor]) ??
        ctrl.overlayColor.value;
    ctrl.underColor.value =
        _asInt(raw[DesktopSharedPreferencesKey.underColor]) ??
        ctrl.underColor.value;
    ctrl.fontOpacity.value =
        (_asDouble(raw[DesktopSharedPreferencesKey.fontOpacity]) ??
                ctrl.fontOpacity.value)
            .clamp(0.0, 1.0);

    await windowManager.setPosition(
      Offset(
        _asDouble(raw[DesktopSharedPreferencesKey.dx]) ?? 50,
        _asDouble(raw[DesktopSharedPreferencesKey.dy]) ?? 50,
      ),
    );

    final ignoreMouse =
        _asBool(raw[DesktopSharedPreferencesKey.isIgnoreMouseEvents]) ?? false;
    ctrl.isIgnoreMouseEvents.value = ignoreMouse;
    await windowManager.setIgnoreMouseEvents(ignoreMouse, forward: false);

    ctrl.lrcAlignment.value = LyricAlignment.fromIndex(
      _asInt(raw[DesktopSharedPreferencesKey.lrcAlignment]) ?? 1,
    );

    ctrl.useVerticalDisplayMode.value =
        _asBool(raw[DesktopSharedPreferencesKey.displayMode]) ?? false;
    ctrl.useStroke.value =
        _asBool(raw[DesktopSharedPreferencesKey.useStroke]) ?? true;
    ctrl.strokeColor.value =
        _asInt(raw[DesktopSharedPreferencesKey.strokeColor]) ??
        ctrl.strokeColor.value;

    await ctrl.calcSize(
      _asDouble(raw[DesktopSharedPreferencesKey.windowWidth]) ??
          DesktopLyricsController.windowWidthMin,
      _asDouble(raw[DesktopSharedPreferencesKey.windowHeight]) ??
          DesktopLyricsController.windowHeightMin,
    );

    ctrl.showDoubleLine.value =
        _asBool(raw[DesktopSharedPreferencesKey.showDoubleLine]) ?? false;
    ctrl.lyricsSwitchAnimateMode.value = LyricSwitchAnimation.fromIndex(
      _asInt(raw[DesktopSharedPreferencesKey.lyricsSwitchAnimateMode]) ?? 1,
    );
    ctrl.showKana.value =
        _asBool(raw[DesktopSharedPreferencesKey.showKana]) ?? true;
  }

  /// 播放进度
  void _positionHandle(Map<String, dynamic> data) {
    final ctrl = _desktopLyricsController;
    batch(() {
      ctrl.currentWordIndex.value = _asInt(data['wordIndex']) ?? -1;
      ctrl.wordProgress.value = _asDouble(data['progress']) ?? 0;
    });
  }

  /// 收到新的一行歌词。[isNextLine] 区分「当前行」与「预告的下一行」。
  void _lyricLineHandle(Map<String, dynamic> data, {required bool isNextLine}) {
    final line = parseLyricLine(
      lyricsType: data['lyricsType'],
      lyrics: data['lyrics'],
    );
    final translate = _asString(data['translate']) ?? '';
    final ctrl = _desktopLyricsController;

    batch(() {
      ctrl.currentWordIndex.value = -1;
      if (isNextLine) {
        ctrl.nextLine.value = line;
        ctrl.nextTranslate.value = translate;
      } else {
        ctrl.currentLine.value = line;
        ctrl.currentTranslate.value = translate;
        // 只有当前行推进计数：双行模式据此轮换槽位
        lyricsCounter.value++;
      }
    });
  }

  void _add(Object? msg) {
    final channel = _channel;
    if (channel == null) return;
    try {
      channel.sink.add(msg);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void sendCmd({required String cmdType, Object? cmdData}) {
    try {
      _add(
        jsonEncode({
          'type': 'clientCmd',
          'cmdType': cmdType,
          'cmdData': cmdData,
        }),
      );
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  /// 收起歌词窗口。
  ///
  /// [notifyServer] 为 false 用于服务端主动下发 shutdown 的情形
  Future<void> close({bool notifyServer = true}) async {
    if (notifyServer) sendCmd(cmdType: ClientCmdType.close);
    _cancelTimers();
    await _closeConnection();
    await windowManager.close();
  }

  void _cancelTimers() {
    _reconnectTimer?.cancel();
    _alwaysOnTopTimer?.cancel();
    _heartbeatTimer?.cancel();
    _heartbeatTimeoutTimer?.cancel();
  }

  /// 关掉当前订阅与通道，但保留重连计数
  Future<void> _closeConnection() async {
    final listen = _listen;
    final channel = _channel;
    _listen = null;
    _channel = null;
    try {
      await listen?.cancel();
      await channel?.sink.close(status.normalClosure);
    } catch (e) {
      debugPrint(e.toString());
    }
  }
}
