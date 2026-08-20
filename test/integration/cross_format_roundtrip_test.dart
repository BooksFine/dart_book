import 'dart:io';
import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';
import '../utils/ast_generator.dart';
import '../utils/golden_comparator.dart';

void main() {
  group('Cross-Format Roundtrip & Fixed-Point Idempotence Tests', () {
    test('Chain: EPUB -> Book -> FB2 -> Book -> EPUB with Calibre EPUB sample', () async {
      final epubFile = File('test/fixtures/epub/calibre_sample.epub');
      expect(epubFile.existsSync(), isTrue);

      // Iteration 1: EPUB -> Book1 -> FB2 -> BookFB2_1 -> EPUB -> BookEPUB_1
      final rawEpubBytes = epubFile.readAsBytesSync();
      final book1 = await DartBook.load(rawEpubBytes, filename: 'input.epub');
      expect(book1.metadata.title, isNotEmpty);

      final fb2Bytes1 = await Fb2Converter.bookToFb2(book1);
      final bookFb2_1 = await DartBook.load(fb2Bytes1, filename: 'converted1.fb2');
      expect(bookFb2_1.metadata.title, equals(book1.metadata.title));

      final epubBytes1 = await EpubConverter.bookToEpub(bookFb2_1);
      final bookEpub_1 = await DartBook.load(epubBytes1, filename: 'converted1.epub');
      expect(bookEpub_1.metadata.title, equals(book1.metadata.title));

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

      // Fixed-Point Idempotence Verification (AST stabilizes on 2nd and 3rd iterations)
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
    });

    test('Chain: FB2 -> Book -> EPUB -> Book -> FB2 with LitRes FB2 sample', () async {
      final fb2File = File('test/fixtures/fb2/litres_sample.fb2');
      expect(fb2File.existsSync(), isTrue);

      // Iteration 1: FB2 -> Book1 -> EPUB -> BookEPUB_1 -> FB2 -> BookFB2_1
      final rawFb2Bytes = fb2File.readAsBytesSync();
      final book1 = await DartBook.load(rawFb2Bytes, filename: 'litres.fb2');
      expect(book1.metadata.title, isNotEmpty);

      final epubBytes1 = await EpubConverter.bookToEpub(book1);
      final bookEpub_1 = await DartBook.load(epubBytes1, filename: 'converted1.epub');
      expect(bookEpub_1.metadata.title, equals(book1.metadata.title));

      final fb2Bytes1 = await Fb2Converter.bookToFb2(bookEpub_1);
      final bookFb2_1 = await DartBook.load(fb2Bytes1, filename: 'converted1.fb2');
      expect(bookFb2_1.metadata.title, equals(book1.metadata.title));

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

      // Fixed-Point Idempotence Verification (AST stabilizes on 2nd and 3rd iterations)
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
    });

    test('Chain: FB2 2.1 Sample -> EPUB -> FB2 -> EPUB -> FB2 (Fixed-Point Idempotence)', () async {
      final fb2File = File('test/fixtures/fb2/fb2_21_sample.fb2');
      expect(fb2File.existsSync(), isTrue);

      final rawFb2Bytes = fb2File.readAsBytesSync();
      final book1 = await DartBook.load(rawFb2Bytes, filename: 'fb2_21.fb2');

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
    });

    test('Complex Multi-Format Conversion with AstGenerator generated book', () async {
      final generator = AstGenerator(12345);
      final original = generator.generateBook(maxDepth: 2, blockCount: 6, includeResources: true);

      // Encode initial to EPUB
      final epubBytes0 = await EpubConverter.bookToEpub(original);
      final bookEpub0 = await DartBook.load(epubBytes0, filename: 'gen.epub');

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
    });
  });
}
