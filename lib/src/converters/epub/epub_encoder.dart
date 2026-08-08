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
          final idAttr = s.id != null && s.id!.isNotEmpty ? ' id="${s.id}"' : '';
          buffer.write('<section$idAttr>');
          if (s.title.isNotEmpty) {
            buffer.write('<h2>${_inlinesToXhtml(s.title)}</h2>');
          }
          buffer.write(_blocksToXhtml(s.blocks));
          buffer.write(_blocksToXhtml(s.children));
          buffer.write('</section>');
        case BookQuote q:
          buffer.write('<blockquote>');
          buffer.write(_blocksToXhtml(q.blocks));
          if (q.citation.isNotEmpty) {
            buffer.write('<p class="citation">${_inlinesToXhtml(q.citation)}</p>');
          }
          buffer.write('</blockquote>');
        case BookList l:
          final tag = l.ordered ? 'ol' : 'ul';
          buffer.write('<$tag>');
          for (final item in l.items) {
            buffer.write('<li>${_blocksToXhtml(item.blocks)}</li>');
          }
          buffer.write('</$tag>');
        case BookTable t:
          buffer.write('<table>');
          for (final row in t.rows) {
            buffer.write('<tr>');
            for (final cell in row.cells) {
              final colSpan = cell.colSpan != null ? ' colspan="${cell.colSpan}"' : '';
              final rowSpan = cell.rowSpan != null ? ' rowspan="${cell.rowSpan}"' : '';
              buffer.write('<td$colSpan$rowSpan>${_blocksToXhtml(cell.blocks)}</td>');
            }
            buffer.write('</tr>');
          }
          buffer.write('</table>');
        case BookPoem poem:
          buffer.write('<div class="poem">');
          for (final stanza in poem.stanzas) {
            buffer.write('<div class="stanza">');
            for (final line in stanza.lines) {
              buffer.write('<p class="poem-line">${_inlinesToXhtml(line.inlines)}</p>');
            }
            buffer.write('</div>');
          }
          buffer.write('</div>');
        case BookCodeBlock code:
          buffer.write('<pre><code>${_escapeHtml(code.code)}</code></pre>');
        case BookImageBlock img:
          buffer.write(
            '<img src="resources/${img.ref.id}" alt="${_escapeHtml(img.alt ?? '')}"/>',
          );
        case BookAudioBlock audio:
          buffer.write(
            '<audio src="resources/${audio.ref.id}"${audio.controls ? ' controls="controls"' : ''}></audio>',
          );
        case BookVideoBlock video:
          final posterAttr = video.posterRef != null ? ' poster="resources/${video.posterRef!.id}"' : '';
          buffer.write(
            '<video src="resources/${video.ref.id}"$posterAttr${video.controls ? ' controls="controls"' : ''}></video>',
          );
        case BookMathBlock math:
          buffer.write(math.mathml);
        case BookSvgBlock svg:
          buffer.write(svg.svg);
        case BookHorizontalRule():
          buffer.write('<hr/>');
        case BookEmptyLine():
          buffer.write('<br/>');
        case BookRawHtmlBlock rawHtml:
          buffer.write(rawHtml.html);
        case BookRawXmlBlock rawXml:
          buffer.write(rawXml.xml);
      }
    }
    return buffer.toString();
  }

  String _inlinesToXhtml(List<BookInline> inlines) {
    final buffer = StringBuffer();
    for (final inline in inlines) {
      switch (inline) {
        case BookText t:
          buffer.write(_escapeHtml(t.text));
        case BookLineBreak():
          buffer.write('<br/>');
        case BookStrong s:
          buffer.write('<strong>${_inlinesToXhtml(s.children)}</strong>');
        case BookEmphasis e:
          buffer.write('<em>${_inlinesToXhtml(e.children)}</em>');
        case BookStrike st:
          buffer.write('<s>${_inlinesToXhtml(st.children)}</s>');
        case BookCodeSpan cs:
          buffer.write('<code>${_escapeHtml(cs.code)}</code>');
        case BookLink l:
          buffer.write(
            '<a href="${l.href}">${_inlinesToXhtml(l.children)}</a>',
          );
        case BookAnchor a:
          buffer.write('<a id="${a.id}"></a>');
        case BookImageInline img:
          buffer.write(
            '<img src="resources/${img.ref.id}" alt="${_escapeHtml(img.alt ?? '')}"/>',
          );
        case BookSuperscript sup:
          buffer.write('<sup>${_inlinesToXhtml(sup.children)}</sup>');
        case BookSubscript sub:
          buffer.write('<sub>${_inlinesToXhtml(sub.children)}</sub>');
        case BookFootnoteRef fn:
          buffer.write(
            '<a href="#${fn.id}" class="footnote-ref">${fn.label.isNotEmpty ? _inlinesToXhtml(fn.label) : '[${fn.id}]'}</a>',
          );
        case BookRawHtmlInline rawHtml:
          buffer.write(rawHtml.html);
        case BookRawXmlInline rawXml:
          buffer.write(rawXml.xml);
      }
    }
    return buffer.toString();
  }

  String _escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
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
