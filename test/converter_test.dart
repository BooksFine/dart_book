import 'dart:typed_data';
import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';

void main() {
  final sampleBook = Book(
    metadata: const BookMetadata(
      id: 'test-book-1',
      title: 'Test Book Title',
      language: 'ru',
      contributors: [
        BookContributor(
          role: BookContributorRole.author,
          name: PersonName(first: 'Антон', last: 'Чехов', display: 'Антон Чехов'),
        ),
      ],
      genres: [BookGenre(code: 'prose_classic', name: 'Классика')],
      cover: BookCover(ref: BookResourceRef('cover.jpg')),
    ),
    content: const BookContent(
      blocks: [
        BookHeading(level: 1, text: [BookText('Глава 1')]),
        BookParagraph(inlines: [
          BookText('Это '),
          BookStrong(children: [BookText('важный')]),
          BookText(' текст с '),
          BookCodeSpan('var x = 42;'),
          BookText('.'),
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
      BookResource(
        id: 'audio1.mp3',
        mediaType: 'audio/mpeg',
        bytes: Uint8List.fromList([10, 20, 30]),
      ),
    ],
  );

  group('FB2 Converter Tests', () {
    test('Encodes and decodes FB2 maintaining metadata and content', () async {
      final bytes = await Fb2Converter.bookToFb2(sampleBook);
      expect(bytes, isNotEmpty);

      final xmlString = String.fromCharCodes(bytes);
      expect(xmlString, contains('<code>var x = 42;</code>'));

      final decoded = Fb2Converter.fb2ToBook(bytes);
      expect(decoded.metadata.title, equals('Test Book Title'));
      expect(decoded.metadata.language, equals('ru'));
      expect(decoded.metadata.contributors.length, equals(1));
      expect(decoded.metadata.contributors.first.name.display, equals('Антон Чехов'));
      expect(decoded.resources.length, equals(2));
      expect(decoded.resources.first.id, equals('cover.jpg'));
      expect(decoded.resources.first.bytes, equals([1, 2, 3, 4, 5]));
      expect(decoded.metadata.cover, isNotNull);
      expect(decoded.metadata.cover!.ref.id, equals('cover.jpg'));
    });
  });

  group('EPUB Converter Tests', () {
    test('Encodes and decodes EPUB maintaining metadata, cover, audio and content', () async {
      final bytes = await EpubConverter.bookToEpub(sampleBook);
      expect(bytes, isNotEmpty);

      final decoded = await EpubConverter.epubToBook(bytes);
      expect(decoded.metadata.id, equals('test-book-1'));
      expect(decoded.metadata.title, equals('Test Book Title'));
      expect(decoded.metadata.language, equals('ru'));
      expect(decoded.metadata.contributors.length, equals(1));
      expect(decoded.resources.length, equals(2));
      expect(decoded.metadata.cover, isNotNull);

      // Verify audio extraction in resources
      final audioRes = decoded.resources.firstWhere((r) => r.mediaType == 'audio/mpeg');
      expect(audioRes.bytes, equals([10, 20, 30]));
    });

    test('EpubException extends BookException', () {
      final exc = EpubInvalidPackageException('Corrupt OPF');
      expect(exc, isA<BookException>());
      expect(exc, isA<EpubException>());
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
