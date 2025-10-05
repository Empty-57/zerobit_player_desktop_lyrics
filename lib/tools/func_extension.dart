import 'dart:async';

bool _throttleIsAllowed = true;

extension ThrottleExtension on Function {
  void Function() throttle({int ms = 500}) {
    Timer? throttleTimer;
    return () {
      if (!_throttleIsAllowed) return;
      _throttleIsAllowed = false;
      this();
      throttleTimer?.cancel();
      throttleTimer = Timer(Duration(milliseconds: ms), () {
        _throttleIsAllowed = true;
      });
    };
  }
}
