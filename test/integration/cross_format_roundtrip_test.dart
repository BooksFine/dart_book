import 'dart:io';
import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';
import '../utils/ast_generator.dart';
import '../utils/golden_comparator.dart';

void main() {
  group('Cross-Format Roundtrip & Fixed-Point Idempotence Tests', () {
    test(
      'Chain: EPUB -> Book -> FB2 -> Book -> EPUB (Calibre sample with metadata & resources)',
      () async {
        final epubFile = File('test/fixtures/epub/calibre_sample.epub');
        expect(epubFile.existsSync(), isTrue);

        // Load original EPUB
        final rawEpubBytes = epubFile.readAsBytesSync();
        final book1 = await DartBook.load(rawEpubBytes, filename: 'input.epub');
        expect(book1.metadata.title, equals('Calibre Sample Book'));
        expect(book1.metadata.language, equals('en'));
        expect(book1.metadata.contributors, isNotEmpty);
        expect(book1.metadata.series, isNotEmpty);
        expect(book1.metadata.series.first.name, equals('Sherlock Holmes Collection'));
        expect(book1.metadata.series.first.number, equals(2));
        expect(book1.resources, isNotEmpty);

        // Iteration 1: EPUB -> FB2 -> EPUB
        final fb2Bytes1 = await Fb2Converter.bookToFb2(book1);
        final bookFb2_1 = await DartBook.load(fb2Bytes1, filename: 'converted1.fb2');
        expect(bookFb2_1.metadata.title, equals(book1.metadata.title));
        expect(bookFb2_1.metadata.language, equals(book1.metadata.language));
        expect(bookFb2_1.metadata.contributors.first.name.display, equals(book1.metadata.contributors.first.name.display));
        expect(bookFb2_1.metadata.series.first.name, equals(book1.metadata.series.first.name));
        expect(bookFb2_1.metadata.series.first.number, equals(book1.metadata.series.first.number));
        expect(bookFb2_1.resources.length, greaterThanOrEqualTo(1));

        final epubBytes1 = await EpubConverter.bookToEpub(bookFb2_1);
        final bookEpub_1 = await DartBook.load(epubBytes1, filename: 'converted1.epub');
        expect(bookEpub_1.metadata.title, equals(book1.metadata.title));
        expect(bookEpub_1.metadata.series.first.name, equals(book1.metadata.series.first.name));

        // Iteration 2: BookEPUB_1 -> FB2 -> BookFB2_2 -> EPUB -> BookEPUB_2
        final fb2Bytes2 = await Fb2Converter.bookToFb2(bookEpub_1);
        final bookFb2_2 = await DartBook.load(fb2Bytes2, filename: 'converted2.fb2');

        final epubBytes2 = await EpubConverter.bookToEpub(bookFb2_2);
        final bookEpub_2 = await DartBook.load(epubBytes2, filename: 'converted2.epub');

        // Iteration 3: BookEPUB_2 -> FB2 -> BookFB2_3 -> EPUB -> BookEPUB_3
        final fb2Bytes3 = await Fb2Converter.bookToFb2(bookEpub_2);
        final bookFb2_3 = await DartBook.load(fb2Bytes3, filename: 'converted3.fb2');

        final epubBytes3 = await EpubConverter.bookToEpub(bookFb2_3);
        final bookEpub_3 = await DartBook.load(epubBytes3, filename: 'converted3.epub');

        // Fixed-Point Idempotence: Content
        GoldenComparator.assertContentEquals(
          bookFb2_2.content,
          bookFb2_3.content,
          context: 'FB2 AST Idempotence in EPUB->FB2->EPUB Chain',
        );

        GoldenComparator.assertContentEquals(
          bookEpub_2.content,
          bookEpub_3.content,
          context: 'EPUB AST Idempotence in EPUB->FB2->EPUB Chain',
        );

        // Fixed-Point Idempotence: Metadata & Resources
        expect(bookFb2_2.metadata.title, equals(bookFb2_3.metadata.title));
        expect(bookFb2_2.metadata.language, equals(bookFb2_3.metadata.language));
        expect(bookFb2_2.metadata.series.first.name, equals(bookFb2_3.metadata.series.first.name));
        expect(bookFb2_2.metadata.series.first.number, equals(bookFb2_3.metadata.series.first.number));
        expect(bookFb2_2.resources.length, equals(bookFb2_3.resources.length));

        expect(bookEpub_2.metadata.title, equals(bookEpub_3.metadata.title));
        expect(bookEpub_2.metadata.series.first.name, equals(bookEpub_3.metadata.series.first.name));
        expect(bookEpub_2.resources.length, equals(bookEpub_3.resources.length));
      },
    );

    test(
      'Chain: FB2 -> Book -> EPUB -> Book -> FB2 (LitRes sample with metadata & resources)',
      () async {
        final fb2File = File('test/fixtures/fb2/litres_sample.fb2');
        expect(fb2File.existsSync(), isTrue);

        final rawFb2Bytes = fb2File.readAsBytesSync();
        final book1 = await DartBook.load(rawFb2Bytes, filename: 'litres.fb2');
        expect(book1.metadata.title, equals('Евгений Онегин и стихотворения'));
        expect(book1.metadata.contributors.first.name.display, equals('Александр Сергеевич Пушкин'));
        expect(book1.metadata.publishInfo?.publisher, equals('Издательство Литрес Эксмо'));
        expect(book1.metadata.publishInfo?.year, equals(2023));
        expect(book1.metadata.series.first.name, equals('Русская Классика'));
        expect(book1.metadata.cover, isNotNull);
        expect(book1.resources, isNotEmpty);

        // Iteration 1: FB2 -> EPUB -> FB2
        final epubBytes1 = await EpubConverter.bookToEpub(book1);
        final bookEpub_1 = await DartBook.load(epubBytes1, filename: 'converted1.epub');
        expect(bookEpub_1.metadata.title, equals(book1.metadata.title));
        expect(bookEpub_1.metadata.contributors.first.name.display, equals(book1.metadata.contributors.first.name.display));
        expect(bookEpub_1.metadata.series.first.name, equals(book1.metadata.series.first.name));
        expect(bookEpub_1.metadata.publishInfo?.publisher, equals(book1.metadata.publishInfo?.publisher));
        expect(bookEpub_1.resources, isNotEmpty);

        final fb2Bytes1 = await Fb2Converter.bookToFb2(bookEpub_1);
        final bookFb2_1 = await DartBook.load(fb2Bytes1, filename: 'converted1.fb2');
        expect(bookFb2_1.metadata.title, equals(book1.metadata.title));
        expect(bookFb2_1.metadata.series.first.name, equals(book1.metadata.series.first.name));
        expect(bookFb2_1.resources, isNotEmpty);

        // Iteration 2: BookFB2_1 -> EPUB -> BookEPUB_2 -> FB2 -> BookFB2_2
        final epubBytes2 = await EpubConverter.bookToEpub(bookFb2_1);
        final bookEpub_2 = await DartBook.load(epubBytes2, filename: 'converted2.epub');

        final fb2Bytes2 = await Fb2Converter.bookToFb2(bookEpub_2);
        final bookFb2_2 = await DartBook.load(fb2Bytes2, filename: 'converted2.fb2');

        // Iteration 3: BookFB2_2 -> EPUB -> BookEPUB_3 -> FB2 -> BookFB2_3
        final epubBytes3 = await EpubConverter.bookToEpub(bookFb2_2);
        final bookEpub_3 = await DartBook.load(epubBytes3, filename: 'converted3.epub');

        final fb2Bytes3 = await Fb2Converter.bookToFb2(bookEpub_3);
        final bookFb2_3 = await DartBook.load(fb2Bytes3, filename: 'converted3.fb2');

        // Fixed-Point Idempotence: Content
        GoldenComparator.assertContentEquals(
          bookFb2_2.content,
          bookFb2_3.content,
          context: 'FB2 AST Idempotence in FB2->EPUB->FB2 Chain (LitRes)',
        );

        GoldenComparator.assertContentEquals(
          bookEpub_2.content,
          bookEpub_3.content,
          context: 'EPUB AST Idempotence in FB2->EPUB->FB2 Chain (LitRes)',
        );

        // Fixed-Point Idempotence: Metadata & Resources
        expect(bookFb2_2.metadata.title, equals(bookFb2_3.metadata.title));
        expect(bookFb2_2.metadata.contributors.first.name.display, equals(bookFb2_3.metadata.contributors.first.name.display));
        expect(bookFb2_2.metadata.series.first.name, equals(bookFb2_3.metadata.series.first.name));
        expect(bookFb2_2.metadata.publishInfo?.publisher, equals(bookFb2_3.metadata.publishInfo?.publisher));
        expect(bookFb2_2.resources.length, equals(bookFb2_3.resources.length));

        expect(bookEpub_2.metadata.title, equals(bookEpub_3.metadata.title));
        expect(bookEpub_2.metadata.series.first.name, equals(bookEpub_3.metadata.series.first.name));
        expect(bookEpub_2.resources.length, equals(bookEpub_3.resources.length));
      },
    );

    test(
      'Chain: FB2 2.1 Sample -> EPUB -> FB2 -> EPUB -> FB2 (src-title-info & table attributes)',
      () async {
        final fb2File = File('test/fixtures/fb2/fb2_21_sample.fb2');
        expect(fb2File.existsSync(), isTrue);

        final rawFb2Bytes = fb2File.readAsBytesSync();
        final book1 = await DartBook.load(rawFb2Bytes, filename: 'fb2_21.fb2');
        expect(book1.metadata.title, equals('FB2 2.1 Specification Reference'));
        expect(book1.metadata.srcTitleInfo?.title, equals('Computing Machinery and Intelligence'));

        // Iteration 1
        final epubBytes1 = await EpubConverter.bookToEpub(book1);
        final bookEpub_1 = await DartBook.load(epubBytes1, filename: 'c1.epub');
        final fb2Bytes1 = await Fb2Converter.bookToFb2(bookEpub_1);
        final bookFb2_1 = await DartBook.load(fb2Bytes1, filename: 'c1.fb2');

        // Iteration 2
        final epubBytes2 = await EpubConverter.bookToEpub(bookFb2_1);
        final bookEpub_2 = await DartBook.load(epubBytes2, filename: 'c2.epub');
        final fb2Bytes2 = await Fb2Converter.bookToFb2(bookEpub_2);
        final bookFb2_2 = await DartBook.load(fb2Bytes2, filename: 'c2.fb2');

        // Iteration 3
        final epubBytes3 = await EpubConverter.bookToEpub(bookFb2_2);
        final bookEpub_3 = await DartBook.load(epubBytes3, filename: 'c3.epub');
        final fb2Bytes3 = await Fb2Converter.bookToFb2(bookEpub_3);
        final bookFb2_3 = await DartBook.load(fb2Bytes3, filename: 'c3.fb2');

        // Fixed-Point Idempotence Verification
        GoldenComparator.assertContentEquals(
          bookFb2_2.content,
          bookFb2_3.content,
          context: 'FB2 2.1 AST Idempotence (Iter 2 vs Iter 3)',
        );

        GoldenComparator.assertContentEquals(
          bookEpub_2.content,
          bookEpub_3.content,
          context: 'EPUB 2.1 AST Idempotence (Iter 2 vs Iter 3)',
        );

        expect(bookFb2_2.metadata.title, equals(bookFb2_3.metadata.title));
        expect(bookFb2_2.resources.length, equals(bookFb2_3.resources.length));
        expect(bookEpub_2.metadata.title, equals(bookEpub_3.metadata.title));
        expect(bookEpub_2.resources.length, equals(bookEpub_3.resources.length));
      },
    );

    test(
      'Complex Multi-Format Conversion with AstGenerator generated book (all 23 node types + resources)',
      () async {
        final generator = AstGenerator(12345);
        final original = generator.generateBook(
          maxDepth: 2,
          blockCount: 6,
          includeResources: true,
        );

        // Encode initial to EPUB
        final epubBytes0 = await EpubConverter.bookToEpub(original);
        final bookEpub0 = await DartBook.load(epubBytes0, filename: 'gen.epub');
        expect(bookEpub0.metadata.title, equals(original.metadata.title));
        expect(bookEpub0.resources, isNotEmpty);

        // Iteration 1: EPUB -> FB2 -> EPUB
        final fb2Bytes1 = await Fb2Converter.bookToFb2(bookEpub0);
        final bookFb2_1 = await DartBook.load(fb2Bytes1, filename: 'gen1.fb2');
        final epubBytes1 = await EpubConverter.bookToEpub(bookFb2_1);
        final bookEpub_1 = await DartBook.load(epubBytes1, filename: 'gen1.epub');

        // Iteration 2: EPUB -> FB2 -> EPUB
        final fb2Bytes2 = await Fb2Converter.bookToFb2(bookEpub_1);
        final bookFb2_2 = await DartBook.load(fb2Bytes2, filename: 'gen2.fb2');
        final epubBytes2 = await EpubConverter.bookToEpub(bookFb2_2);
        final bookEpub_2 = await DartBook.load(epubBytes2, filename: 'gen2.epub');

        // Iteration 3: EPUB -> FB2 -> EPUB
        final fb2Bytes3 = await Fb2Converter.bookToFb2(bookEpub_2);
        final bookFb2_3 = await DartBook.load(fb2Bytes3, filename: 'gen3.fb2');
        final epubBytes3 = await EpubConverter.bookToEpub(bookFb2_3);
        final bookEpub_3 = await DartBook.load(epubBytes3, filename: 'gen3.epub');

        // Fixed-Point Idempotence Verification
        GoldenComparator.assertContentEquals(
          bookFb2_2.content,
          bookFb2_3.content,
          context: 'Generated Book FB2 AST Idempotence (Iter 2 vs Iter 3)',
        );

        GoldenComparator.assertContentEquals(
          bookEpub_2.content,
          bookEpub_3.content,
          context: 'Generated Book EPUB AST Idempotence (Iter 2 vs Iter 3)',
        );

        expect(bookFb2_2.metadata.title, equals(bookFb2_3.metadata.title));
        expect(bookFb2_2.resources.length, equals(bookFb2_3.resources.length));
        expect(bookEpub_2.metadata.title, equals(bookEpub_3.metadata.title));
        expect(bookEpub_2.resources.length, equals(bookEpub_3.resources.length));
      },
    );
  });
}
