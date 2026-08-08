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
    var str = value.trim();
    if (str.endsWith('s')) str = str.substring(0, str.length - 1);
    return double.tryParse(str);
  }
}
