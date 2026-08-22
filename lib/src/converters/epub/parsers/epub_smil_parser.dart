import 'package:xml/xml.dart';

class EpubSmilClip {
  final String textRef;
  final String audioSrc;
  final double? clipBegin;
  final double? clipEnd;

  const EpubSmilClip({
    required this.textRef,
    required this.audioSrc,
    this.clipBegin,
    this.clipEnd,
  });
}

class EpubSmilDocument {
  final List<EpubSmilClip> clips;

  const EpubSmilDocument({this.clips = const []});

  static EpubSmilDocument parseFromString(String xmlContent) {
    final document = XmlDocument.parse(xmlContent);
    final clips = <EpubSmilClip>[];

    for (final par in document.findAllElements('par')) {
      final text = par.findElements('text').firstOrNull;
      final audio = par.findElements('audio').firstOrNull;

      if (text != null && audio != null) {
        final textSrc = text.getAttribute('src') ?? '';
        final audioSrc = audio.getAttribute('src') ?? '';
        final beginStr = audio.getAttribute('clipBegin');
        final endStr = audio.getAttribute('clipEnd');

        clips.add(
          EpubSmilClip(
            textRef: textSrc,
            audioSrc: audioSrc,
            clipBegin: _parseClockValue(beginStr),
            clipEnd: _parseClockValue(endStr),
          ),
        );
      }
    }

    return EpubSmilDocument(clips: clips);
  }

  static double? _parseClockValue(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final str = value.trim();
    if (str.endsWith('ms')) {
      final ms = double.tryParse(str.substring(0, str.length - 2));
      return ms != null ? ms / 1000.0 : null;
    }
    if (str.endsWith('s')) {
      return double.tryParse(str.substring(0, str.length - 1));
    }
    if (str.endsWith('min')) {
      final min = double.tryParse(str.substring(0, str.length - 3));
      return min != null ? min * 60.0 : null;
    }
    if (str.endsWith('h')) {
      final h = double.tryParse(str.substring(0, str.length - 1));
      return h != null ? h * 3600.0 : null;
    }
    if (str.contains(':')) {
      final parts = str.split(':');
      if (parts.length == 3) {
        final h = double.tryParse(parts[0]) ?? 0;
        final m = double.tryParse(parts[1]) ?? 0;
        final s = double.tryParse(parts[2]) ?? 0;
        return h * 3600 + m * 60 + s;
      } else if (parts.length == 2) {
        final m = double.tryParse(parts[0]) ?? 0;
        final s = double.tryParse(parts[1]) ?? 0;
        return m * 60 + s;
      }
    }
    return double.tryParse(str);
  }
}
