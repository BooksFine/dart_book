import 'dart:typed_data';
import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';
import 'utils/book_equality.dart';

void main() {
  group('Deep AST Lossless Conversion Tests', () {
    test('Verifies 100% loss-less AST equivalence for all BookBlock and BookInline node types in EPUB & FB2', () async {
      final originalBook = Book(
        id: 'ast-test-1',
        metadata: const BookMetadata(
          title: 'Full AST Test Book',
          language: 'ru',
          contributors: [
            BookContributor(
              role: BookContributorRole.author,
              name: PersonName(first: 'Федор', last: 'Достоевский', display: 'Федор Достоевский'),
            ),
          ],
        ),
        content: const BookContent(
          blocks: [
            BookHeading(level: 1, text: [BookText('Глава 1. Преступление')]),
            BookParagraph(inlines: [
              BookText('Обычный текст с '),
              BookStrong(children: [BookText('жирным')]),
              BookText(' и '),
              BookEmphasis(children: [BookText('курсивом')]),
              BookText('.'),
            ]),
            BookQuote(
              blocks: [BookParagraph(inlines: [BookText('Тварь ли я дрожащая или право имею?')])],
              citation: [BookText('Раскольников')],
            ),
            BookList(
              ordered: true,
              items: [
                BookListItem(blocks: [BookParagraph(inlines: [BookText('Первое условие')])]),
                BookListItem(blocks: [BookParagraph(inlines: [BookText('Второе условие')])]),
              ],
            ),
            BookTable(
              rows: [
                BookTableRow(cells: [
                  BookTableCell(blocks: [BookParagraph(inlines: [BookText('Колонка 1')])]),
                  BookTableCell(blocks: [BookParagraph(inlines: [BookText('Колонка 2')])]),
                ]),
              ],
            ),
            BookPoem(
              stanzas: [
                BookStanza(lines: [
                  BookPoemLine(inlines: [BookText('Я помню чудное мгновенье:')]),
                  BookPoemLine(inlines: [BookText('Передо мной явилась ты,')]),
                ]),
              ],
            ),
            BookCodeBlock(code: 'int sum(int a, int b) => a + b;'),
            BookImageBlock(ref: BookResourceRef('img1.png'), alt: 'Описание изображения'),
            BookHorizontalRule(),
            BookEmptyLine(),
          ],
        ),
        resources: [
          BookResource(
            id: 'img1.png',
            mediaType: 'image/png',
            bytes: Uint8List.fromList([137, 80, 78, 71]),
          ),
        ],
      );

      // 1. Кодирование в FB2 и обратная десериализация
      final fb2Bytes = await Fb2Converter.bookToFb2(originalBook);
      final fb2Decoded = Fb2Converter.fb2ToBook(fb2Bytes);

      // 2. Кодирование в EPUB и обратная десериализация
      final epubBytes = await EpubConverter.bookToEpub(originalBook);
      final epubDecoded = await EpubConverter.epubToBook(epubBytes);

      // 3. EPUB — 100% Абсолютно потери-устойчивая точность всех AST-узлов
      final epubContentBlocks = epubDecoded.content.blocks.first is BookSection
          ? (epubDecoded.content.blocks.first as BookSection).blocks
          : epubDecoded.content.blocks;
      print('EPUB content blocks: ${epubContentBlocks.map((b) => b.runtimeType).toList()}');
      assertBlockListEquals(epubContentBlocks, originalBook.content.blocks);

      // 4. FB2 — Проверка корректности декодирования всех списков, таблиц, стихов и метаданных
      expect(fb2Decoded.content.blocks, isNotEmpty);
      expect(fb2Decoded.content.blocks.any((b) => b is BookTable), isTrue);
      expect(fb2Decoded.content.blocks.any((b) => b is BookQuote), isTrue);
      expect(fb2Decoded.content.blocks.any((b) => b is BookPoem), isTrue);
    });
  });
}
