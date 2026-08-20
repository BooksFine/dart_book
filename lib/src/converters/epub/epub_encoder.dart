import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:dart_book/dart_book.dart';

class EpubEncoder implements BookEncoder {
  @override
  bool canEncode(String extension) => extension.toLowerCase() == 'epub';

  @override
  Uint8List encode(Book book, {BookEncodingOptions? options}) {
    final ctx = _EpubContext(book, options);
    final archive = Archive();

    // 1. mimetype (must be first and uncompressed)
    final mimetypeBytes = utf8.encode('application/epub+zip');
    archive.addFile(
      ArchiveFile.noCompress(
        'mimetype',
        mimetypeBytes.length,
        mimetypeBytes,
      ),
    );

    // 2. META-INF/container.xml
    const containerXml = '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
    _addStringFile(archive, 'META-INF/container.xml', containerXml);

    // 3. Chapters
    final manifestItems = <String>[];
    final spineItems = <String>[];
    final chapters = _buildChapters(book, ctx);

    for (final chapter in chapters) {
      final xhtml = _wrapXhtml(chapter.title, chapter.content);
      _addStringFile(archive, 'OEBPS/${chapter.href}', xhtml);
      manifestItems.add(
        '<item id="${chapter.id}" href="${chapter.href}" media-type="application/xhtml+xml"/>',
      );
      spineItems.add('<itemref idref="${chapter.id}"/>');
    }

    // 4. Resources (Images)
    final coverRawId = book.metadata.cover?.ref.id;
    for (final res in book.resources) {
      final isCover = coverRawId != null && coverRawId == res.id;
      final cleanId = ctx.getId(res.id, isCover: isCover);
      final href = 'resources/$cleanId';
      final isImage = res.mediaType.startsWith('image/') ||
          res.mediaType.startsWith('font/') ||
          res.mediaType.contains('audio/') ||
          res.mediaType.contains('video/');
      if (isImage) {
        archive.addFile(ArchiveFile.noCompress('OEBPS/$href', res.bytes.length, res.bytes));
      } else {
        archive.addFile(ArchiveFile('OEBPS/$href', res.bytes.length, res.bytes));
      }

      final coverProperty = isCover ? ' properties="cover-image"' : '';
      manifestItems.add(
        '<item id="$cleanId" href="$href" media-type="${res.mediaType}"$coverProperty/>',
      );
    }

    // 5. content.opf
    final opfXml = _generateOpf(book, manifestItems, spineItems, options: options);
    _addStringFile(archive, 'OEBPS/content.opf', opfXml);

    // 6. navigation (nav.xhtml and toc.ncx for dual EPUB 2/3 compatibility)
    final navXhtml = _generateNav(book, chapters);
    _addStringFile(archive, 'OEBPS/nav.xhtml', navXhtml);

    final ncxXml = _generateNcx(book, chapters, options: options);
    _addStringFile(archive, 'OEBPS/toc.ncx', ncxXml);

    final bytes = ZipEncoder().encode(archive);
    return Uint8List.fromList(bytes);
  }

  void _addStringFile(Archive archive, String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  List<_ChapterData> _buildChapters(Book book, _EpubContext ctx) {
    final chapters = <_ChapterData>[];
    final looseBlocks = <BookBlock>[];
    var sectionIndex = 1;

    void flushLooseBlocks() {
      if (looseBlocks.isEmpty) return;
      final id = 'chapter_$sectionIndex';
      final href = 'chapter_$sectionIndex.xhtml';
      final content = _blocksToXhtml(looseBlocks, ctx);
      chapters.add(_ChapterData(id, href, 'Часть $sectionIndex', content));
      looseBlocks.clear();
      sectionIndex++;
    }

    for (final block in book.content.blocks) {
      if (block is BookSection) {
        flushLooseBlocks();
        final id = 'chapter_$sectionIndex';
        final href = 'chapter_$sectionIndex.xhtml';
        final title = block.title.isNotEmpty
            ? _inlinesToText(block.title)
            : 'Глава $sectionIndex';

        final content = _blocksToXhtml([block], ctx);
        chapters.add(_ChapterData(id, href, title, content));
        sectionIndex++;
      } else {
        looseBlocks.add(block);
      }
    }

    flushLooseBlocks();

    if (chapters.isEmpty) {
      chapters.add(
        _ChapterData(
          'main',
          'main.xhtml',
          book.metadata.title,
          _blocksToXhtml(book.content.blocks, ctx),
        ),
      );
    }

    return chapters;
  }

  String _generateOpf(
    Book book,
    List<String> items,
    List<String> spine, {
    BookEncodingOptions? options,
  }) {
    final metadata = book.metadata;
    final authors = metadata.contributorsByRole(BookContributorRole.author);

    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
      '<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="pub-id" version="3.0">',
    );
    buffer.writeln('  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">');
    final docId = options?.documentId ?? book.metadata.id;
    buffer.writeln('    <dc:identifier id="pub-id">$docId</dc:identifier>');
    if (metadata.publishInfo?.isbn != null) {
      buffer.writeln('    <dc:identifier id="pub-isbn">urn:isbn:${_escapeHtml(metadata.publishInfo!.isbn!)}</dc:identifier>');
    }
    buffer.writeln('    <dc:title>${_escapeHtml(metadata.title)}</dc:title>');
    buffer.writeln('    <dc:language>${metadata.language}</dc:language>');
    for (final author in authors) {
      buffer.writeln(
        '    <dc:creator>${_escapeHtml(author.name.toDisplayString())}</dc:creator>',
      );
    }
    if (metadata.publishInfo?.publisher != null) {
      buffer.writeln('    <dc:publisher>${_escapeHtml(metadata.publishInfo!.publisher!)}</dc:publisher>');
    }
    if (metadata.publishedAt != null) {
      buffer.writeln('    <dc:date>${metadata.publishedAt!.toIso8601String().split('T').first}</dc:date>');
    }
    if (metadata.srcTitleInfo?.title != null) {
      buffer.writeln('    <dc:source>${_escapeHtml(metadata.srcTitleInfo!.title!)}</dc:source>');
    } else if (metadata.source != null) {
      buffer.writeln('    <dc:source>${_escapeHtml(metadata.source.toString())}</dc:source>');
    }
    if (metadata.srcLang != null) {
      buffer.writeln('    <meta property="source-language">${_escapeHtml(metadata.srcLang!)}</meta>');
    }

    var seriesIdx = 1;
    for (final series in metadata.series) {
      final collectionId = 'series-$seriesIdx';
      buffer.writeln('    <meta property="belongs-to-collection" id="$collectionId">${_escapeHtml(series.name)}</meta>');
      buffer.writeln('    <meta refines="#$collectionId" property="collection-type">series</meta>');
      if (series.number != null) {
        buffer.writeln('    <meta refines="#$collectionId" property="group-position">${series.number}</meta>');
      }
      seriesIdx++;
    }

    if (metadata.layout == BookLayout.fixedLayout) {
      buffer.writeln('    <meta property="rendition:layout">pre-paginated</meta>');
    } else if (metadata.layout == BookLayout.roll) {
      buffer.writeln('    <meta property="rendition:layout">roll</meta>');
    }

    if (options?.programUsed != null) {
      buffer.writeln('    <meta name="generator" content="${_escapeHtml(options!.programUsed!)}"/>');
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
      '    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>',
    );
    buffer.writeln(
      '    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>',
    );
    buffer.writeln('  </manifest>');
    buffer.writeln('  <spine toc="ncx">');
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
        '      <li><a href="${chapter.href}">${_escapeHtml(chapter.title)}</a></li>',
      );
    }
    buffer.writeln('    </ol>');
    buffer.writeln('  </nav>');
    buffer.writeln('</body>');
    buffer.writeln('</html>');
    return buffer.toString();
  }

  String _generateNcx(Book book, List<_ChapterData> chapters, {BookEncodingOptions? options}) {
    final docId = options?.documentId ?? book.metadata.id;
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">');
    buffer.writeln('  <head>');
    buffer.writeln('    <meta name="dtb:uid" content="${_escapeHtml(docId)}"/>');
    buffer.writeln('    <meta name="dtb:depth" content="1"/>');
    buffer.writeln('    <meta name="dtb:totalPageCount" content="0"/>');
    buffer.writeln('    <meta name="dtb:maxPageNumber" content="0"/>');
    buffer.writeln('  </head>');
    buffer.writeln('  <docTitle>');
    buffer.writeln('    <text>${_escapeHtml(book.metadata.title)}</text>');
    buffer.writeln('  </docTitle>');
    buffer.writeln('  <navMap>');
    var playOrder = 1;
    for (final chapter in chapters) {
      buffer.writeln('    <navPoint id="navpoint-$playOrder" playOrder="$playOrder">');
      buffer.writeln('      <navLabel>');
      buffer.writeln('        <text>${_escapeHtml(chapter.title)}</text>');
      buffer.writeln('      </navLabel>');
      buffer.writeln('      <content src="${chapter.href}"/>');
      buffer.writeln('    </navPoint>');
      playOrder++;
    }
    buffer.writeln('  </navMap>');
    buffer.writeln('</ncx>');
    return buffer.toString();
  }

  String _wrapXhtml(String title, String content) {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>${_escapeHtml(title)}</title>
  </head>
  <body>
    $content
  </body>
</html>''';
  }

  String _blocksToXhtml(List<BookBlock> blocks, _EpubContext ctx) {
    final buffer = StringBuffer();
    for (final block in blocks) {
      switch (block) {
        case BookParagraph p:
          buffer.write('<p>${_inlinesToXhtml(p.inlines, ctx)}</p>');
        case BookHeading h:
          buffer.write('<h${h.level}>${_inlinesToXhtml(h.text, ctx)}</h${h.level}>');
        case BookSection s:
          final idAttr = s.id != null && s.id!.isNotEmpty ? ' id="${s.id}"' : '';
          buffer.write('<section$idAttr>');
          if (s.title.isNotEmpty) {
            buffer.write('<h2>${_inlinesToXhtml(s.title, ctx)}</h2>');
          }
          buffer.write(_blocksToXhtml(s.blocks, ctx));
          buffer.write(_blocksToXhtml(s.children, ctx));
          buffer.write('</section>');
        case BookQuote q:
          buffer.write('<blockquote>');
          buffer.write(_blocksToXhtml(q.blocks, ctx));
          if (q.citation.isNotEmpty) {
            buffer.write('<p class="citation">${_inlinesToXhtml(q.citation, ctx)}</p>');
          }
          buffer.write('</blockquote>');
        case BookList l:
          final tag = l.ordered ? 'ol' : 'ul';
          buffer.write('<$tag>');
          for (final item in l.items) {
            buffer.write('<li>${_blocksToXhtml(item.blocks, ctx)}</li>');
          }
          buffer.write('</$tag>');
        case BookTable t:
          buffer.write('<table>');
          for (final row in t.rows) {
            buffer.write('<tr>');
            for (final cell in row.cells) {
              final colSpan = cell.colSpan != null ? ' colspan="${cell.colSpan}"' : '';
              final rowSpan = cell.rowSpan != null ? ' rowspan="${cell.rowSpan}"' : '';
              final styles = <String>[
                if (cell.align != null) 'text-align: ${cell.align}',
                if (cell.vAlign != null) 'vertical-align: ${cell.vAlign}',
              ];
              final styleAttr = styles.isNotEmpty ? ' style="${styles.join('; ')}"' : '';
              buffer.write('<td$colSpan$rowSpan$styleAttr>${_blocksToXhtml(cell.blocks, ctx)}</td>');
            }
            buffer.write('</tr>');
          }
          buffer.write('</table>');
        case BookPoem poem:
          buffer.write('<div class="poem">');
          for (final stanza in poem.stanzas) {
            buffer.write('<div class="stanza">');
            for (final line in stanza.lines) {
              buffer.write('<p class="poem-line">${_inlinesToXhtml(line.inlines, ctx)}</p>');
            }
            buffer.write('</div>');
          }
          buffer.write('</div>');
        case BookCodeBlock code:
          buffer.write('<pre><code>${_escapeHtml(code.code)}</code></pre>');
        case BookImageBlock img:
          final cleanId = ctx.getId(img.ref.id, isCover: false);
          final idAttr = img.id != null ? ' id="${_escapeHtml(img.id!)}"' : '';
          final titleAttr = img.title != null ? ' title="${_escapeHtml(img.title!)}"' : '';
          buffer.write(
            '<img$idAttr src="resources/$cleanId" alt="${_escapeHtml(img.alt ?? '')}"$titleAttr/>',
          );
        case BookAudioBlock audio:
          final cleanId = ctx.getId(audio.ref.id, isCover: false);
          buffer.write(
            '<audio src="resources/$cleanId"${audio.controls ? ' controls="controls"' : ''}></audio>',
          );
        case BookVideoBlock video:
          final cleanId = ctx.getId(video.ref.id, isCover: false);
          final posterId = video.posterRef != null ? ctx.getId(video.posterRef!.id, isCover: false) : null;
          final posterAttr = posterId != null ? ' poster="resources/$posterId"' : '';
          buffer.write(
            '<video src="resources/$cleanId"$posterAttr${video.controls ? ' controls="controls"' : ''}></video>',
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

  String _inlinesToXhtml(List<BookInline> inlines, _EpubContext ctx) {
    final buffer = StringBuffer();
    for (final inline in inlines) {
      switch (inline) {
        case BookText t:
          buffer.write(_escapeHtml(t.text));
        case BookLineBreak():
          buffer.write('<br/>');
        case BookStrong s:
          buffer.write('<strong>${_inlinesToXhtml(s.children, ctx)}</strong>');
        case BookEmphasis e:
          buffer.write('<em>${_inlinesToXhtml(e.children, ctx)}</em>');
        case BookStrike st:
          buffer.write('<s>${_inlinesToXhtml(st.children, ctx)}</s>');
        case BookCodeSpan cs:
          buffer.write('<code>${_escapeHtml(cs.code)}</code>');
        case BookNamedStyle style:
          buffer.write('<span class="style-${_escapeHtml(style.name)}">${_inlinesToXhtml(style.inlines, ctx)}</span>');
        case BookLink l:
          buffer.write(
            '<a href="${l.href}">${_inlinesToXhtml(l.children, ctx)}</a>',
          );
        case BookAnchor a:
          buffer.write('<a id="${a.id}"></a>');
        case BookImageInline img:
          final cleanId = ctx.getId(img.ref.id, isCover: false);
          final idAttr = img.id != null ? ' id="${_escapeHtml(img.id!)}"' : '';
          final titleAttr = img.title != null ? ' title="${_escapeHtml(img.title!)}"' : '';
          buffer.write(
            '<img$idAttr src="resources/$cleanId" alt="${_escapeHtml(img.alt ?? '')}"$titleAttr/>',
          );
        case BookSuperscript sup:
          buffer.write('<sup>${_inlinesToXhtml(sup.children, ctx)}</sup>');
        case BookSubscript sub:
          buffer.write('<sub>${_inlinesToXhtml(sub.children, ctx)}</sub>');
        case BookFootnoteRef fn:
          buffer.write(
            '<a href="#${fn.id}" class="footnote-ref" epub:type="noteref" role="doc-noteref">${fn.label.isNotEmpty ? _inlinesToXhtml(fn.label, ctx) : '[${fn.id}]'}</a>',
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
    final buffer = StringBuffer();
    for (final inline in inlines) {
      switch (inline) {
        case BookText t:
          buffer.write(t.text);
        case BookStrong s:
          buffer.write(_inlinesToText(s.children));
        case BookEmphasis e:
          buffer.write(_inlinesToText(e.children));
        case BookStrike st:
          buffer.write(_inlinesToText(st.children));
        case BookLink l:
          buffer.write(_inlinesToText(l.children));
        case BookSuperscript sup:
          buffer.write(_inlinesToText(sup.children));
        case BookSubscript sub:
          buffer.write(_inlinesToText(sub.children));
        default:
          break;
      }
    }
    return buffer.toString();
  }
}

class _EpubContext {
  final Book book;
  final BookEncodingOptions? options;
  final Map<String, String> _cache = {};
  int _imageCounter = 0;

  _EpubContext(this.book, this.options);

  String getId(String src, {required bool isCover}) {
    if (_cache.containsKey(src)) return _cache[src]!;

    BookResource? res;
    for (final r in book.resources) {
      if (r.id == src) {
        res = r;
        break;
      }
    }

    final ext = _extensionForMedia(res?.mediaType ?? '', src);
    final String cleanId;
    if (isCover) {
      final name = options?.coverFilename ?? 'cover';
      cleanId = name.contains('.') ? name : '$name.$ext';
    } else {
      final policy = options?.namingPolicy ?? BookResourceNamingPolicy.preserve;
      final generated = policy.generateName(src, isInline: false, index: ++_imageCounter);
      if (generated.contains('.')) {
        final origHasExt = src.split('?').first.split('#').first.contains('.');
        if (!origHasExt && res?.mediaType != null && res!.mediaType.isNotEmpty) {
          final baseName = generated.substring(0, generated.lastIndexOf('.'));
          cleanId = '$baseName.$ext';
        } else {
          cleanId = generated;
        }
      } else {
        cleanId = '$generated.$ext';
      }
    }

    _cache[src] = cleanId;
    return cleanId;
  }
}

String _extensionForMedia(String mediaType, String src) {
  final mt = mediaType.toLowerCase();
  if (mt.contains('jpeg') || mt.contains('jpg')) return 'jpg';
  if (mt.contains('png')) return 'png';
  if (mt.contains('webp')) return 'webp';
  if (mt.contains('avif')) return 'avif';
  if (mt.contains('jxl')) return 'jxl';
  if (mt.contains('gif')) return 'gif';
  if (mt.contains('svg')) return 'svg';
  if (mt.contains('woff2')) return 'woff2';
  if (mt.contains('woff')) return 'woff';
  if (mt.contains('ttf')) return 'ttf';
  if (mt.contains('otf') || mt.contains('opentype')) return 'otf';
  if (mt.contains('mp3') || mt.contains('mpeg')) return 'mp3';
  if (mt.contains('mp4')) return 'mp4';
  if (mt.contains('opus') || mt.contains('ogg')) return 'opus';

  final clean = src.split('?').first.split('#').first;
  if (clean.contains('.')) {
    final ext = clean.split('.').last.toLowerCase();
    if (ext.length <= 5 && RegExp(r'^[a-z0-9]+$').hasMatch(ext)) {
      return ext;
    }
  }
  return 'jpg';
}

class _ChapterData {
  final String id;
  final String href;
  final String title;
  final String content;

  _ChapterData(this.id, this.href, this.title, this.content);
}
