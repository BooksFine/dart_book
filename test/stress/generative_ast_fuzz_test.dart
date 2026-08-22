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
      '50 mutated/corrupted byte streams never cause unhandled TypeError, RangeError, or StackOverflowError',
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
          } on TypeError catch (e) {
            fail(
              'Unhandled TypeError in DartBook.load (EPUB) for length $length: $e',
            );
          } on RangeError catch (e) {
            fail(
              'Unhandled RangeError in DartBook.load (EPUB) for length $length: $e',
            );
          } on StackOverflowError catch (e) {
            fail(
              'Unhandled StackOverflowError in DartBook.load (EPUB) for length $length: $e',
            );
          } catch (_) {
            // Cleanly caught exception
          }

          try {
            await DartBook.load(bytes, filename: 'fuzz_$i.fb2');
          } on TypeError catch (e) {
            fail(
              'Unhandled TypeError in DartBook.load (FB2) for length $length: $e',
            );
          } on RangeError catch (e) {
            fail(
              'Unhandled RangeError in DartBook.load (FB2) for length $length: $e',
            );
          } on StackOverflowError catch (e) {
            fail(
              'Unhandled StackOverflowError in DartBook.load (FB2) for length $length: $e',
            );
          } catch (_) {
            // Cleanly caught exception
          }

          // 2. EpubDecoder
          try {
            if (EpubDecoder().canDecode(bytes)) {
              await EpubDecoder().decode(bytes);
            }
          } on TypeError catch (e) {
            fail('Unhandled TypeError in EpubDecoder for length $length: $e');
          } on RangeError catch (e) {
            fail('Unhandled RangeError in EpubDecoder for length $length: $e');
          } on StackOverflowError catch (e) {
            fail(
              'Unhandled StackOverflowError in EpubDecoder for length $length: $e',
            );
          } catch (_) {
            // Cleanly caught exception
          }

          // 3. Fb2Decoder
          try {
            Fb2Decoder().decode(bytes);
          } on TypeError catch (e) {
            fail('Unhandled TypeError in Fb2Decoder for length $length: $e');
          } on RangeError catch (e) {
            fail('Unhandled RangeError in Fb2Decoder for length $length: $e');
          } on StackOverflowError catch (e) {
            fail(
              'Unhandled StackOverflowError in Fb2Decoder for length $length: $e',
            );
          } catch (_) {
            // Cleanly caught exception
          }

          // 4. Fb2ZipDecoder
          try {
            Fb2ZipDecoder().decode(bytes);
          } on TypeError catch (e) {
            fail('Unhandled TypeError in Fb2ZipDecoder for length $length: $e');
          } on RangeError catch (e) {
            fail(
              'Unhandled RangeError in Fb2ZipDecoder for length $length: $e',
            );
          } on StackOverflowError catch (e) {
            fail(
              'Unhandled StackOverflowError in Fb2ZipDecoder for length $length: $e',
            );
          } catch (_) {
            // Cleanly caught exception
          }

          // 5. HtmlParser & Fb2Parser
          try {
            HtmlParser().parseFromString(asString);
          } on TypeError catch (e) {
            fail('Unhandled TypeError in HtmlParser for length $length: $e');
          } on RangeError catch (e) {
            fail('Unhandled RangeError in HtmlParser for length $length: $e');
          } on StackOverflowError catch (e) {
            fail(
              'Unhandled StackOverflowError in HtmlParser for length $length: $e',
            );
          } catch (_) {
            // Cleanly caught exception
          }

          try {
            Fb2Parser().parseFromString(asString);
          } on TypeError catch (e) {
            fail('Unhandled TypeError in Fb2Parser for length $length: $e');
          } on RangeError catch (e) {
            fail('Unhandled RangeError in Fb2Parser for length $length: $e');
          } on StackOverflowError catch (e) {
            fail(
              'Unhandled StackOverflowError in Fb2Parser for length $length: $e',
            );
          } catch (_) {
            // Cleanly caught exception
          }

          // 6. EpubNavDocument & EpubNcxDocument
          try {
            EpubNavDocument.parseFromString(asString);
          } on TypeError catch (e) {
            fail(
              'Unhandled TypeError in EpubNavDocument for length $length: $e',
            );
          } on RangeError catch (e) {
            fail(
              'Unhandled RangeError in EpubNavDocument for length $length: $e',
            );
          } on StackOverflowError catch (e) {
            fail(
              'Unhandled StackOverflowError in EpubNavDocument for length $length: $e',
            );
          } catch (_) {
            // Cleanly caught exception
          }

          try {
            EpubNcxDocument.parseFromString(asString);
          } on TypeError catch (e) {
            fail(
              'Unhandled TypeError in EpubNcxDocument for length $length: $e',
            );
          } on RangeError catch (e) {
            fail(
              'Unhandled RangeError in EpubNcxDocument for length $length: $e',
            );
          } on StackOverflowError catch (e) {
            fail(
              'Unhandled StackOverflowError in EpubNcxDocument for length $length: $e',
            );
          } catch (_) {
            // Cleanly caught exception
          }
        }
      },
    );
  });
}
