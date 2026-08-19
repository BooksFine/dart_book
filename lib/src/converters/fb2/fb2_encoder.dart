import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_book/dart_book.dart';

class Fb2Encoder implements BookEncoder {
  final String programUsed;

  const Fb2Encoder({this.programUsed = 'Re: UCM'});

  @override
  bool canEncode(String extension) {
    final ext = extension.toLowerCase();
    return ext == 'fb2' || ext == 'xml';
  }

  @override
  FutureOr<Uint8List> encode(
    Book book, {
    BookEncodingOptions? options,
    bool pretty = true,
    BookResourceResolver? resourceResolver,
  }) {
    final effectivePretty = options?.pretty ?? pretty;
    if (resourceResolver != null) {
      return _encodeAsync(book, options, effectivePretty, resourceResolver);
    }
    final xml = _buildXml(book, options: options, pretty: effectivePretty);
    return Uint8List.fromList(utf8.encode(xml));
  }

  Future<Uint8List> _encodeAsync(
    Book book,
    BookEncodingOptions? options,
    bool pretty,
    BookResourceResolver resourceResolver,
  ) async {
    final resolvedBook = await book.resolveResources(
      resourceResolver,
      baseUri: book.metadata.source,
    );
    final xml = _buildXml(resolvedBook, options: options, pretty: pretty);
    return Uint8List.fromList(utf8.encode(xml));
  }

  String _buildXml(Book book, {BookEncodingOptions? options, bool pretty = true}) {
    final ctx = _Fb2Context(book, options);
    final writer = _Fb2XmlWriter(pretty: pretty);

    writer.processing('xml', 'version="1.0" encoding="utf-8"');
    writer.openElement(
      'FictionBook',
      attributes: {
        'xmlns': 'http://www.gribuser.ru/xml/fictionbook/2.0',
        'xmlns:l': 'http://www.w3.org/1999/xlink',
      },
    );

    _buildDescription(writer, ctx);
    _buildMainBody(writer, ctx);
    _buildNotesBody(writer, ctx);
    _buildBinaries(writer, ctx);

    writer.closeElement('FictionBook');
    return writer.toString();
  }

  void _buildDescription(_Fb2XmlWriter writer, _Fb2Context ctx) {
    final metadata = ctx.book.metadata;

    writer.openElement('description');
    writer.openElement('title-info');

    for (final genre in metadata.genres) {
      writer.element('genre', text: genre.code, inline: true);
    }

    final authors = metadata.contributorsByRole(BookContributorRole.author);
    for (final author in authors) {
      writer.openElement('author');
      final name = author.name;
      if (name.first?.trim().isNotEmpty == true) {
        writer.element('first-name', text: name.first!.trim());
      }
      if (name.middle?.trim().isNotEmpty == true) {
        writer.element('middle-name', text: name.middle!.trim());
      }
      if (name.last?.trim().isNotEmpty == true) {
        writer.element('last-name', text: name.last!.trim());
      }
      if (name.nickname?.trim().isNotEmpty == true) {
        writer.element('nickname', text: name.nickname!.trim());
      }
      if (author.homePage != null) {
        writer.element('home-page', text: author.homePage.toString());
      }
      if (author.email != null && author.email!.trim().isNotEmpty) {
        writer.element('email', text: author.email!.trim());
      }
      writer.closeElement('author');
    }

    writer.element('book-title', text: metadata.title, inline: true);
    writer.element('lang', text: metadata.language, inline: true);

    if (metadata.annotation != null) {
      writer.openElement('annotation');
      _writeBlocks(writer, metadata.annotation!.blocks, ctx);
      writer.closeElement('annotation');
    }

    if (metadata.keywords.isNotEmpty) {
      writer.element('keywords', text: metadata.keywords.join(', '), inline: true);
    }

    if (metadata.updatedAt != null) {
      writer.element(
        'date',
        attributes: {'value': _formatDate(metadata.updatedAt!)},
        text: _formatDate(metadata.updatedAt!),
        inline: true,
      );
    } else if (metadata.publishedAt != null) {
      writer.element(
        'date',
        attributes: {'value': _formatDate(metadata.publishedAt!)},
        text: _formatDate(metadata.publishedAt!),
        inline: true,
      );
    }

    if (metadata.series != null) {
      final series = metadata.series!;
      final attributes = <String, String>{'name': series.name};
      if (series.number != null) {
        attributes['number'] = series.number.toString();
      }
      writer.element('sequence', attributes: attributes);
    }

    if (metadata.cover != null) {
      final cleanId = ctx.getId(metadata.cover!.ref.id, isCover: true);
      writer.openElement('coverpage');
      writer.element('image', attributes: {'l:href': '#$cleanId'});
      writer.closeElement('coverpage');
    }

    writer.closeElement('title-info');

    writer.openElement('document-info');
    final docId = ctx.options?.documentId ?? metadata.id;
    writer.element('id', text: docId, inline: true);
    writer.element('version', text: '1.0', inline: true);
    writer.element(
      'date',
      attributes: {'value': _formatDate(DateTime.now())},
      text: _formatDate(DateTime.now()),
      inline: true,
    );
    if (metadata.source != null) {
      writer.element('src-url', text: metadata.source.toString(), inline: true);
    }
    final prog = ctx.options?.programUsed ?? programUsed;
    writer.element('program-used', text: prog, inline: true);
    writer.closeElement('document-info');

    if (metadata.series?.url != null) {
      writer.element(
        'custom-info',
        attributes: {'info-type': 'sequence-url'},
        text: metadata.series!.url.toString(),
        inline: true,
      );
    }

    writer.closeElement('description');
  }

  void _buildMainBody(_Fb2XmlWriter writer, _Fb2Context ctx) {
    writer.openElement('body');
    writer.openElement('title');
    writer.element('p', text: ctx.book.metadata.title, inline: true);
    writer.closeElement('title');
    _writeBlocks(writer, ctx.book.content.blocks, ctx);
    writer.closeElement('body');
  }

  void _buildNotesBody(_Fb2XmlWriter writer, _Fb2Context ctx) {
    if (ctx.book.content.footnotes.isEmpty) return;

    writer.openElement('body', attributes: {'name': 'notes'});
    for (final footnote in ctx.book.content.footnotes) {
      writer.openElement('section', attributes: {'id': footnote.id});
      writer.openElement('title');
      writer.element('p', text: footnote.id, inline: true);
      writer.closeElement('title');
      _writeBlocks(writer, footnote.blocks, ctx);
      writer.closeElement('section');
    }
    writer.closeElement('body');
  }

  void _buildBinaries(_Fb2XmlWriter writer, _Fb2Context ctx) {
    for (final resource in ctx.book.resources) {
      final isCover = ctx.book.metadata.cover?.ref.id == resource.id;
      final cleanId = ctx.getId(resource.id, isCover: isCover);
      writer.binaryElement(cleanId, resource.mediaType, resource.bytes);
    }
  }

  void _writeBlocks(_Fb2XmlWriter writer, List<BookBlock> blocks, _Fb2Context ctx) {
    for (final block in blocks) {
      switch (block) {
        case BookSection section:
          writer.openElement('section', attributes: _idAttribute(section.id));
          if (section.title.isNotEmpty) {
            writer.openElement('title');
            writer.openElement('p', inline: true);
            _writeInlines(writer, section.title, ctx);
            writer.closeElement('p', inline: true);
            writer.closeElement('title');
          }
          _writeBlocks(writer, section.blocks, ctx);
          _writeBlocks(writer, section.children, ctx);
          writer.closeElement('section');

        case BookHeading heading:
          writer.openElement('subtitle', inline: true);
          _writeInlines(writer, heading.text, ctx);
          writer.closeElement('subtitle', inline: true);

        case BookParagraph paragraph:
          writer.openElement('p', inline: true);
          _writeInlines(writer, paragraph.inlines, ctx);
          writer.closeElement('p', inline: true);

        case BookQuote quote:
          writer.openElement('cite');
          _writeBlocks(writer, quote.blocks, ctx);
          if (quote.citation.isNotEmpty) {
            writer.openElement('text-author', inline: true);
            _writeInlines(writer, quote.citation, ctx);
            writer.closeElement('text-author', inline: true);
          }
          writer.closeElement('cite');

        case BookList list:
          var index = 1;
          for (final item in list.items) {
            for (final itemBlock in item.blocks) {
              switch (itemBlock) {
                case BookParagraph paragraph:
                  writer.openElement('p', inline: true);
                  final prefix = list.ordered ? '${index++}. ' : '• ';
                  writer.text(prefix);
                  _writeInlines(writer, paragraph.inlines, ctx);
                  writer.closeElement('p', inline: true);
                default:
                  _writeBlocks(writer, [itemBlock], ctx);
              }
            }
          }

        case BookTable table:
          writer.openElement('table');
          for (final row in table.rows) {
            writer.openElement('tr');
            for (final cell in row.cells) {
              writer.openElement('td');
              _writeBlocks(writer, cell.blocks, ctx);
              writer.closeElement('td');
            }
            writer.closeElement('tr');
          }
          writer.closeElement('table');

        case BookPoem poem:
          writer.openElement('poem');
          for (final stanza in poem.stanzas) {
            writer.openElement('stanza');
            for (final line in stanza.lines) {
              writer.openElement('v', inline: true);
              _writeInlines(writer, line.inlines, ctx);
              writer.closeElement('v', inline: true);
            }
            writer.closeElement('stanza');
          }
          writer.closeElement('poem');

        case BookImageBlock image:
          final cleanId = ctx.getId(image.ref.id, isCover: false);
          writer.element('image', attributes: {'l:href': '#$cleanId'});

        case BookAudioBlock audio:
          writer.element('p', text: '[Audio: ${audio.ref.id}]', inline: true);

        case BookVideoBlock video:
          writer.element('p', text: '[Video: ${video.ref.id}]', inline: true);

        case BookMathBlock math:
          writer.element('p', text: _stripTags(math.mathml), inline: true);

        case BookSvgBlock():
          writer.element('p', text: '[SVG Graphic]', inline: true);

        case BookHorizontalRule() || BookEmptyLine():
          writer.element('empty-line');

        case BookCodeBlock code:
          for (final line in const LineSplitter().convert(code.code)) {
            writer.element('p', text: line, inline: true);
          }

        case BookRawHtmlBlock rawHtml:
          writer.element('p', text: _stripTags(rawHtml.html), inline: true);

        case BookRawXmlBlock rawXml:
          writer.element('p', text: rawXml.xml, inline: true);
      }
    }
  }

  void _writeInlines(_Fb2XmlWriter writer, List<BookInline> inlines, _Fb2Context ctx) {
    for (final inline in inlines) {
      switch (inline) {
        case BookText text:
          writer.text(text.text);

        case BookLineBreak():
          writer.element('empty-line');

        case BookEmphasis emphasis:
          writer.openElement('emphasis', inline: true);
          _writeInlines(writer, emphasis.children, ctx);
          writer.closeElement('emphasis', inline: true);

        case BookStrong strong:
          writer.openElement('strong', inline: true);
          _writeInlines(writer, strong.children, ctx);
          writer.closeElement('strong', inline: true);

        case BookStrike strike:
          writer.openElement('strikethrough', inline: true);
          _writeInlines(writer, strike.children, ctx);
          writer.closeElement('strikethrough', inline: true);

        case BookCodeSpan codeSpan:
          writer.text(codeSpan.code);

        case BookLink link:
          writer.openElement('a', attributes: {'l:href': link.href.toString()}, inline: true);
          _writeInlines(writer, link.children, ctx);
          writer.closeElement('a', inline: true);

        case BookAnchor anchor:
          writer.element('a', attributes: {'id': anchor.id}, inline: true);

        case BookImageInline imageInline:
          final cleanId = ctx.getId(imageInline.ref.id, isCover: false);
          writer.element('image', attributes: {'l:href': '#$cleanId'}, inline: true);

        case BookSuperscript superscript:
          writer.openElement('sup', inline: true);
          _writeInlines(writer, superscript.children, ctx);
          writer.closeElement('sup', inline: true);

        case BookSubscript subscript:
          writer.openElement('sub', inline: true);
          _writeInlines(writer, subscript.children, ctx);
          writer.closeElement('sub', inline: true);

        case BookFootnoteRef footnoteRef:
          writer.openElement('a', attributes: {'l:href': '#${footnoteRef.id}', 'type': 'note'}, inline: true);
          if (footnoteRef.label.isNotEmpty) {
            _writeInlines(writer, footnoteRef.label, ctx);
          } else {
            writer.text('[${footnoteRef.id}]');
          }
          writer.closeElement('a', inline: true);

        case BookRawHtmlInline rawHtmlInline:
          writer.text(_stripTags(rawHtmlInline.html));

        case BookRawXmlInline rawXmlInline:
          writer.text(rawXmlInline.xml);
      }
    }
  }

  String _stripTags(String raw) {
    return raw.replaceAll(RegExp(r'<[^>]+>'), '');
  }

  Map<String, String> _idAttribute(String? id) {
    if (id == null || id.trim().isEmpty) return const {};
    return {'id': id};
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class _Fb2Context {
  final Book book;
  final BookEncodingOptions? options;
  final Map<String, String> _cache = {};
  int _imageCounter = 0;

  _Fb2Context(this.book, this.options);

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
      cleanId = generated.contains('.') ? generated : '$generated.$ext';
    }

    _cache[src] = cleanId;
    return cleanId;
  }
}

class _Fb2XmlWriter {
  final StringBuffer _buffer = StringBuffer();
  final bool pretty;
  int _indentLevel = 0;

  _Fb2XmlWriter({required this.pretty});

  void _indent() {
    if (!pretty) return;
    _buffer.write('  ' * _indentLevel);
  }

  void _newline() {
    if (!pretty) return;
    _buffer.write('\n');
  }

  void processing(String target, String text) {
    _buffer.write('<?$target $text?>');
    _newline();
  }

  void openElement(String name, {Map<String, String>? attributes, bool selfClosing = false, bool inline = false}) {
    if (!inline) _indent();
    _buffer.write('<$name');
    if (attributes != null && attributes.isNotEmpty) {
      for (final entry in attributes.entries) {
        if (entry.value.isNotEmpty || entry.key == 'id' || entry.key == 'name') {
          _buffer.write(' ${entry.key}="${_escape(entry.value)}"');
        }
      }
    }
    if (selfClosing) {
      _buffer.write('/>');
      if (!inline) _newline();
    } else {
      _buffer.write('>');
      if (!inline) {
        _newline();
        _indentLevel++;
      }
    }
  }

  void closeElement(String name, {bool inline = false}) {
    if (!inline) {
      _indentLevel--;
      _indent();
    }
    _buffer.write('</$name>');
    if (!inline) _newline();
  }

  void text(String text) {
    _buffer.write(_escape(text));
  }

  void element(String name, {Map<String, String>? attributes, String? text, bool inline = false}) {
    if (text == null || text.isEmpty) {
      openElement(name, attributes: attributes, selfClosing: true, inline: inline);
    } else {
      openElement(name, attributes: attributes, inline: inline);
      this.text(text);
      closeElement(name, inline: true);
    }
  }

  void binaryElement(String id, String mediaType, Uint8List bytes) {
    if (pretty) _indent();
    _buffer.write('<binary id="${_escape(id)}" content-type="${_escape(mediaType)}">');
    _buffer.write(base64Encode(bytes));
    _buffer.write('</binary>');
    if (pretty) _newline();
  }

  String _escape(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  @override
  String toString() => _buffer.toString();
}

String _extensionForMedia(String mediaType, String src) {
  final mt = mediaType.toLowerCase();
  if (mt.contains('jpeg') || mt.contains('jpg')) return 'jpg';
  if (mt.contains('png')) return 'png';
  if (mt.contains('webp')) return 'webp';
  if (mt.contains('gif')) return 'gif';
  if (mt.contains('svg')) return 'svg';

  final clean = src.split('?').first.split('#').first;
  if (clean.contains('.')) {
    final ext = clean.split('.').last.toLowerCase();
    if (ext.length <= 4 && RegExp(r'^[a-z0-9]+$').hasMatch(ext)) {
      return ext;
    }
  }
  return 'jpg';
}
