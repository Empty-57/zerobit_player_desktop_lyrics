import 'package:flutter/material.dart';

/// 歌词槽位只显示新行，因此只保留入场动画，立即释放旧行的订阅。
class LyricSlotTransition extends StatefulWidget {
  const LyricSlotTransition({
    super.key,
    required this.version,
    required this.duration,
    required this.alignment,
    required this.transitionBuilder,
    required this.child,
  });

  final String version;
  final Duration duration;
  final Alignment alignment;
  final Widget Function(Animation<double>, Widget) transitionBuilder;
  final Widget child;

  @override
  State<LyricSlotTransition> createState() => _LyricSlotTransitionState();
}

class _LyricSlotTransitionState extends State<LyricSlotTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(LyricSlotTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (oldWidget.version != widget.version) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    alignment: widget.alignment,
    children: [
      widget.transitionBuilder(
        _animation,
        KeyedSubtree(key: ValueKey(widget.version), child: widget.child),
      ),
    ],
  );
}
