import 'dart:io';

class SubtitleItem {
  const SubtitleItem({
    required this.start,
    required this.end,
    required this.text,
  });

  final Duration start;
  final Duration end;
  final String text;
}

class SrtParser {
  static Future<List<SubtitleItem>> parseFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return [];
      final content = await file.readAsString();
      return parseText(content);
    } catch (_) {
      return [];
    }
  }

  static List<SubtitleItem> parseText(String content) {
    final items = <SubtitleItem>[];
    final lines = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');

    int i = 0;
    while (i < lines.length) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        i++;
        continue;
      }

      // Check if this line is an index or timestamp line
      String timeLine = '';
      if (line.contains('-->')) {
        timeLine = line;
        i++;
      } else if (i + 1 < lines.length && lines[i + 1].contains('-->')) {
        timeLine = lines[i + 1].trim();
        i += 2;
      } else {
        i++;
        continue;
      }

      final parts = timeLine.split('-->');
      if (parts.length != 2) continue;

      final start = _parseTimestamp(parts[0].trim());
      final end = _parseTimestamp(parts[1].trim());
      if (start == null || end == null) continue;

      final textBuffer = StringBuffer();
      while (i < lines.length && lines[i].trim().isNotEmpty) {
        if (textBuffer.isNotEmpty) textBuffer.write('\n');
        textBuffer.write(lines[i].trim());
        i++;
      }

      final text = textBuffer.toString().replaceAll(RegExp(r'<[^>]*>'), '');
      if (text.isNotEmpty) {
        items.add(SubtitleItem(start: start, end: end, text: text));
      }
    }

    return items;
  }

  static Duration? _parseTimestamp(String s) {
    // 00:01:20,000 or 00:01:20.000 or 01:20.000
    try {
      final clean = s.replaceAll(',', '.');
      final parts = clean.split(':');
      if (parts.length == 3) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final secParts = parts[2].split('.');
        final seconds = int.parse(secParts[0]);
        final millis = secParts.length > 1 ? int.parse(secParts[1].padRight(3, '0').substring(0, 3)) : 0;
        return Duration(hours: hours, minutes: minutes, seconds: seconds, milliseconds: millis);
      } else if (parts.length == 2) {
        final minutes = int.parse(parts[0]);
        final secParts = parts[1].split('.');
        final seconds = int.parse(secParts[0]);
        final millis = secParts.length > 1 ? int.parse(secParts[1].padRight(3, '0').substring(0, 3)) : 0;
        return Duration(minutes: minutes, seconds: seconds, milliseconds: millis);
      }
    } catch (_) {}
    return null;
  }

  /// Finds subtitle for given duration with delay offset applied
  static String? findSubtitle(List<SubtitleItem> items, Duration currentPosition, Duration delay) {
    if (items.isEmpty) return null;
    final pos = currentPosition - delay;
    if (pos.isNegative) return null;

    for (final item in items) {
      if (pos >= item.start && pos <= item.end) {
        return item.text;
      }
    }
    return null;
  }
}
