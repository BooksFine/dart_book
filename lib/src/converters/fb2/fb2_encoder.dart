import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_book/dart_book.dart';
import 'package:xml/xml.dart';

class Fb2Encoder implements BookEncoder {
  @override
  bool canEncode(String extension) {
    final ext = extension.toLowerCase();
    return ext == 'fb2' || ext == 'xml';
  }

  @override
  FutureOr<Uint8List> encode(
    Book book, {
    bool pretty = true,
    BookResourceResolver? resourceResolver,
  }) {
    if (resourceResolver != null) {
      return _encodeAsync(book, pretty, resourceResolver);
    }
    final xml = _buildXml(book, pretty: pretty);
    return Uint8List.fromList(utf8.encode(xml));
  }

  Future<Uint8List> _encodeAsync(
    Book book,
    bool pretty,
    BookResourceResolver resourceResolver,
  ) async {
    final resolvedBook = await resolveBookResources(
      book,
      resourceResolver,
      baseUri: book.metadata.source,
    );
    final xml = _buildXml(resolvedBook, pretty: pretty);
    return Uint8List.fromList(utf8.encode(xml));
  }

  String _buildXml(Book book, {bool pretty = true}) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="utf-8"');
    builder.element(
      'FictionBook',
      attributes: {
        'xmlns': 'http://www.gribuser.ru/xml/fictionbook/2.0',
        'xmlns:l': 'http://www.w3.org/1999/xlink',
      },
      nest: () {
        _buildDescription(builder, book);
        _buildMainBody(builder, book);
        _buildNotesBody(builder, book.content);
        _buildBinaries(builder, book.resources);
      },
    );

    final document = builder.buildDocument();
    return document.toXmlString(pretty: pretty, indent: '  ');
  }

  void _buildDescription(XmlBuilder builder, Book book) {
    final metadata = book.metadata;

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
                  _writeBlocks(builder, metadata.annotation!.blocks);
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
              builder.element(
                'coverpage',
                nest: () {
                  builder.element(
                    'image',
                    attributes: {'l:href': '#${metadata.cover!.ref.id}'},
                  );
                },
              );
            }
          },
        );

        builder.element(
          'document-info',
          nest: () {
            builder.element('id', nest: book.id);
            builder.element('version', nest: '1.0');
            builder.element(
              'date',
              attributes: {'value': _formatDate(DateTime.now())},
              nest: _formatDate(DateTime.now()),
            );
            if (metadata.source != null) {
              builder.element('src-url', nest: metadata.source.toString());
            }
            builder.element('program-used', nest: 'dart_book');
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

  void _buildMainBody(XmlBuilder builder, Book book) {
    builder.element(
      'body',
      nest: () {
        builder.element(
          'title',
          nest: () {
            builder.element('p', nest: book.metadata.title);
          },
        );
        _writeBlocks(builder, book.content.blocks);
      },
    );
  }

  void _buildNotesBody(XmlBuilder builder, BookContent content) {
    if (content.footnotes.isEmpty) return;

    builder.element(
      'body',
      attributes: {'name': 'notes'},
      nest: () {
        for (final footnote in content.footnotes) {
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
              _writeBlocks(builder, footnote.blocks);
            },
          );
        }
      },
    );
  }

  void _buildBinaries(XmlBuilder builder, List<BookResource> resources) {
    for (final resource in resources) {
      builder.element(
        'binary',
        attributes: {'id': resource.id, 'content-type': resource.mediaType},
        nest: base64Encode(resource.bytes),
      );
    }
  }

  void _writeBlocks(XmlBuilder builder, List<BookBlock> blocks) {
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
                        _writeInlines(builder, section.title);
                      },
                    );
                  },
                );
              }
              _writeBlocks(builder, section.blocks);
              _writeBlocks(builder, section.children);
            },
          );

        case BookHeading heading:
          builder.element(
            'subtitle',
            nest: () {
              _writeInlines(builder, heading.text);
            },
          );

        case BookParagraph paragraph:
          builder.element(
            'p',
            nest: () {
              _writeInlines(builder, paragraph.inlines);
            },
          );

        case BookQuote quote:
          builder.element(
            'cite',
            nest: () {
              _writeBlocks(builder, quote.blocks);
              if (quote.citation.isNotEmpty) {
                builder.element(
                  'text-author',
                  nest: () {
                    _writeInlines(builder, quote.citation);
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
                      _writeInlines(builder, paragraph.inlines);
                    },
                  );
                default:
                  _writeBlocks(builder, [itemBlock]);
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
                          _writeBlocks(builder, cell.blocks);
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
                          _writeInlines(builder, line.inlines);
                        },
                      );
                    }
                  },
                );
              }
            },
          );

        case BookImageBlock image:
          builder.element('image', attributes: {'l:href': '#${image.ref.id}'});

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

  void _writeInlines(XmlBuilder builder, List<BookInline> inlines) {
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
              _writeInlines(builder, emphasis.children);
            },
          );

        case BookStrong strong:
          builder.element(
            'strong',
            nest: () {
              _writeInlines(builder, strong.children);
            },
          );

        case BookStrike strike:
          builder.element(
            'strikethrough',
            nest: () {
              _writeInlines(builder, strike.children);
            },
          );

        case BookCodeSpan codeSpan:
          builder.text(codeSpan.code);

        case BookLink link:
          builder.element(
            'a',
            attributes: {'l:href': link.href.toString()},
            nest: () {
              _writeInlines(builder, link.children);
            },
          );

        case BookAnchor anchor:
          builder.element('a', attributes: {'id': anchor.id});

        case BookImageInline imageInline:
          builder.element(
            'image',
            attributes: {'l:href': '#${imageInline.ref.id}'},
          );

        case BookSuperscript superscript:
          builder.element(
            'sup',
            nest: () {
              _writeInlines(builder, superscript.children);
            },
          );

        case BookSubscript subscript:
          builder.element(
            'sub',
            nest: () {
              _writeInlines(builder, subscript.children);
            },
          );

        case BookFootnoteRef footnoteRef:
          builder.element(
            'a',
            attributes: {'l:href': '#${footnoteRef.id}', 'type': 'note'},
            nest: () {
              if (footnoteRef.label.isNotEmpty) {
                _writeInlines(builder, footnoteRef.label);
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
