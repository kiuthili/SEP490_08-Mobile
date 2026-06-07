import 'dart:convert';

class TextEncoding {
  TextEncoding._();

  static const _windows1252Bytes = <int, int>{
    0x20AC: 0x80,
    0x201A: 0x82,
    0x0192: 0x83,
    0x201E: 0x84,
    0x2026: 0x85,
    0x2020: 0x86,
    0x2021: 0x87,
    0x02C6: 0x88,
    0x2030: 0x89,
    0x0160: 0x8A,
    0x2039: 0x8B,
    0x0152: 0x8C,
    0x017D: 0x8E,
    0x2018: 0x91,
    0x2019: 0x92,
    0x201C: 0x93,
    0x201D: 0x94,
    0x2022: 0x95,
    0x2013: 0x96,
    0x2014: 0x97,
    0x02DC: 0x98,
    0x2122: 0x99,
    0x0161: 0x9A,
    0x203A: 0x9B,
    0x0153: 0x9C,
    0x017E: 0x9E,
    0x0178: 0x9F,
  };

  static String repairMojibake(String value) {
    if (!_looksLikeUtf8Mojibake(value)) return value;

    try {
      final bytes = <int>[];
      for (final rune in value.runes) {
        final byte = rune <= 0xFF ? rune : _windows1252Bytes[rune];
        if (byte == null) return value;
        bytes.add(byte);
      }
      final repaired = utf8.decode(bytes);
      return _mojibakeScore(repaired) < _mojibakeScore(value)
          ? repaired
          : value;
    } on FormatException {
      return value;
    }
  }

  static bool _looksLikeUtf8Mojibake(String value) {
    return value.contains('Ã') ||
        value.contains('Â') ||
        value.contains('Ä') ||
        value.contains('áº') ||
        value.contains('á»') ||
        value.contains('â€');
  }

  static int _mojibakeScore(String value) {
    const markers = ['Ã', 'Â', 'Ä', 'áº', 'á»', 'â€', '\uFFFD'];
    return markers.fold(
      0,
      (score, marker) => score + marker.allMatches(value).length,
    );
  }
}
