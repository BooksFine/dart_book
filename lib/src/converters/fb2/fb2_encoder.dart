import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_book/dart_book.dart';
import 'package:xml/xml.dart';

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
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="utf-8"');
    builder.element(
      'FictionBook',
      attributes: {
        'xmlns': 'http://www.gribuser.ru/xml/fictionbook/2.0',
        'xmlns:l': 'http://www.w3.org/1999/xlink',
      },
      nest: () {
        _buildDescription(builder, ctx);
        _buildMainBody(builder, ctx);
        _buildNotesBody(builder, ctx);
        _buildBinaries(builder, ctx);
      },
    );

    final document = builder.buildDocument();
    return document.toXmlString(pretty: pretty, indent: '  ');
  }

  void _buildDescription(XmlBuilder builder, _Fb2Context ctx) {
    final metadata = ctx.book.metadata;

    builder.element(
      'description',
      nest: () {
        builder.element(
          'title-info',
          nest: () {
            for (final genre in metadata.genres) {
              builder.element('genre', nest: genre.code);
            }

            final authors = metadata.contributorsByRole(
              BookContributorRole.author,
            );
            for (final author in authors) {
              builder.element(
                'author',
                nest: () {
                  final name = author.name;
                  if (name.first?.trim().isNotEmpty == true) {
                    builder.element('first-name', nest: name.first!.trim());
                  }
                  if (name.middle?.trim().isNotEmpty == true) {
                    builder.element('middle-name', nest: name.middle!.trim());
                  }
                  if (name.last?.trim().isNotEmpty == true) {
                    builder.element('last-name', nest: name.last!.trim());
                  }
                  if (name.nickname?.trim().isNotEmpty == true) {
                    builder.element('nickname', nest: name.nickname!.trim());
                  }
                  if (author.homePage != null) {
                    builder.element(
                      'home-page',
                      nest: author.homePage.toString(),
                    );
                  }
                  if (author.email != null && author.email!.trim().isNotEmpty) {
                    builder.element('email', nest: author.email!.trim());
                  }
                },
              );
            }

            builder.element('book-title', nest: metadata.title);
            builder.element('lang', nest: metadata.language);

            if (metadata.annotation != null) {
              builder.element(
                'annotation',
                nest: () {
                  _writeBlocks(builder, metadata.annotation!.blocks, ctx);
                },
              );
            }

            if (metadata.keywords.isNotEmpty) {
              builder.element('keywords', nest: metadata.keywords.join(', '));
            }

            if (metadata.updatedAt != null) {
              builder.element(
                'date',
                attributes: {'value': _formatDate(metadata.updatedAt!)},
                nest: _formatDate(metadata.updatedAt!),
              );
            } else if (metadata.publishedAt != null) {
              builder.element(
                'date',
                attributes: {'value': _formatDate(metadata.publishedAt!)},
                nest: _formatDate(metadata.publishedAt!),
              );
            }

            if (metadata.series != null) {
              final series = metadata.series!;
              final attributes = <String, String>{'name': series.name};
              if (series.number != null) {
                attributes['number'] = series.number.toString();
              }
              builder.element('sequence', attributes: attributes);
            }

            if (metadata.cover != null) {
              final cleanId = ctx.getId(metadata.cover!.ref.id, isCover: true);
              builder.element(
                'coverpage',
                nest: () {
                  builder.element(
                    'image',
                    attributes: {'l:href': '#$cleanId'},
                  );
                },
              );
            }
          },
        );

        builder.element(
          'document-info',
          nest: () {
            final docId = ctx.options?.documentId ?? metadata.id;
            builder.element('id', nest: docId);
            builder.element('version', nest: '1.0');
            builder.element(
              'date',
              attributes: {'value': _formatDate(DateTime.now())},
              nest: _formatDate(DateTime.now()),
            );
            if (metadata.source != null) {
              builder.element('src-url', nest: metadata.source.toString());
            }
            final prog = ctx.options?.programUsed ?? programUsed;
            builder.element('program-used', nest: prog);
          },
        );

        if (metadata.series?.url != null) {
          builder.element(
            'custom-info',
            attributes: {'info-type': 'sequence-url'},
            nest: metadata.series!.url.toString(),
          );
        }
      },
    );
  }

  void _buildMainBody(XmlBuilder builder, _Fb2Context ctx) {
    builder.element(
      'body',
      nest: () {
        builder.element(
          'title',
          nest: () {
            builder.element('p', nest: ctx.book.metadata.title);
          },
        );
        _writeBlocks(builder, ctx.book.content.blocks, ctx);
      },
    );
  }

  void _buildNotesBody(XmlBuilder builder, _Fb2Context ctx) {
    if (ctx.book.content.footnotes.isEmpty) return;

    builder.element(
      'body',
      attributes: {'name': 'notes'},
      nest: () {
        for (final footnote in ctx.book.content.footnotes) {
          builder.element(
            'section',
            attributes: {'id': footnote.id},
            nest: () {
              builder.element(
                'title',
                nest: () {
                  builder.element('p', nest: footnote.id);
                },
              );
              _writeBlocks(builder, footnote.blocks, ctx);
            },
          );
        }
      },
    );
  }

  void _buildBinaries(XmlBuilder builder, _Fb2Context ctx) {
    for (final resource in ctx.book.resources) {
      final isCover = ctx.book.metadata.cover?.ref.id == resource.id;
      final cleanId = ctx.getId(resource.id, isCover: isCover);
      builder.element(
        'binary',
        attributes: {'id': cleanId, 'content-type': resource.mediaType},
        nest: base64Encode(resource.bytes),
      );
    }
  }

  void _writeBlocks(XmlBuilder builder, List<BookBlock> blocks, _Fb2Context ctx) {
    for (final block in blocks) {
      switch (block) {
        case BookSection section:
          builder.element(
            'section',
            attributes: _idAttribute(section.id),
            nest: () {
              if (section.title.isNotEmpty) {
                builder.element(
                  'title',
                  nest: () {
                    builder.element(
                      'p',
                      nest: () {
                        _writeInlines(builder, section.title, ctx);
                      },
                    );
                  },
                );
              }
              _writeBlocks(builder, section.blocks, ctx);
              _writeBlocks(builder, section.children, ctx);
            },
          );

        case BookHeading heading:
          builder.element(
            'subtitle',
            nest: () {
              _writeInlines(builder, heading.text, ctx);
            },
          );

        case BookParagraph paragraph:
          builder.element(
            'p',
            nest: () {
              _writeInlines(builder, paragraph.inlines, ctx);
            },
          );

        case BookQuote quote:
          builder.element(
            'cite',
            nest: () {
              _writeBlocks(builder, quote.blocks, ctx);
              if (quote.citation.isNotEmpty) {
                builder.element(
                  'text-author',
                  nest: () {
                    _writeInlines(builder, quote.citation, ctx);
                  },
                );
              }
            },
          );

        case BookList list:
          var index = 1;
          for (final item in list.items) {
            for (final itemBlock in item.blocks) {
              switch (itemBlock) {
                case BookParagraph paragraph:
                  builder.element(
                    'p',
                    nest: () {
                      final prefix = list.ordered ? '${index++}. ' : '• ';
                      builder.text(prefix);
                      _writeInlines(builder, paragraph.inlines, ctx);
                    },
                  );
                default:
                  _writeBlocks(builder, [itemBlock], ctx);
              }
            }
          }

        case BookTable table:
          builder.element(
            'table',
            nest: () {
              for (final row in table.rows) {
                builder.element(
                  'tr',
                  nest: () {
                    for (final cell in row.cells) {
                      builder.element(
                        'td',
                        nest: () {
                          _writeBlocks(builder, cell.blocks, ctx);
                        },
                      );
                    }
                  },
                );
              }
            },
          );

        case BookPoem poem:
          builder.element(
            'poem',
            nest: () {
              for (final stanza in poem.stanzas) {
                builder.element(
                  'stanza',
                  nest: () {
                    for (final line in stanza.lines) {
                      builder.element(
                        'v',
                        nest: () {
                          _writeInlines(builder, line.inlines, ctx);
                        },
                      );
                    }
                  },
                );
              }
            },
          );

        case BookImageBlock image:
          final cleanId = ctx.getId(image.ref.id, isCover: false);
          builder.element('image', attributes: {'l:href': '#$cleanId'});

        case BookAudioBlock audio:
          builder.element('p', nest: '[Audio: ${audio.ref.id}]');

        case BookVideoBlock video:
          builder.element('p', nest: '[Video: ${video.ref.id}]');

        case BookMathBlock math:
          builder.element('p', nest: _stripTags(math.mathml));

        case BookSvgBlock():
          builder.element('p', nest: '[SVG Graphic]');

        case BookHorizontalRule() || BookEmptyLine():
          builder.element('empty-line');

        case BookCodeBlock code:
          for (final line in const LineSplitter().convert(code.code)) {
            builder.element('p', nest: line);
          }

        case BookRawHtmlBlock rawHtml:
          builder.element('p', nest: _stripTags(rawHtml.html));

        case BookRawXmlBlock rawXml:
          builder.element('p', nest: rawXml.xml);
      }
    }
  }

  void _writeInlines(XmlBuilder builder, List<BookInline> inlines, _Fb2Context ctx) {
    for (final inline in inlines) {
      switch (inline) {
        case BookText text:
          builder.text(text.text);

        case BookLineBreak():
          builder.element('empty-line');

        case BookEmphasis emphasis:
          builder.element(
            'emphasis',
            nest: () {
              _writeInlines(builder, emphasis.children, ctx);
            },
          );

        case BookStrong strong:
          builder.element(
            'strong',
            nest: () {
              _writeInlines(builder, strong.children, ctx);
            },
          );

        case BookStrike strike:
          builder.element(
            'strikethrough',
            nest: () {
              _writeInlines(builder, strike.children, ctx);
            },
          );

        case BookCodeSpan codeSpan:
          builder.text(codeSpan.code);

        case BookLink link:
          builder.element(
            'a',
            attributes: {'l:href': link.href.toString()},
            nest: () {
              _writeInlines(builder, link.children, ctx);
            },
          );

        case BookAnchor anchor:
          builder.element('a', attributes: {'id': anchor.id});

        case BookImageInline imageInline:
          final cleanId = ctx.getId(imageInline.ref.id, isCover: false);
          builder.element(
            'image',
            attributes: {'l:href': '#$cleanId'},
          );

        case BookSuperscript superscript:
          builder.element(
            'sup',
            nest: () {
              _writeInlines(builder, superscript.children, ctx);
            },
          );

        case BookSubscript subscript:
          builder.element(
            'sub',
            nest: () {
              _writeInlines(builder, subscript.children, ctx);
            },
          );

        case BookFootnoteRef footnoteRef:
          builder.element(
            'a',
            attributes: {'l:href': '#${footnoteRef.id}', 'type': 'note'},
            nest: () {
              if (footnoteRef.label.isNotEmpty) {
                _writeInlines(builder, footnoteRef.label, ctx);
              } else {
                builder.text('[${footnoteRef.id}]');
              }
            },
          );

        case BookRawHtmlInline rawHtmlInline:
          builder.text(_stripTags(rawHtmlInline.html));

        case BookRawXmlInline rawXmlInline:
          builder.text(rawXmlInline.xml);
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
      final policy = options?.namingPolicy ?? BookResourceNamingPolicy.sequential;
      final generated = policy.generateName(src, isInline: false, index: ++_imageCounter);
      cleanId = generated.contains('.') ? generated : '$generated.$ext';
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
