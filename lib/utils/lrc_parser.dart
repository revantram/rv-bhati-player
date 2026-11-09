import 'dart:io';

class LrcLine {
  const LrcLine(this.time, this.text);
  final Duration time;
  final String text;
}

class LrcParser {
  static Future<List<LrcLine>> parseFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return [];
      final content = await file.readAsString();
      return parseText(content);
    } catch (_) {
      return [];
    }
  }

  static List<LrcLine> parseString(String content) => parseText(content);

  static List<LrcLine> parseText(String content) {
    final list = <LrcLine>[];
    final lines = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final regExp = RegExp(r'\[(\d{2}):(\d{2})\.?(\d{0,3})\](.*)');

    for (final line in lines) {
      final match = regExp.firstMatch(line.trim());
      if (match != null) {
        final min = int.parse(match.group(1)!);
        final sec = int.parse(match.group(2)!);
        final msStr = match.group(3) ?? '0';
        final ms = msStr.isEmpty ? 0 : int.parse(msStr.padRight(3, '0').substring(0, 3));
        final text = (match.group(4) ?? '').trim();
        list.add(LrcLine(Duration(minutes: min, seconds: sec, milliseconds: ms), text));
      }
    }

    list.sort((a, b) => a.time.compareTo(b.time));
    return list;
  }

  static int findActiveIndex(List<LrcLine> lines, Duration currentPosition) {
    if (lines.isEmpty) return -1;
    for (int i = lines.length - 1; i >= 0; i--) {
      if (currentPosition >= lines[i].time) {
        return i;
      }
    }
    return 0;
  }
}
