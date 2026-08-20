import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';

Uint8List encodeWin1251(String str) {
  final list = <int>[];
  for (final char in str.runes) {
    if (char < 128) {
      list.add(char);
    } else if (char >= 0x0410 && char <= 0x044F) {
      list.add(char - 0x0410 + 0xC0);
    } else if (char == 0x0401) {
      list.add(0xA8); // Ё
    } else if (char == 0x0451) {
      list.add(0xB8); // ё
    } else if (char == 0x00AB) {
      list.add(0xAB); // «
    } else if (char == 0x00BB) {
      list.add(0xBB); // »
    } else if (char == 0x2014) {
      list.add(0x97); // —
    } else if (char == 0x2013) {
      list.add(0x96); // –
    } else if (char == 0x2026) {
      list.add(0x85); // …
    } else if (char == 0x201C) {
      list.add(0x93); // “
    } else if (char == 0x201D) {
      list.add(0x94); // ”
    } else if (char == 0x2018) {
      list.add(0x91); // ‘
    } else if (char == 0x2019) {
      list.add(0x92); // ’
    } else if (char == 0x00A0) {
      list.add(0xA0); // non-breaking space
    } else if (char == 0x2116) {
      list.add(0xB9); // №
    } else {
      list.add(63); // ?
    }
  }
  return Uint8List.fromList(list);
}

void main() {
  Directory('test/fixtures/fb2').createSync(recursive: true);
  Directory('test/fixtures/epub').createSync(recursive: true);

  // 1. litres_sample.fb2 (Win-1251)
  final litresFb2Xml = '''<?xml version="1.0" encoding="windows-1251"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  <description>
    <title-info>
      <genre>prose_classic</genre>
      <genre>poetry</genre>
      <author>
        <first-name>Александр</first-name>
        <middle-name>Сергеевич</middle-name>
        <last-name>Пушкин</last-name>
        <email>pushkin@litres.ru</email>
      </author>
      <book-title>Евгений Онегин и стихотворения</book-title>
      <annotation>
        <p>Шедевр русской классической литературы.</p>
      </annotation>
      <date value="1833-01-01">1833</date>
      <coverpage>
        <image l:href="#cover.jpg"/>
      </coverpage>
      <lang>ru</lang>
      <sequence name="Русская Классика" number="1"/>
    </title-info>
    <document-info>
      <author>
        <nickname>litres_editor</nickname>
      </author>
      <program-used>LitRes FB2 Generator v2.0</program-used>
      <date value="2023-01-15">15 января 2023</date>
      <id>litres-book-uuid-123456</id>
      <version>1.0</version>
    </document-info>
    <publish-info>
      <publisher>Издательство Литрес Эксмо</publisher>
      <city>Москва</city>
      <year>2023</year>
      <isbn>978-5-04-123456-7</isbn>
    </publish-info>
  </description>
  <body>
    <title>
      <p>Евгений Онегин</p>
    </title>
    <epigraph>
      <p>И жить торопится, и чувствовать спешит.</p>
      <text-author>Кн. Вяземский</text-author>
    </epigraph>
    <section>
      <title>
        <p>Глава I</p>
      </title>
      <epigraph>
        <p>И в голос все решили так,</p>
        <p>Что он опаснейший чудак.</p>
        <text-author>Грибоедов</text-author>
      </epigraph>
      <p>«Мой дядя самых честных правил,<empty-line/>Когда не в шутку занемог,<empty-line/>Он уважать себя заставил<empty-line/>И лучше выдумать не мог<a type="note" l:href="#note_1">[1]</a>.»</p>
      <poem>
        <stanza>
          <v>Так думал молодой повеса,</v>
          <v>Летя в пыли на почтовых,</v>
          <v>Всевышней волею Зевеса</v>
          <v>Наследник всех своих родных.</v>
        </stanza>
      </poem>
      <p>Служив отлично благородно, долгами жил его отец<a type="note" l:href="#note_2">[2]</a>.</p>
    </section>
  </body>
  <body name="notes">
    <title>
      <p>Примечания</p>
    </title>
    <section id="note_1">
      <title>
        <p>1</p>
      </title>
      <p>Ирония на басню И. А. Крылова «Осел и Мужик».</p>
    </section>
    <section id="note_2">
      <title>
        <p>2</p>
      </title>
      <p>Обычная судьба петербургского дворянства того времени.</p>
    </section>
  </body>
  <binary id="cover.jpg" content-type="image/jpeg">/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=</binary>
</FictionBook>
''';

  final win1251Bytes = encodeWin1251(litresFb2Xml);
  File('test/fixtures/fb2/litres_sample.fb2').writeAsBytesSync(win1251Bytes);
  print('Wrote test/fixtures/fb2/litres_sample.fb2 (\${win1251Bytes.length} bytes)');

  // 2. fb2_21_sample.fb2 (UTF-8, all FB2 2.1 elements)
  final fb221Xml = '''<?xml version="1.0" encoding="UTF-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  <description>
    <title-info>
      <genre>science</genre>
      <author>
        <first-name>Alan</first-name>
        <last-name>Turing</last-name>
      </author>
      <book-title>FB2 2.1 Specification Reference</book-title>
      <lang>ru</lang>
      <src-lang>en</src-lang>
    </title-info>
    <src-title-info>
      <genre>science</genre>
      <author>
        <first-name>Alan</first-name>
        <middle-name>Mathison</middle-name>
        <last-name>Turing</last-name>
        <nickname>AMT</nickname>
      </author>
      <book-title>Computing Machinery and Intelligence</book-title>
      <lang>en</lang>
    </src-title-info>
    <document-info>
      <id>fb2-21-spec-reference-doc-001</id>
      <date value="2024-01-01">2024-01-01</date>
    </document-info>
  </description>
  <body>
    <title>
      <p>FB2 2.1 Features Demonstration</p>
    </title>
    <subtitle>
      <p>Comprehensive Element Reference</p>
    </subtitle>
    <section>
      <title>
        <p>1. Formatting and Formulas</p>
      </title>
      <p>Formula representation: water is H<sub>2</sub>O and relativity is E=mc<sup>2</sup>.</p>
      <p>Editorial revisions: <strikethrough>deprecated algorithm</strikethrough> replaced with modern approach.</p>
      <p>Source code snippet: <code>int factorial(int n) =&gt; n &lt;= 1 ? 1 : n * factorial(n - 1);</code> in Dart.</p>
      <empty-line/>
      <p>Inline icon <image l:href="#icon.png" id="inline-img-01" alt="Code Icon" title="Inline Programming Icon"/> illustrates syntax highlighting.</p>
    </section>
    <section>
      <title>
        <p>2. Complex Tables</p>
      </title>
      <table>
        <tr>
          <th colspan="2" align="center" valign="top"><p>Header spanning 2 columns</p></th>
          <th rowspan="2" align="right" valign="middle"><p>Side Header spanning 2 rows</p></th>
        </tr>
        <tr>
          <td align="left" valign="bottom"><p>Data Cell 1.1</p></td>
          <td align="justify"><p>Data Cell 1.2</p></td>
        </tr>
        <tr>
          <td><p>Data Cell 2.1</p></td>
          <td colspan="2"><p>Wide Bottom Cell</p></td>
        </tr>
      </table>
      <cite>
        <p>Science is what we understand well enough to explain to a computer.</p>
        <text-author>Donald Knuth</text-author>
      </cite>
      <image l:href="#diagram.png" id="block-img-01" alt="Architecture Diagram" title="Figure 1. System Architecture"/>
    </section>
  </body>
  <binary id="icon.png" content-type="image/png">iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==</binary>
  <binary id="diagram.png" content-type="image/png">iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==</binary>
</FictionBook>
''';

  final fb221Bytes = Uint8List.fromList(utf8.encode(fb221Xml));
  File('test/fixtures/fb2/fb2_21_sample.fb2').writeAsBytesSync(fb221Bytes);
  print('Wrote test/fixtures/fb2/fb2_21_sample.fb2 (\${fb221Bytes.length} bytes)');

  // 3. fb2_22_sample.fb2 (FB2 2.2 with style, custom-info, multiple body)
  final fb222Xml = '''<?xml version="1.0" encoding="UTF-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  <description>
    <title-info>
      <genre>sf</genre>
      <author>
        <first-name>Станислав</first-name>
        <last-name>Лем</last-name>
      </author>
      <book-title>FB2 2.2 Advanced Reference</book-title>
      <annotation>
        <p>Демонстрация расширенных возможностей FB2 2.2.</p>
      </annotation>
      <keywords>наука, кибернетика, будущее</keywords>
      <lang>ru</lang>
      <sequence name="Кибериада" number="7"/>
    </title-info>
    <document-info>
      <id>fb2-22-spec-reference-doc-002</id>
      <date value="2024-06-01">2024-06-01</date>
    </document-info>
    <custom-info info-type="sequence-url">https://cybernetics.example.org/series/cyberiada</custom-info>
    <custom-info info-type="editor-notes">Verified for FB2 2.2 schema compliance.</custom-info>
  </description>
  <body>
    <title>
      <p>Книга 1: Сказания роботов</p>
    </title>
    <section>
      <title>
        <p>Глава 1. Киберотические эксперименты</p>
      </title>
      <p>Текст с именованным стилем <style name="highlight">критически важный термин</style> и еще <style name="term">конструкт</style>.</p>
      <p>Смешанное форматирование: <strong>жирный и <style name="code-style">стилизованный код</style></strong> внутри абзаца.</p>
    </section>
  </body>
  <body name="commentary">
    <title>
      <p>Комментарии и дополнения</p>
    </title>
    <section>
      <title>
        <p>Комментарий к главе 1</p>
      </title>
      <p>Дополнительный анализ киберотических конструктов и кибернетических моделей.</p>
    </section>
  </body>
  <body name="notes">
    <title>
      <p>Сноски</p>
    </title>
    <section id="note_lem_1">
      <title>
        <p>1</p>
      </title>
      <p>Сноска к тексту Лема о природе разума.</p>
    </section>
  </body>
</FictionBook>
''';

  final fb222Bytes = Uint8List.fromList(utf8.encode(fb222Xml));
  File('test/fixtures/fb2/fb2_22_sample.fb2').writeAsBytesSync(fb222Bytes);
  print('Wrote test/fixtures/fb2/fb2_22_sample.fb2 (\${fb222Bytes.length} bytes)');

  // 4. calibre_sample.epub (EPUB 2 generated with calibre:series, toc.ncx, cover)
  final archive = Archive();

  // mimetype
  final mimetypeBytes = utf8.encode('application/epub+zip');
  archive.addFile(ArchiveFile.noCompress('mimetype', mimetypeBytes.length, mimetypeBytes));

  // META-INF/container.xml
  const containerXml = '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
  archive.addFile(ArchiveFile('META-INF/container.xml', containerXml.length, utf8.encode(containerXml)));

  // content.opf
  const opfXml = '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf" xmlns:calibre="http://calibre.kovidgoyal.net/2009/metadata">
    <dc:title>Calibre Sample Book</dc:title>
    <dc:creator opf:role="aut">Arthur Conan Doyle</dc:creator>
    <dc:language>en</dc:language>
    <dc:identifier id="BookId" opf:scheme="UUID">urn:uuid:calibre-sample-epub2-uuid-98765</dc:identifier>
    <dc:publisher>Calibre Library Publishing</dc:publisher>
    <dc:date>2023-11-20</dc:date>
    <dc:subject>Mystery</dc:subject>
    <dc:subject>Detective</dc:subject>
    <dc:description>A classic mystery novel exported via Calibre.</dc:description>
    <meta name="calibre:series" content="Sherlock Holmes Collection"/>
    <meta name="calibre:series_index" content="2"/>
    <meta name="cover" content="cover-img"/>
    <meta name="calibre:timestamp" content="2023-11-20T10:00:00+00:00"/>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="cover-img" href="images/cover.jpg" media-type="image/jpeg"/>
    <item id="cover-page" href="text/cover.xhtml" media-type="application/xhtml+xml"/>
    <item id="chap1" href="text/chap1.xhtml" media-type="application/xhtml+xml"/>
    <item id="chap2" href="text/chap2.xhtml" media-type="application/xhtml+xml"/>
    <item id="style" href="styles/stylesheet.css" media-type="text/css"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="cover-page"/>
    <itemref idref="chap1"/>
    <itemref idref="chap2"/>
  </spine>
  <guide>
    <reference type="cover" title="Cover" href="text/cover.xhtml"/>
  </guide>
</package>''';
  archive.addFile(ArchiveFile('content.opf', opfXml.length, utf8.encode(opfXml)));

  // toc.ncx
  const ncxXml = '''<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:uid" content="urn:uuid:calibre-sample-epub2-uuid-98765"/>
    <meta name="dtb:depth" content="2"/>
  </head>
  <docTitle>
    <text>Calibre Sample Book</text>
  </docTitle>
  <navMap>
    <navPoint id="np-1" playOrder="1">
      <navLabel><text>Cover</text></navLabel>
      <content src="text/cover.xhtml"/>
    </navPoint>
    <navPoint id="np-2" playOrder="2">
      <navLabel><text>Chapter 1: The Adventure Begins</text></navLabel>
      <content src="text/chap1.xhtml"/>
    </navPoint>
    <navPoint id="np-3" playOrder="3">
      <navLabel><text>Chapter 2: The Clues</text></navLabel>
      <content src="text/chap2.xhtml"/>
    </navPoint>
  </navMap>
</ncx>''';
  archive.addFile(ArchiveFile('toc.ncx', ncxXml.length, utf8.encode(ncxXml)));

  // text/cover.xhtml
  const coverXhtml = '''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>Cover</title>
    <link rel="stylesheet" href="../styles/stylesheet.css" type="text/css"/>
  </head>
  <body>
    <div class="cover-image">
      <img src="../images/cover.jpg" alt="Cover Image"/>
    </div>
  </body>
</html>''';
  archive.addFile(ArchiveFile('text/cover.xhtml', coverXhtml.length, utf8.encode(coverXhtml)));

  // text/chap1.xhtml
  const chap1Xhtml = '''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>Chapter 1: The Adventure Begins</title>
    <link rel="stylesheet" href="../styles/stylesheet.css" type="text/css"/>
  </head>
  <body>
    <h1>Chapter 1: The Adventure Begins</h1>
    <p>It was a cold and foggy morning in Baker Street.</p>
    <blockquote>
      <p>When you have eliminated the impossible, whatever remains, however improbable, must be the truth.</p>
    </blockquote>
  </body>
</html>''';
  archive.addFile(ArchiveFile('text/chap1.xhtml', chap1Xhtml.length, utf8.encode(chap1Xhtml)));

  // text/chap2.xhtml
  const chap2Xhtml = '''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>Chapter 2: The Clues</title>
    <link rel="stylesheet" href="../styles/stylesheet.css" type="text/css"/>
  </head>
  <body>
    <h1>Chapter 2: The Clues</h1>
    <p>Holmes examined the footprint carefully under the magnifying glass.</p>
    <ul>
      <li>First observation: muddy clay</li>
      <li>Second observation: left boot heel worn down</li>
    </ul>
  </body>
</html>''';
  archive.addFile(ArchiveFile('text/chap2.xhtml', chap2Xhtml.length, utf8.encode(chap2Xhtml)));

  // styles/stylesheet.css
  const css = 'body { font-family: serif; } h1 { color: #333; }';
  archive.addFile(ArchiveFile('styles/stylesheet.css', css.length, utf8.encode(css)));

  // images/cover.jpg
  final coverBytes = base64Decode('/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=');
  archive.addFile(ArchiveFile('images/cover.jpg', coverBytes.length, coverBytes));

  final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));
  File('test/fixtures/epub/calibre_sample.epub').writeAsBytesSync(zipBytes);
  print('Wrote test/fixtures/epub/calibre_sample.epub (\${zipBytes.length} bytes)');
}
