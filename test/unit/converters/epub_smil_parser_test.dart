import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';

void main() {
  group('EpubSmilParser Tests (Media Overlays)', () {
    test('Parses valid SMIL 3.0 document with clock values and text/audio synchronization', () {
      const smilXml = '''<?xml version="1.0" encoding="UTF-8"?>
<smil xmlns="http://www.w3.org/ns/SMIL" xmlns:epub="http://www.idpf.org/2007/ops" version="3.0">
  <body>
    <par id="par1">
      <text src="chapter1.xhtml#p1"/>
      <audio src="audio/chapter1.mp3" clipBegin="0.0s" clipEnd="5.42s"/>
    </par>
    <par id="par2">
      <text src="chapter1.xhtml#p2"/>
      <audio src="audio/chapter1.mp3" clipBegin="5.42s" clipEnd="12.8s"/>
    </par>
  </body>
</smil>''';

      final doc = EpubSmilDocument.parseFromString(smilXml);
      expect(doc.clips.length, equals(2));

      final clip1 = doc.clips[0];
      expect(clip1.textRef, equals('chapter1.xhtml#p1'));
      expect(clip1.audioSrc, equals('audio/chapter1.mp3'));
      expect(clip1.clipBegin, equals(0.0));
      expect(clip1.clipEnd, equals(5.42));

      final clip2 = doc.clips[1];
      expect(clip2.textRef, equals('chapter1.xhtml#p2'));
      expect(clip2.audioSrc, equals('audio/chapter1.mp3'));
      expect(clip2.clipBegin, equals(5.42));
      expect(clip2.clipEnd, equals(12.8));
    });

    test('Handles malformed or empty SMIL document gracefully', () {
      const emptyXml = '<smil></smil>';
      final doc1 = EpubSmilDocument.parseFromString(emptyXml);
      expect(doc1.clips, isEmpty);

      const partialParXml = '''
<smil>
  <body>
    <par>
      <text src="chap.xhtml"/>
      <!-- missing audio -->
    </par>
    <par>
      <!-- missing text -->
      <audio src="audio.mp3"/>
    </par>
    <par>
      <text src="chap2.xhtml"/>
      <audio src="audio2.mp3" clipBegin="invalid" clipEnd=""/>
    </par>
  </body>
</smil>''';

      final doc2 = EpubSmilDocument.parseFromString(partialParXml);
      expect(doc2.clips.length, equals(1));
      expect(doc2.clips[0].textRef, equals('chap2.xhtml'));
      expect(doc2.clips[0].audioSrc, equals('audio2.mp3'));
      expect(doc2.clips[0].clipBegin, isNull);
      expect(doc2.clips[0].clipEnd, isNull);
    });

    test('Parses full SMIL 3.0 clock formats (hh:mm:ss, mm:ss, ms, min, h)', () {
      const clockXml = '''
<smil>
  <body>
    <par><text src="c1.xhtml"/><audio src="a.mp3" clipBegin="01:23:45.500" clipEnd="02:00:00"/></par>
    <par><text src="c2.xhtml"/><audio src="a.mp3" clipBegin="12:34.5" clipEnd="500ms"/></par>
    <par><text src="c3.xhtml"/><audio src="a.mp3" clipBegin="2min" clipEnd="1.5h"/></par>
  </body>
</smil>''';

      final doc = EpubSmilDocument.parseFromString(clockXml);
      expect(doc.clips.length, equals(3));

      // 01:23:45.500 = 3600 + 23*60 + 45.5 = 3600 + 1380 + 45.5 = 5025.5
      expect(doc.clips[0].clipBegin, equals(5025.5));
      expect(doc.clips[0].clipEnd, equals(7200.0));

      // 12:34.5 = 12*60 + 34.5 = 754.5; 500ms = 0.5s
      expect(doc.clips[1].clipBegin, equals(754.5));
      expect(doc.clips[1].clipEnd, equals(0.5));

      // 2min = 120s; 1.5h = 5400s
      expect(doc.clips[2].clipBegin, equals(120.0));
      expect(doc.clips[2].clipEnd, equals(5400.0));
    });
  });
}
