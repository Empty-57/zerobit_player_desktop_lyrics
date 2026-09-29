import 'package:flutter/widgets.dart';

/// 播放器状态
enum AudioState {
  stop,
  playing,
  pause;

  static AudioState fromIndex(int index) =>
      (index >= 0 && index < values.length) ? values[index] : stop;
}

/// 歌词对齐方式
enum LyricAlignment {
  start,
  center,
  end,
  alternate;

  static LyricAlignment fromIndex(int index) =>
      (index >= 0 && index < values.length) ? values[index] : center;

  /// 解析为行内容的交叉轴对齐。
  ///
  /// [isNextLine] 区分「当前行」与「下一行」两个槽位，
  ///
  /// [lineCounter] 是已切换的歌词行数，两者共同决定 [alternate] 落在哪一侧。
  CrossAxisAlignment resolve({
    required bool isNextLine,
    required bool showDoubleLine,
    required int lineCounter,
  }) => switch (this) {
    LyricAlignment.start => CrossAxisAlignment.start,
    LyricAlignment.center => CrossAxisAlignment.center,
    LyricAlignment.end => CrossAxisAlignment.end,
    // 单行模式下没有「对面」可交替，退化为当前行靠左、下一行靠右。
    LyricAlignment.alternate when !showDoubleLine =>
      isNextLine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    LyricAlignment.alternate =>
      (lineCounter.isEven ^ isNextLine)
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
  };

  /// 外层容器（工具栏加两行歌词）的交叉轴对齐。
  /// [alternate] 下左右由各行自行决定，容器取 start 让行铺满。
  CrossAxisAlignment get containerAlignment => switch (this) {
    LyricAlignment.start ||
    LyricAlignment.alternate => CrossAxisAlignment.start,
    LyricAlignment.center => CrossAxisAlignment.center,
    LyricAlignment.end => CrossAxisAlignment.end,
  };
}

/// 歌词切换动画
enum LyricSwitchAnimation {
  none,
  fade,
  slide,
  scale;

  static LyricSwitchAnimation fromIndex(int index) =>
      (index >= 0 && index < values.length) ? values[index] : fade;
}
