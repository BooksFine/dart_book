import 'dart:typed_data';
import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';

void main() {
  final sampleBook = Book(
    id: 'test-book-1',
    metadata: const BookMetadata(
      title: 'Test Book Title',
      language: 'ru',
      contributors: [
        BookContributor(
          role: BookContributorRole.author,
          name: PersonName(first: 'Антон', last: 'Чехов', display: 'Антон Чехов'),
        ),
      ],
      genres: [BookGenre(code: 'prose_classic', name: 'Классика')],
    ),
    content: const BookContent(
      blocks: [
        BookHeading(level: 1, text: [BookText('Глава 1')]),
        BookParagraph(inlines: [
          BookText('Это '),
          BookStrong(children: [BookText('важный')]),
          BookText(' текст.'),
        ]),
        BookQuote(
          blocks: [BookParagraph(inlines: [BookText('Краткость — сестра таланта.')])],
          citation: [BookText('А.П. Чехов')],
        ),
        BookList(
          ordered: false,
          items: [
            BookListItem(blocks: [BookParagraph(inlines: [BookText('Пункт 1')])]),
            BookListItem(blocks: [BookParagraph(inlines: [BookText('Пункт 2')])]),
          ],
        ),
      ],
    ),
    resources: [
      BookResource(
        id: 'cover.jpg',
        mediaType: 'image/jpeg',
        bytes: Uint8List.fromList([1, 2, 3, 4, 5]),
      ),
    ],
  );

  group('FB2 Converter Tests', () {
    test('Encodes and decodes FB2 maintaining metadata and content', () async {
      final bytes = await Fb2Converter.bookToFb2(sampleBook);
      expect(bytes, isNotEmpty);

      final decoded = Fb2Converter.fb2ToBook(bytes);
      expect(decoded.metadata.title, equals('Test Book Title'));
      expect(decoded.metadata.language, equals('ru'));
      expect(decoded.metadata.contributors.length, equals(1));
      expect(decoded.metadata.contributors.first.name.display, equals('Антон Чехов'));
      expect(decoded.resources.length, equals(1));
      expect(decoded.resources.first.id, equals('cover.jpg'));
      expect(decoded.resources.first.bytes, equals([1, 2, 3, 4, 5]));
    });
  });

  group('EPUB Converter Tests', () {
    test('Encodes and decodes EPUB maintaining metadata and content', () async {
      final bytes = await EpubConverter.bookToEpub(sampleBook);
      expect(bytes, isNotEmpty);

      final decoded = await EpubConverter.epubToBook(bytes);
      expect(decoded.id, equals('test-book-1'));
      expect(decoded.metadata.title, equals('Test Book Title'));
      expect(decoded.metadata.language, equals('ru'));
      expect(decoded.metadata.contributors.length, equals(1));
      expect(decoded.resources.length, equals(1));
    });
  });

  group('BookRegistry Tests', () {
    test('Finds correct decoder based on extension and bytes signature', () async {
      final fb2Bytes = await Fb2Converter.bookToFb2(sampleBook);
      final epubBytes = await EpubConverter.bookToEpub(sampleBook);

      final fb2DecoderExt = BookRegistry.findDecoder(fb2Bytes, extension: 'fb2');
      expect(fb2DecoderExt, isA<Fb2Decoder>());

      final fb2DecoderBytes = BookRegistry.findDecoder(fb2Bytes);
      expect(fb2DecoderBytes, isA<Fb2Decoder>());

      final epubDecoderExt = BookRegistry.findDecoder(epubBytes, extension: 'epub');
      expect(epubDecoderExt, isA<EpubDecoder>());

      final epubDecoderBytes = BookRegistry.findDecoder(epubBytes);
      expect(epubDecoderBytes, isA<EpubDecoder>());
    });
  });
}
