import 'dart:math';

/// 逐字歌词中的一个字。
class WordEntry {
  const WordEntry({
    required this.start,
    required this.duration,
    required this.lyricWord,
    this.furigana = '',
    this.furiganaGroupLength = 1,
  });

  final double start;
  final double duration;
  final String lyricWord;
  final String furigana;
  final int furiganaGroupLength;
}

abstract final class LyricFormat {
  static const qrc = '.qrc';
  static const yrc = '.yrc';
  static const krc = '.krc';
  static const lrc = '.lrc';
  static const byWordLrc = '.byWordLrc';
}

/// 一行歌词：要么是整行纯文本，要么是逐字时间轴。
///
/// 用密封类代替此前的 `dynamic` 载荷加一个独立的 `lrcType` 信号：
/// 格式与载荷不可能再失步，渲染侧的类型转换也全部由编译器检查。
sealed class LyricLine {
  const LyricLine();

  /// 翻译文本按该数量切分，使其在排版上与歌词逐段对应。
  int get segmentCount;
}

/// 整行纯文本歌词（.lrc）。
final class PlainLyricLine extends LyricLine {
  const PlainLyricLine(this.text);
  final String text;

  @override
  int get segmentCount => text.length;
}

/// 逐字歌词
final class KaraokeLyricLine extends LyricLine {
  const KaraokeLyricLine(this.words);
  final List<WordEntry> words;

  @override
  int get segmentCount => words.length;
}

/// 解析服务端下发的歌词载荷
LyricLine? parseLyricLine({
  required Object? lyricsType,
  required Object? lyrics,
}) {
  if (lyrics == null) return null;
  if (lyricsType != LyricFormat.lrc && lyrics is List) {
    return KaraokeLyricLine(
      lyrics.map(_parseWordEntry).toList(growable: false),
    );
  }
  return PlainLyricLine(lyrics is String ? lyrics : lyrics.toString());
}

/// 逐字条目的解析
WordEntry _parseWordEntry(Object? raw) {
  if (raw is! Map) {
    return const WordEntry(start: 0, duration: 0, lyricWord: '');
  }
  final start = raw['start'];
  final duration = raw['duration'];
  final groupLength = raw['furiganaGroupLength'];
  return WordEntry(
    start: start is num ? start.toDouble() : 0,
    duration: duration is num ? duration.toDouble() : 0,
    lyricWord: raw['lyricWord']?.toString() ?? '',
    furigana: raw['furigana']?.toString() ?? '',
    furiganaGroupLength: groupLength is num ? max(1, groupLength.round()) : 1,
  );
}

/// 把翻译切成 [count] 段，使其与歌词逐段对应
List<String> splitTranslate(String text, int count) {
  if (count <= 0 || count >= text.length) return text.split('');
  return [
    ...List.generate(count - 1, (i) => text[i]),
    text.substring(count - 1),
  ];
}
