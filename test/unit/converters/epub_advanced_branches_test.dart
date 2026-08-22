import 'dart:typed_data';
import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';

void main() {
  group('EPUB Advanced Branches & Multimedia Codec Tests', () {
    test('EpubEncoder handles Audio, Video, MathML, SVG and Layouts in XHTML and OPF', () async {
      final audioRes = BookResource(
        id: 'track1.mp3',
        mediaType: 'audio/mpeg',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
      );
      final videoRes = BookResource(
        id: 'clip1.mp4',
        mediaType: 'video/mp4',
        bytes: Uint8List.fromList([5, 6, 7, 8]),
      );
      final posterRes = BookResource(
        id: 'poster.jpg',
        mediaType: 'image/jpeg',
        bytes: Uint8List.fromList([9, 10, 11]),
      );
      final avifRes = BookResource(
        id: 'pic.avif',
        mediaType: 'image/avif',
        bytes: Uint8List.fromList([12, 13]),
      );
      final jxlRes = BookResource(
        id: 'pic.jxl',
        mediaType: 'image/jxl',
        bytes: Uint8List.fromList([14, 15]),
      );
      final woff2Res = BookResource(
        id: 'font.woff2',
        mediaType: 'font/woff2',
        bytes: Uint8List.fromList([16, 17]),
      );
      final opusRes = BookResource(
        id: 'audio.opus',
        mediaType: 'audio/opus',
        bytes: Uint8List.fromList([18, 19]),
      );
      final otfRes = BookResource(
        id: 'font.otf',
        mediaType: 'font/otf',
        bytes: Uint8List.fromList([20, 21]),
      );
      final gifRes = BookResource(
        id: 'anim.gif',
        mediaType: 'image/gif',
        bytes: Uint8List.fromList([22, 23]),
      );

      final book = Book(
        metadata: const BookMetadata(
          id: 'multimedia-book-1',
          title: 'Multimedia & Interactive Book',
          language: 'ru',
          layout: BookLayout.roll,
          cover: BookCover(ref: BookResourceRef('poster.jpg')),
        ),
        content: const BookContent(
          blocks: [
            BookSection(
              title: [
                BookText('Глава 1. '),
                BookStrong(children: [BookText('Жирный ')]),
                BookEmphasis(children: [BookText('Курсив ')]),
                BookStrike(children: [BookText('Зачеркнутый ')]),
                BookSuperscript(children: [BookText('2')]),
                BookSubscript(children: [BookText('0')]),
              ],
              blocks: [
                BookParagraph(
                  inlines: [
                    BookLineBreak(),
                    BookCodeSpan('final int x = 42;'),
                    BookNamedStyle(name: 'custom', inlines: [BookText('Стиль')]),
                    BookAnchor('sec1_anchor'),
                    BookFootnoteRef(id: 'fn_1', label: [BookText('1')]),
                    BookImageInline(ref: BookResourceRef('pic.avif')),
                    BookImageInline(ref: BookResourceRef('pic.jxl')),
                    BookImageInline(ref: BookResourceRef('anim.gif')),
                  ],
                ),
                BookAudioBlock(
                  ref: BookResourceRef('track1.mp3'),
                  controls: true,
                ),
                BookAudioBlock(
                  ref: BookResourceRef('audio.opus'),
                  controls: false,
                ),
                BookVideoBlock(
                  ref: BookResourceRef('clip1.mp4'),
                  posterRef: BookResourceRef('poster.jpg'),
                  controls: true,
                ),
                BookMathBlock(
                  mathml: '<math xmlns="http://www.w3.org/1998/Math/MathML"><mi>E</mi><mo>=</mo><mi>m</mi><msup><mi>c</mi><mn>2</mn></msup></math>',
                ),
                BookSvgBlock(
                  svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10"/></svg>',
                ),
                BookHorizontalRule(),
                BookEmptyLine(),
                BookCodeBlock(code: 'print("hello");', language: 'dart'),
                BookRawHtmlBlock('<div class="raw-box">Raw HTML</div>'),
                BookRawXmlBlock('<custom-tag>Raw XML</custom-tag>'),
              ],
            ),
          ],
        ),
        resources: [
          audioRes,
          videoRes,
          posterRes,
          avifRes,
          jxlRes,
          woff2Res,
          opusRes,
          otfRes,
          gifRes,
        ],
      );

      final epubBytes = await EpubConverter.bookToEpub(
        book,
        options: const BookEncodingOptions(
          documentId: 'custom-doc-id-999',
          coverFilename: 'my_cover.jpeg',
          namingPolicy: BookResourceNamingPolicy.sequential,
        ),
      );
      expect(epubBytes, isNotEmpty);

      final decoded = await EpubConverter.epubToBook(epubBytes);
      expect(decoded.metadata.title, equals(book.metadata.title));
      expect(decoded.resources, isNotEmpty);
      expect(decoded.metadata.layout, equals(BookLayout.roll));

      final sec = decoded.content.blocks.firstWhere((b) => b is BookSection) as BookSection;
      expect(sec.blocks.any((b) => b is BookAudioBlock), isTrue);
      expect(sec.blocks.any((b) => b is BookVideoBlock), isTrue);
      expect(sec.blocks.any((b) => b is BookMathBlock), isTrue);
      expect(sec.blocks.any((b) => b is BookSvgBlock), isTrue);
    });

    test('EpubConverter handles fixed-layout and custom naming policies', () async {
      final book = const Book(
        metadata: BookMetadata(
          id: 'fixed-book',
          title: 'Fixed Layout Book',
          language: 'en',
          layout: BookLayout.fixedLayout,
        ),
        content: BookContent(
          blocks: [
            BookParagraph(inlines: [BookText('Fixed layout page')]),
          ],
        ),
        resources: [],
      );

      final epubBytes = await EpubConverter.bookToEpub(
        book,
        options: const BookEncodingOptions(
          namingPolicy: BookResourceNamingPolicy.hash,
        ),
      );
      final decoded = await EpubConverter.epubToBook(epubBytes);
      expect(decoded.metadata.layout, equals(BookLayout.fixedLayout));
    });

    test('EpubConverter & Fb2Converter helper methods work synchronously and asynchronously', () async {
      final book = const Book(
        metadata: BookMetadata(
          id: 'helper-book',
          title: 'Helper Book',
          language: 'en',
        ),
        content: BookContent(
          blocks: [
            BookParagraph(inlines: [BookText('Hello world')]),
          ],
        ),
        resources: [],
      );

      // EPUB Converter static methods
      final epubBytes = await EpubConverter.bookToEpub(book);
      final epubDecoded = await EpubConverter.epubToBook(epubBytes);
      expect(epubDecoded.metadata.title, equals('Helper Book'));

      // FB2 Converter static methods
      final fb2Bytes = await Fb2Converter.bookToFb2(book);
      final fb2Decoded = Fb2Converter.fb2ToBook(fb2Bytes);
      expect(fb2Decoded.metadata.title, equals('Helper Book'));

      // Registry
      expect(BookRegistry.findEncoder('epub'), isNotNull);
      expect(BookRegistry.findEncoder('.epub'), isNotNull);
      expect(BookRegistry.findEncoder('fb2'), isNotNull);
      expect(BookRegistry.findEncoder('fb2.zip'), isNotNull);
      expect(BookRegistry.findEncoder('unknown_ext'), isNull);
    });
  });
}
