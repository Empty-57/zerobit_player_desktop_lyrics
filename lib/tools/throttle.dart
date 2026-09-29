import 'package:flutter/foundation.dart';

/// 节流包装
VoidCallback throttle(
  VoidCallback action, {
  Duration duration = const Duration(milliseconds: 500),
}) {
  DateTime? lastInvocation;
  return () {
    final now = DateTime.now();
    final last = lastInvocation;
    if (last != null && now.difference(last) < duration) return;
    lastInvocation = now;
    action();
  };
}
