import 'dart:typed_data';
import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';

void main() {
  group('ResourceResolver & ResourceRequestsCollector Tests', () {
    test('collectResourceRequestsFromBook extracts all image requests from rich AST', () {
      final book = Book(
        metadata: const BookMetadata(
          id: 'test-reqs',
          title: 'Requests Book',
          language: 'ru',
          cover: BookCover(ref: BookResourceRef('cover.png')),
          annotation: BookContent(
            blocks: [
              BookParagraph(
                inlines: [
                  BookText('Аннотация с картинкой: '),
                  BookImageInline(
                    ref: BookResourceRef('annot_icon.png'),
                    attributes: {'source-src': 'https://example.com/annot.png'},
                  ),
                ],
              ),
            ],
          ),
        ),
        content: BookContent(
          blocks: [
            BookSection(
              title: [const BookText('Глава 1')],
              blocks: [
                const BookImageBlock(
                  ref: BookResourceRef('chapter1.png'),
                  attributes: {'source-src': 'https://example.com/ch1.png'},
                ),
                const BookQuote(
                  blocks: [
                    BookParagraph(
                      inlines: [
                        BookImageInline(
                          ref: BookResourceRef('quote_img.png'),
                          attributes: {'source-src': 'quote_img.png'},
                        ),
                      ],
                    ),
                  ],
                  citation: [BookText('Цитата')],
                ),
                BookList(
                  ordered: false,
                  items: [
                    BookListItem(
                      blocks: [
                        const BookParagraph(
                          inlines: [
                            BookEmphasis(
                              children: [
                                BookImageInline(ref: BookResourceRef('item1.png')),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                BookTable(
                  rows: [
                    BookTableRow(
                      cells: [
                        BookTableCell(
                          blocks: [
                            BookParagraph(
                              inlines: [
                                BookLink(
                                  href: Uri.parse('https://example.com'),
                                  children: const [
                                    BookImageInline(ref: BookResourceRef('table_cell.png')),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],

                    ),
                  ],
                ),
                const BookPoem(
                  stanzas: [
                    BookStanza(
                      lines: [
                        BookPoemLine(
                          inlines: [
                            BookStrong(
                              children: [
                                BookImageInline(ref: BookResourceRef('poem_icon.png')),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        resources: const [],
      );

      final requests = collectResourceRequestsFromBook(book);
      expect(requests, isNotEmpty);
      final reqIds = requests.map((r) => r.id).toList();
      expect(reqIds, contains('cover.png'));
      expect(reqIds, contains('annot_icon.png'));
      expect(reqIds, contains('chapter1.png'));
      expect(reqIds, contains('quote_img.png'));
      expect(reqIds, contains('item1.png'));
      expect(reqIds, contains('table_cell.png'));
      expect(reqIds, contains('poem_icon.png'));
    });

    test('resolveResources: downloads pending resources with progress callbacks', () async {
      final book = Book(
        metadata: const BookMetadata(
          id: 'test-res',
          title: 'Resolve Book',
          language: 'ru',
          cover: BookCover(ref: BookResourceRef('res1.png')),
        ),
        content: const BookContent(
          blocks: [
            BookParagraph(
              inlines: [
                BookImageInline(
                  ref: BookResourceRef('res2.png'),
                  attributes: {'source-src': 'images/res2.png'},
                ),
              ],
            ),
          ],
        ),
        resources: const [],
      );

      var progressCalls = 0;
      final resolvedBook = await book.resolveResources(
        (request, {onByteProgress}) async {
          onByteProgress?.call(50, 100);
          onByteProgress?.call(100, 100);
          if (request.id == 'res1.png') {
            return BookResource(
              id: 'res1.png',
              mediaType: 'image/png',
              bytes: Uint8List.fromList([1, 2, 3, 4]),
            );
          } else if (request.id == 'res2.png') {
            return BookResource(
              id: 'res2.png',
              mediaType: 'image/png',
              bytes: Uint8List.fromList([5, 6, 7, 8]),
            );
          }
          return null;
        },
        baseUri: Uri.parse('https://example.com/books/'),
        onProgress: (completed, total, states) {
          progressCalls++;
          expect(total, equals(2));
        },
        maxConcurrent: 2,
      );

      expect(resolvedBook.resources.length, equals(2));
      expect(progressCalls, greaterThan(0));
    });

    test('resolveResources: handles failure and already resolved resources gracefully', () async {
      final existingRes = BookResource(
        id: 'already_present.png',
        mediaType: 'image/png',
        bytes: Uint8List.fromList([9, 9, 9]),
      );

      final book = Book(
        metadata: const BookMetadata(
          id: 'test-err',
          title: 'Error Book',
          language: 'en',
          cover: BookCover(ref: BookResourceRef('already_present.png')),
        ),
        content: const BookContent(
          blocks: [
            BookParagraph(
              inlines: [
                BookImageInline(ref: BookResourceRef('fail_me.png')),
                BookImageInline(ref: BookResourceRef('throw_me.png')),
              ],
            ),
          ],
        ),
        resources: [existingRes],
      );

      final resolvedBook = await book.resolveResources((request, {onByteProgress}) async {
        if (request.id == 'fail_me.png') {
          return null; // fails
        }
        if (request.id == 'throw_me.png') {
          throw Exception('Network error');
        }
        return null;
      });

      // Existing resource is retained, failed ones are not added
      expect(resolvedBook.resources.length, equals(1));
      expect(resolvedBook.resources.first.id, equals('already_present.png'));

      // If all resources already exist, returns book immediately
      final allResolvedBook = await resolvedBook.resolveResources((req, {onByteProgress}) async => null);
      expect(allResolvedBook.resources.length, equals(resolvedBook.resources.length));
    });
  });
}

