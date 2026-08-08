import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:dart_book/dart_book.dart';

class EpubEncoder implements BookEncoder {
  @override
  bool canEncode(String extension) => extension.toLowerCase() == 'epub';

  @override
  Uint8List encode(Book book) {
    final archive = Archive();

    // 1. mimetype (must be first and uncompressed)
    archive.addFile(
      ArchiveFile.noCompress(
        'mimetype',
        20,
        utf8.encode('application/epub+zip'),
      ),
    );

    // 2. META-INF/container.xml
    const containerXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
''';
    archive.addFile(
      ArchiveFile(
        'META-INF/container.xml',
        containerXml.length,
        utf8.encode(containerXml),
      ),
    );

    // 3. Chapters & Resources
    final manifestItems = <String>[];
    final spineItems = <String>[];

    final chapters = <_ChapterData>[];
    if (book.content.blocks.any((b) => b is BookSection)) {
      var i = 1;
      for (final block in book.content.blocks) {
        if (block is BookSection) {
          final id = 'chapter_$i';
          final href = 'chapter_$i.xhtml';
          final title = block.title.isNotEmpty
              ? _inlinesToText(block.title)
              : 'Chapter $i';
          chapters.add(_ChapterData(id, href, title, _blocksToXhtml([block])));
          i++;
        }
      }
    }

    if (chapters.isEmpty) {
      chapters.add(
        _ChapterData(
          'main',
          'main.xhtml',
          book.metadata.title,
          _blocksToXhtml(book.content.blocks),
        ),
      );
    }

    for (final chapter in chapters) {
      final xhtml = _wrapXhtml(chapter.title, chapter.content);
      archive.addFile(
        ArchiveFile('OEBPS/${chapter.href}', xhtml.length, utf8.encode(xhtml)),
      );
      manifestItems.add(
        '<item id="${chapter.id}" href="${chapter.href}" media-type="application/xhtml+xml"/>',
      );
      spineItems.add('<itemref idref="${chapter.id}"/>');
    }

    for (final res in book.resources) {
      final href = 'resources/${res.id}';
      archive.addFile(ArchiveFile('OEBPS/$href', res.bytes.length, res.bytes));
      manifestItems.add(
        '<item id="${res.id}" href="$href" media-type="${res.mediaType}"/>',
      );
    }

    // 4. content.opf
    final opfXml = _generateOpf(book, manifestItems, spineItems);
    archive.addFile(
      ArchiveFile('OEBPS/content.opf', opfXml.length, utf8.encode(opfXml)),
    );

    // 5. navigation
    final navXhtml = _generateNav(book, chapters);
    archive.addFile(
      ArchiveFile('OEBPS/nav.xhtml', navXhtml.length, utf8.encode(navXhtml)),
    );

    final bytes = ZipEncoder().encode(archive);
    return Uint8List.fromList(bytes);
  }

  String _generateOpf(Book book, List<String> items, List<String> spine) {
    final metadata = book.metadata;
    final authors = metadata.contributorsByRole(BookContributorRole.author);

    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
      '<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="pub-id" version="3.0">',
    );
    buffer.writeln('  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">');
    buffer.writeln('    <dc:identifier id="pub-id">${book.id}</dc:identifier>');
    buffer.writeln('    <dc:title>${metadata.title}</dc:title>');
    buffer.writeln('    <dc:language>${metadata.language}</dc:language>');
    for (final author in authors) {
      buffer.writeln(
        '    <dc:creator>${author.name.toDisplayString()}</dc:creator>',
      );
    }
    buffer.writeln(
      '    <meta property="dcterms:modified">${DateTime.now().toIso8601String().split('.').first}Z</meta>',
    );
    buffer.writeln('  </metadata>');
    buffer.writeln('  <manifest>');
    for (final item in items) {
      buffer.writeln('    $item');
    }
    buffer.writeln(
      '    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>',
    );
    buffer.writeln('  </manifest>');
    buffer.writeln('  <spine>');
    for (final item in spine) {
      buffer.writeln('    $item');
    }
    buffer.writeln('  </spine>');
    buffer.writeln('</package>');
    return buffer.toString();
  }

  String _generateNav(Book book, List<_ChapterData> chapters) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
      '<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">',
    );
    buffer.writeln('<head><title>Navigation</title></head>');
    buffer.writeln('<body>');
    buffer.writeln('  <nav epub:type="toc" id="toc">');
    buffer.writeln('    <h1>Table of Contents</h1>');
    buffer.writeln('    <ol>');
    for (final chapter in chapters) {
      buffer.writeln(
        '      <li><a href="${chapter.href}">${chapter.title}</a></li>',
      );
    }
    buffer.writeln('    </ol>');
    buffer.writeln('  </nav>');
    buffer.writeln('</body>');
    buffer.writeln('</html>');
    return buffer.toString();
  }

  String _wrapXhtml(String title, String content) {
    return '''
<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>$title</title>
  </head>
  <body>
    $content
  </body>
</html>
''';
  }

  String _blocksToXhtml(List<BookBlock> blocks) {
    final buffer = StringBuffer();
    for (final block in blocks) {
      switch (block) {
        case BookParagraph p:
          buffer.write('<p>${_inlinesToXhtml(p.inlines)}</p>');
        case BookHeading h:
          buffer.write('<h${h.level}>${_inlinesToXhtml(h.text)}</h${h.level}>');
        case BookSection s:
          if (s.title.isNotEmpty) {
            buffer.write('<h2>${_inlinesToXhtml(s.title)}</h2>');
          }
          buffer.write(_blocksToXhtml(s.blocks));
          buffer.write(_blocksToXhtml(s.children));
        case BookImageBlock img:
          buffer.write(
            '<img src="resources/${img.ref.id}" alt="${img.alt ?? ''}"/>',
          );
        default:
          buffer.write('<div class="block"></div>');
      }
    }
    return buffer.toString();
  }

  String _inlinesToXhtml(List<BookInline> inlines) {
    final buffer = StringBuffer();
    for (final inline in inlines) {
      switch (inline) {
        case BookText t:
          buffer.write(t.text);
        case BookStrong s:
          buffer.write('<strong>${_inlinesToXhtml(s.children)}</strong>');
        case BookEmphasis e:
          buffer.write('<em>${_inlinesToXhtml(e.children)}</em>');
        case BookLink l:
          buffer.write(
            '<a href="${l.href}">${_inlinesToXhtml(l.children)}</a>',
          );
        default:
          break;
      }
    }
    return buffer.toString();
  }

  String _inlinesToText(List<BookInline> inlines) {
    return inlines.map((i) => i is BookText ? i.text : '').join();
  }
}

class _ChapterData {
  final String id;
  final String href;
  final String title;
  final String content;

  _ChapterData(this.id, this.href, this.title, this.content);
}
