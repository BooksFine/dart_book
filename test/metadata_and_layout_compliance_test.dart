import 'dart:convert';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:dart_book/dart_book.dart';

void main() {
  group('Category 1 & 2 Compliance & Roundtrip Tests', () {
    test('FB2 PublishInfo roundtrip: publisher, city, year, isbn', () async {
      final originalBook = Book(
        metadata: const BookMetadata(
          id: 'fb2-pub-1',
          title: 'Издательская книга',
          language: 'ru',
          publishInfo: BookPublishInfo(
            publisher: 'Эксмо',
            city: 'Москва',
            year: 2024,
            isbn: '978-5-04-123456-7',
          ),
        ),
        content: const BookContent(
          blocks: [BookParagraph(inlines: [BookText('Текст')])],
        ),
        resources: const [],
      );

      final encodedBytes = await Fb2Encoder().encode(originalBook);
      final decodedBook = Fb2Decoder().decode(encodedBytes);

      expect(decodedBook.metadata.publishInfo, isNotNull);
      expect(decodedBook.metadata.publishInfo!.publisher, equals('Эксмо'));
      expect(decodedBook.metadata.publishInfo!.city, equals('Москва'));
      expect(decodedBook.metadata.publishInfo!.year, equals(2024));
      expect(decodedBook.metadata.publishInfo!.isbn, equals('978-5-04-123456-7'));
    });

    test('EPUB PublishInfo and ISBN roundtrip', () async {
      final originalBook = Book(
        metadata: BookMetadata(
          id: 'epub-pub-1',
          title: 'EPUB Издание',
          language: 'en',
          publishedAt: DateTime(2023, 5, 12),
          publishInfo: const BookPublishInfo(
            publisher: 'OReilly Media',
            isbn: '978-1-491-95438-6',
            year: 2023,
          ),
        ),
        content: const BookContent(
          blocks: [
            BookSection(
              title: [BookText('Chapter 1')],
              blocks: [BookParagraph(inlines: [BookText('Content')])],
            ),
          ],
        ),
        resources: const [],
      );

      final encodedBytes = EpubEncoder().encode(originalBook);
      final decodedBook = await EpubDecoder().decode(encodedBytes);

      expect(decodedBook.metadata.publishInfo, isNotNull);
      expect(decodedBook.metadata.publishInfo!.publisher, equals('OReilly Media'));
      expect(decodedBook.metadata.publishInfo!.isbn, equals('978-1-491-95438-6'));
      expect(decodedBook.metadata.publishedAt, isNotNull);
      expect(decodedBook.metadata.publishedAt!.year, equals(2023));
    });

    test('Multiple series in FB2 and EPUB 3 collections', () async {
      final originalBook = Book(
        metadata: const BookMetadata(
          id: 'series-test-1',
          title: 'Многосерийная книга',
          language: 'ru',
          series: [
            BookSeries(name: 'Основная Серия', number: 1),
            BookSeries(name: 'Сквозная Подсерия', number: 4),
          ],
        ),
        content: const BookContent(
          blocks: [
            BookSection(
              title: [BookText('Глава 1')],
              blocks: [BookParagraph(inlines: [BookText('Текст главы')])],
            ),
          ],
        ),
        resources: const [],
      );

      // FB2
      final fb2Bytes = await Fb2Encoder().encode(originalBook);
      final decodedFb2 = Fb2Decoder().decode(fb2Bytes);
      expect(decodedFb2.metadata.series.length, equals(2));
      expect(decodedFb2.metadata.series[0].name, equals('Основная Серия'));
      expect(decodedFb2.metadata.series[0].number, equals(1));
      expect(decodedFb2.metadata.series[1].name, equals('Сквозная Подсерия'));
      expect(decodedFb2.metadata.series[1].number, equals(4));

      // EPUB
      final epubBytes = EpubEncoder().encode(originalBook);
      final decodedEpub = await EpubDecoder().decode(epubBytes);
      expect(decodedEpub.metadata.series.length, equals(2));
      expect(decodedEpub.metadata.series[0].name, equals('Основная Серия'));
      expect(decodedEpub.metadata.series[0].number, equals(1));
      expect(decodedEpub.metadata.series[1].name, equals('Сквозная Подсерия'));
      expect(decodedEpub.metadata.series[1].number, equals(4));
    });

    test('Original work metadata (src-lang and src-title-info) in FB2 and EPUB', () async {
      final originalBook = Book(
        metadata: const BookMetadata(
          id: 'translation-1',
          title: 'Властелин Колец',
          language: 'ru',
          srcLang: 'en',
          srcTitleInfo: BookSourceTitleInfo(
            title: 'The Lord of the Rings',
            language: 'en',
            authors: [
              BookContributor(
                role: BookContributorRole.author,
                name: PersonName(first: 'J.R.R.', last: 'Tolkien'),
              ),
            ],
          ),
        ),
        content: const BookContent(
          blocks: [BookParagraph(inlines: [BookText('Три Кольца — для эльфийских царей...')])],
        ),
        resources: const [],
      );

      // FB2 roundtrip
      final fb2Bytes = await Fb2Encoder().encode(originalBook);
      final decodedFb2 = Fb2Decoder().decode(fb2Bytes);
      expect(decodedFb2.metadata.srcLang, equals('en'));
      expect(decodedFb2.metadata.srcTitleInfo, isNotNull);
      expect(decodedFb2.metadata.srcTitleInfo!.title, equals('The Lord of the Rings'));
      expect(decodedFb2.metadata.srcTitleInfo!.language, equals('en'));
      expect(decodedFb2.metadata.srcTitleInfo!.authors.length, equals(1));
      expect(decodedFb2.metadata.srcTitleInfo!.authors.first.name.last, equals('Tolkien'));

      // EPUB roundtrip
      final epubBytes = EpubEncoder().encode(originalBook);
      final decodedEpub = await EpubDecoder().decode(epubBytes);
      expect(decodedEpub.metadata.srcLang, equals('en'));
      expect(decodedEpub.metadata.srcTitleInfo?.title, equals('The Lord of the Rings'));
    });

    test('Full Windows-1251 decoding with quotes, dashes, №, and rare characters', () {
      final rawWin1251 = [
        0xAB, // «
        0x54, 0x65, 0x73, 0x74, // Test
        0xBB, // »
        0x20,
        0x97, // —
        0x20,
        0xB9, // №
        0x31,
        0x85, // …
        0x20,
        0xC0, 0xE1, 0xE2, // Абв
      ];

      final prefix = ascii.encode('<?xml version="1.0" encoding="windows-1251"?>\n<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0"><description><title-info><book-title>');
      final suffix = ascii.encode('</book-title></title-info></description><body><p>Text</p></body></FictionBook>');
      final fullBytes = Uint8List.fromList([...prefix, ...rawWin1251, ...suffix]);

      final book = Fb2Decoder().decode(fullBytes);
      expect(book.metadata.title, contains('«'));
      expect(book.metadata.title, contains('»'));
      expect(book.metadata.title, contains('—'));
      expect(book.metadata.title, contains('№'));
      expect(book.metadata.title, contains('…'));
      expect(book.metadata.title, contains('Абв'));
    });

    test('Image attributes (id, alt, title) in block and inline nodes in FB2 & EPUB', () async {
      final imgResource = BookResource(
        id: 'img1.png',
        mediaType: 'image/png',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
      );

      final originalBook = Book(
        metadata: const BookMetadata(
          id: 'img-test-1',
          title: 'Image Test',
          language: 'ru',
        ),
        content: const BookContent(
          blocks: [
            BookSection(
              title: [BookText('Section 1')],
              blocks: [
                BookImageBlock(
                  id: 'figure-1',
                  ref: BookResourceRef('img1.png'),
                  alt: 'Альтернативный текст картинки',
                  title: 'Всплывающая подсказка',
                ),
                BookParagraph(
                  inlines: [
                    BookText('Текст перед '),
                    BookImageInline(
                      id: 'inline-img-1',
                      ref: BookResourceRef('img1.png'),
                      alt: 'Инлайн alt',
                      title: 'Инлайн title',
                    ),
                    BookText(' текст после'),
                  ],
                ),
              ],
            ),
          ],
        ),
        resources: [imgResource],
      );

      // FB2
      final fb2Bytes = await Fb2Encoder().encode(originalBook);
      final fb2Xml = utf8.decode(fb2Bytes);
      expect(fb2Xml, contains('alt="Альтернативный текст картинки"'));
      expect(fb2Xml, contains('title="Всплывающая подсказка"'));
      expect(fb2Xml, contains('id="figure-1"'));

      final decodedFb2 = Fb2Decoder().decode(fb2Bytes);
      final fb2Sec = decodedFb2.content.blocks.whereType<BookSection>().first;
      final blockImg = fb2Sec.blocks.whereType<BookImageBlock>().first;
      expect(blockImg.alt, equals('Альтернативный текст картинки'));
      expect(blockImg.title, equals('Всплывающая подсказка'));
      expect(blockImg.id, equals('figure-1'));

      final para = fb2Sec.blocks.whereType<BookParagraph>().first;
      final inlineImg = para.inlines.whereType<BookImageInline>().first;
      expect(inlineImg.alt, equals('Инлайн alt'));
      expect(inlineImg.title, equals('Инлайн title'));
      expect(inlineImg.id, equals('inline-img-1'));

      // EPUB
      final epubBytes = EpubEncoder().encode(originalBook);
      final decodedEpub = await EpubDecoder().decode(epubBytes);
      final epubBlockImg = _allBlocks(decodedEpub.content.blocks).whereType<BookImageBlock>().first;
      expect(epubBlockImg.alt, equals('Альтернативный текст картинки'));
      expect(epubBlockImg.title, equals('Всплывающая подсказка'));
      expect(epubBlockImg.id, equals('figure-1'));
    });

    test('Table cell alignment (align and valign) in FB2 and EPUB', () async {
      final originalBook = Book(
        metadata: const BookMetadata(
          id: 'table-align-1',
          title: 'Table Alignment',
          language: 'en',
        ),
        content: const BookContent(
          blocks: [
            BookSection(
              title: [BookText('Section 1')],
              blocks: [
                BookTable(
                  rows: [
                    BookTableRow(
                      cells: [
                        BookTableCell(
                          blocks: [BookParagraph(inlines: [BookText('Header 1')])],
                          colSpan: 2,
                          align: 'center',
                          vAlign: 'top',
                        ),
                      ],
                    ),
                    BookTableRow(
                      cells: [
                        BookTableCell(
                          blocks: [BookParagraph(inlines: [BookText('Cell 1')])],
                          align: 'right',
                          vAlign: 'bottom',
                        ),
                        BookTableCell(
                          blocks: [BookParagraph(inlines: [BookText('Cell 2')])],
                          align: 'left',
                          vAlign: 'middle',
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

      // FB2
      final fb2Bytes = await Fb2Encoder().encode(originalBook);
      final decodedFb2 = Fb2Decoder().decode(fb2Bytes);
      final fb2Table = _allBlocks(decodedFb2.content.blocks).whereType<BookTable>().first;
      expect(fb2Table.rows[0].cells[0].align, equals('center'));
      expect(fb2Table.rows[0].cells[0].vAlign, equals('top'));
      expect(fb2Table.rows[1].cells[0].align, equals('right'));
      expect(fb2Table.rows[1].cells[0].vAlign, equals('bottom'));

      // EPUB
      final epubBytes = EpubEncoder().encode(originalBook);
      final decodedEpub = await EpubDecoder().decode(epubBytes);
      final epubTable = _allBlocks(decodedEpub.content.blocks).whereType<BookTable>().first;
      expect(epubTable.rows[0].cells[0].align, equals('center'));
      expect(epubTable.rows[0].cells[0].vAlign, equals('top'));
      expect(epubTable.rows[1].cells[0].align, equals('right'));
      expect(epubTable.rows[1].cells[0].vAlign, equals('bottom'));
    });

    test('BookLayout (fixedLayout, roll, reflowable) in EPUB', () async {
      final comicBook = Book(
        metadata: const BookMetadata(
          id: 'comic-1',
          title: 'Fixed Layout Comic',
          language: 'en',
          layout: BookLayout.fixedLayout,
        ),
        content: const BookContent(
          blocks: [
            BookSection(
              title: [BookText('Page 1')],
              blocks: [BookParagraph(inlines: [BookText('Graphic panel')])],
            ),
          ],
        ),
        resources: const [],
      );

      final epubBytes = EpubEncoder().encode(comicBook);
      final decoded = await EpubDecoder().decode(epubBytes);
      expect(decoded.metadata.layout, equals(BookLayout.fixedLayout));

      final webtoonBook = comicBook.copyWith(
        metadata: comicBook.metadata.copyWith(layout: BookLayout.roll),
      );
      final webtoonBytes = EpubEncoder().encode(webtoonBook);
      final decodedWebtoon = await EpubDecoder().decode(webtoonBytes);
      expect(decodedWebtoon.metadata.layout, equals(BookLayout.roll));
    });

    test('BookNamedStyle (<style name="...">) in FB2 and EPUB', () async {
      final originalBook = Book(
        metadata: const BookMetadata(
          id: 'custom-style-1',
          title: 'Named Style Book',
          language: 'ru',
        ),
        content: const BookContent(
          blocks: [
            BookParagraph(
              inlines: [
                BookText('Обычный текст и '),
                BookNamedStyle(
                  name: 'highlight-red',
                  inlines: [BookText('выделенный стиль')],
                ),
                BookText('.'),
              ],
            ),
          ],
        ),
        resources: const [],
      );

      // FB2
      final fb2Bytes = await Fb2Encoder().encode(originalBook);
      final fb2Xml = utf8.decode(fb2Bytes);
      expect(fb2Xml, contains('<style name="highlight-red">выделенный стиль</style>'));

      final decodedFb2 = Fb2Decoder().decode(fb2Bytes);
      final p = decodedFb2.content.blocks.whereType<BookParagraph>().first;
      final styled = p.inlines.whereType<BookNamedStyle>().first;
      expect(styled.name, equals('highlight-red'));
      expect((styled.inlines.first as BookText).text, equals('выделенный стиль'));

      // EPUB
      final epubBytes = EpubEncoder().encode(originalBook);
      final epubDoc = await EpubDecoder().decode(epubBytes);
      expect(epubDoc.content.blocks, isNotEmpty);
      final pEpub = _allBlocks(epubDoc.content.blocks).whereType<BookParagraph>().first;
      final styledEpub = pEpub.inlines.whereType<BookNamedStyle>().first;
      expect(styledEpub.name, equals('highlight-red'));
      expect((styledEpub.inlines.first as BookText).text, equals('выделенный стиль'));
    });
  });
}

List<BookBlock> _allBlocks(List<BookBlock> blocks) {
  final result = <BookBlock>[];
  for (final b in blocks) {
    result.add(b);
    if (b is BookSection) {
      result.addAll(_allBlocks(b.blocks));
    }
  }
  return result;
}
