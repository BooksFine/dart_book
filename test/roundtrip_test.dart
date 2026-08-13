import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';

void main() {
  group('Roundtrip Conversion Tests', () {
    test('EPUB -> Book -> FB2 -> Book', () async {
      // 1. Create a base book
      final original = Book(
        metadata: const BookMetadata(
          id: 'roundtrip-1',
          title: 'Roundtrip Test Book',
          language: 'ru',
          contributors: [
            BookContributor(
              role: BookContributorRole.author,
              name: PersonName(first: 'Лев', last: 'Толстой', display: 'Лев Толстой'),
            ),
          ],
        ),
        content: const BookContent(
          blocks: [
            BookSection(
              title: [BookText('Глава 1')],
              blocks: [
                BookParagraph(inlines: [
                  BookText('Первый абзац с '),
                  BookEmphasis(children: [BookText('курсивом')]),
                  BookText('.'),
                ]),
              ],
            ),
          ],
        ),
        resources: const [],
      );

      // 2. Encode to EPUB
      final epubBytes = await EpubConverter.bookToEpub(original);

      // 3. Load EPUB using DartBook.load
      final epubBook = await DartBook.load(epubBytes, filename: 'input.epub');
      expect(epubBook.metadata.title, equals('Roundtrip Test Book'));

      // 4. Convert EPUB book model to FB2 bytes
      final fb2Bytes = await Fb2Converter.bookToFb2(epubBook);

      // 5. Load FB2 using DartBook.load
      final fb2Book = await DartBook.load(fb2Bytes, filename: 'converted.fb2');
      expect(fb2Book.metadata.title, equals('Roundtrip Test Book'));
      expect(fb2Book.content.blocks, isNotEmpty);
    });
  });
}
