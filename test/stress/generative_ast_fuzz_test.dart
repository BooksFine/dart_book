import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';
import '../utils/ast_generator.dart';
import '../utils/ast_normalizer.dart';
import '../utils/golden_comparator.dart';

void main() {
  group('Stress: Generative AST Property-Based Fuzzing', () {
    test(
      '50 randomly generated AST books roundtrip through EPUB with AST normalization',
      () async {
        final generator = AstGenerator(2026);

        for (var i = 0; i < 50; i++) {
          final originalBook = generator.generateBook(
            maxDepth: 2,
            blockCount: 4,
            includeResources: false,
          );

          // Roundtrip: Book -> EPUB -> Book
          final epubBytes = await EpubConverter.bookToEpub(originalBook);
          expect(epubBytes, isNotEmpty);

          final decodedBook = await EpubConverter.epubToBook(epubBytes);
          expect(
            decodedBook.metadata.title,
            equals(originalBook.metadata.title),
          );

          final normDecoded = AstNormalizer.normalizeBook(decodedBook);

          // Fixed-point idempotence check on content
          final reEncodedEpub = await EpubConverter.bookToEpub(decodedBook);
          final reDecodedBook = await EpubConverter.epubToBook(reEncodedEpub);
          final normReDecoded = AstNormalizer.normalizeBook(reDecodedBook);

          GoldenComparator.assertContentEquals(
            normReDecoded.content,
            normDecoded.content,
            context: 'EPUB Generative Fuzz iteration $i',
          );
        }
      },
    );

    test(
      '50 randomly generated AST books roundtrip through FB2 with structure verification',
      () async {
        final generator = AstGenerator(4242);

        for (var i = 0; i < 50; i++) {
          final originalBook = generator.generateBook(
            maxDepth: 2,
            blockCount: 4,
            includeResources: false,
          );

          final fb2Bytes = await Fb2Converter.bookToFb2(originalBook);
          expect(fb2Bytes, isNotEmpty);

          final decodedBook = Fb2Converter.fb2ToBook(fb2Bytes);
          expect(
            decodedBook.metadata.title,
            equals(originalBook.metadata.title),
          );
          expect(decodedBook.content.blocks, isNotEmpty);

          // Verify that re-encoding decoded book is stable (fixed-point idempotence)
          final reEncodedFb2 = await Fb2Converter.bookToFb2(decodedBook);
          final reDecodedBook = Fb2Converter.fb2ToBook(reEncodedFb2);

          final norm1 = AstNormalizer.normalizeBook(decodedBook);
          final norm2 = AstNormalizer.normalizeBook(reDecodedBook);

          GoldenComparator.assertContentEquals(
            norm2.content,
            norm1.content,
            context: 'FB2 Generative Fuzz iteration $i',
          );
        }
      },
    );
  });

  group('Stress: Crash-Free Invariant on Corrupted Byte Streams', () {
    test(
      '50 mutated/corrupted byte streams never cause unhandled Errors (StateError, ArgumentError, TypeError, RangeError, StackOverflowError)',
      () async {
        final generator = AstGenerator(9999);
        final testLengths = [
          0,
          1,
          2,
          3,
          4,
          8,
          16,
          32,
          57,
          58,
          64,
          100,
          128,
          256,
          512,
          1024,
          2048,
          4096,
          8192,
          16384,
        ];

        for (var i = 0; i < 50; i++) {
          final length = testLengths[i % testLengths.length];
          final bytes = generator.generateCorruptedBytes(length);
          final asString = String.fromCharCodes(bytes);

          // 1. DartBook.load
          try {
            await DartBook.load(bytes, filename: 'fuzz_$i.epub');
          } on Error catch (e, st) {
            fail(
              'Unhandled Error in DartBook.load (EPUB) for length $length: $e\n$st',
            );
          } on Exception catch (_) {
            // Expected exception cleanly handled
          }

          try {
            await DartBook.load(bytes, filename: 'fuzz_$i.fb2');
          } on Error catch (e, st) {
            fail(
              'Unhandled Error in DartBook.load (FB2) for length $length: $e\n$st',
            );
          } on Exception catch (_) {
            // Expected exception cleanly handled
          }

          // 2. EpubDecoder direct decode
          try {
            await EpubDecoder().decode(bytes);
          } on Error catch (e, st) {
            fail('Unhandled Error in EpubDecoder for length $length: $e\n$st');
          } on Exception catch (_) {
            // Expected exception cleanly handled
          }

          // 3. Fb2Decoder
          try {
            Fb2Decoder().decode(bytes);
          } on Error catch (e, st) {
            fail('Unhandled Error in Fb2Decoder for length $length: $e\n$st');
          } on Exception catch (_) {
            // Expected exception cleanly handled
          }

          // 4. Fb2ZipDecoder
          try {
            Fb2ZipDecoder().decode(bytes);
          } on Error catch (e, st) {
            fail(
              'Unhandled Error in Fb2ZipDecoder for length $length: $e\n$st',
            );
          } on Exception catch (_) {
            // Expected exception cleanly handled
          }

          // 5. HtmlParser & Fb2Parser
          try {
            HtmlParser().parseFromString(asString);
          } on Error catch (e, st) {
            fail('Unhandled Error in HtmlParser for length $length: $e\n$st');
          } on Exception catch (_) {
            // Expected exception cleanly handled
          }

          try {
            Fb2Parser().parseFromString(asString);
          } on Error catch (e, st) {
            fail('Unhandled Error in Fb2Parser for length $length: $e\n$st');
          } on Exception catch (_) {
            // Expected exception cleanly handled
          }

          // 6. EpubNavDocument & EpubNcxDocument
          try {
            EpubNavDocument.parseFromString(asString);
          } on Error catch (e, st) {
            fail(
              'Unhandled Error in EpubNavDocument for length $length: $e\n$st',
            );
          } on Exception catch (_) {
            // Expected exception cleanly handled
          }

          try {
            EpubNcxDocument.parseFromString(asString);
          } on Error catch (e, st) {
            fail(
              'Unhandled Error in EpubNcxDocument for length $length: $e\n$st',
            );
          } on Exception catch (_) {
            // Expected exception cleanly handled
          }
        }
      },
    );
  });
}
