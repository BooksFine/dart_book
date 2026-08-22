import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';
import '../utils/golden_comparator.dart';

Uint8List packEpubDirectory(Directory dir) {
  final archive = Archive();
  final mimetypeFile = File('${dir.path}/mimetype');
  if (mimetypeFile.existsSync()) {
    final bytes = mimetypeFile.readAsBytesSync();
    archive.addFile(ArchiveFile.noCompress('mimetype', bytes.length, bytes));
  }
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File) {
      final relativePath = entity.path
          .substring(dir.path.length + 1)
          .replaceAll('\\', '/');
      if (relativePath == 'mimetype') continue;
      final bytes = entity.readAsBytesSync();
      archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
    }
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  group('EPUB Golden Master Integration Tests', () {
    test(
      'Parses Calibre EPUB 2 sample (calibre:series, toc.ncx, cover, AST, roundtrip) and matches Golden snapshot',
      () async {
        final file = File('test/fixtures/epub/calibre_sample.epub');
        expect(
          file.existsSync(),
          isTrue,
          reason: 'calibre_sample.epub fixture must exist',
        );

        final rawBytes = file.readAsBytesSync();
        final book = await DartBook.load(
          rawBytes,
          filename: 'calibre_sample.epub',
        );

        // 1. Verify Metadata
        expect(book.metadata.title, equals('Calibre Sample Book'));
        expect(book.metadata.language, equals('en'));
        expect(
          book.metadata.id,
          equals('urn:uuid:calibre-sample-epub2-uuid-98765'),
        );
        expect(
          book.metadata.publishInfo?.publisher,
          equals('Calibre Library Publishing'),
        );
        expect(book.metadata.publishInfo?.year, equals(2023));
        expect(
          book.metadata.genres.map((g) => g.code),
          containsAll(['Mystery', 'Detective']),
        );
        expect(book.metadata.annotation, isNotNull);

        // Author metadata
        expect(book.metadata.contributors, isNotEmpty);
        expect(
          book.metadata.contributors.first.name.display,
          equals('Arthur Conan Doyle'),
        );

        // Calibre Series extraction
        expect(book.metadata.series, isNotEmpty);
        expect(
          book.metadata.series.first.name,
          equals('Sherlock Holmes Collection'),
        );
        expect(book.metadata.series.first.number, equals(2));

        // Cover metadata & resource
        expect(book.metadata.cover, isNotNull);
        expect(book.metadata.cover!.ref.id, equals('epub-res-cover-img'));
        final coverRes = book.resources.firstWhere(
          (r) => r.id == 'epub-res-cover-img',
        );
        expect(coverRes.mediaType, equals('image/jpeg'));
        expect(coverRes.bytes, isNotEmpty);

        // Stylesheet resource
        final styleRes = book.resources.firstWhere(
          (r) => r.id == 'epub-res-style',
        );
        expect(styleRes.mediaType, equals('text/css'));
        expect(utf8.decode(styleRes.bytes), contains('font-family: serif'));

        // 2. Verify Key AST Nodes & TOC Chapter Titles from toc.ncx
        final sections = book.content.blocks.whereType<BookSection>().toList();
        expect(sections.length, equals(3));

        expect((sections[0].title.first as BookText).text, equals('Cover'));
        expect(
          (sections[1].title.first as BookText).text,
          equals('Chapter 1: The Adventure Begins'),
        );
        expect(
          (sections[2].title.first as BookText).text,
          equals('Chapter 2: The Clues'),
        );

        // Chapter 1 AST: Quote
        final chap1 = sections[1];
        expect(chap1.blocks.any((b) => b is BookHeading), isTrue);
        expect(chap1.blocks.any((b) => b is BookQuote), isTrue);
        final quote =
            chap1.blocks.firstWhere((b) => b is BookQuote) as BookQuote;
        final quoteP = quote.blocks.first as BookParagraph;
        expect(
          (quoteP.inlines.first as BookText).text,
          contains('When you have eliminated the impossible'),
        );

        // Chapter 2 AST: List
        final chap2 = sections[2];
        expect(chap2.blocks.any((b) => b is BookList), isTrue);
        final list = chap2.blocks.firstWhere((b) => b is BookList) as BookList;
        expect(list.items.length, equals(2));

        // 3. Golden Snapshot File Matching
        GoldenComparator.assertBookMatchesGoldenFile(
          book,
          'test/fixtures/golden/epub/calibre_sample.golden.json',

        );

        // 4. Lossless EPUB Roundtrip & Fixed-Point Idempotence
        final reEncodedEpub1 = await EpubConverter.bookToEpub(book);
        final reDecoded1 = await EpubConverter.epubToBook(reEncodedEpub1);
        expect(reDecoded1.metadata.title, equals(book.metadata.title));
        expect(
          reDecoded1.metadata.contributors.first.name.display,
          equals('Arthur Conan Doyle'),
        );
        expect(
          reDecoded1.metadata.series.first.name,
          equals('Sherlock Holmes Collection'),
        );
        expect(reDecoded1.metadata.series.first.number, equals(2));

        final reEncodedEpub2 = await EpubConverter.bookToEpub(reDecoded1);
        final reDecoded2 = await EpubConverter.epubToBook(reEncodedEpub2);
        GoldenComparator.assertContentEquals(
          reDecoded1.content,
          reDecoded2.content,
          context: 'Calibre EPUB Fixed-Point Roundtrip',
        );
      },
    );

    test(
      'Parses IDPF EPUB 3.0 Sample Book (accessible_epub_3) end-to-end',
      () async {
        final sampleDir = Directory(
          'test/fixtures/epub3-samples/30/accessible_epub_3',
        );
        expect(
          sampleDir.existsSync(),
          isTrue,
          reason: 'accessible_epub_3 sample folder must exist',
        );

        final epubBytes = packEpubDirectory(sampleDir);
        expect(epubBytes, isNotEmpty);

        final book = await DartBook.load(
          epubBytes,
          filename: 'accessible_epub_3.epub',
        );

        // Verify Metadata
        expect(book.metadata.title, equals('Accessible EPUB 3'));
        expect(book.metadata.language, equals('en'));
        expect(book.metadata.contributors, isNotEmpty);
        expect(
          book.metadata.contributors.first.name.display,
          equals('Matt Garrish'),
        );
        expect(book.metadata.cover, isNotNull);

        // Verify Chapters & Content Blocks
        expect(book.content.blocks, isNotEmpty);
        final sections = book.content.blocks.whereType<BookSection>().toList();
        expect(sections.length, equals(22));

        // Verify Resources (Fonts, Images, CSS)
        expect(book.resources, isNotEmpty);
        expect(
          book.resources.any((r) => r.mediaType.startsWith('image/')),
          isTrue,
        );
        expect(book.resources.any((r) => r.mediaType == 'text/css'), isTrue);
        expect(
          book.resources.any(
            (r) =>
                r.mediaType.contains('font') ||
                r.mediaType.contains('opentype'),
          ),
          isTrue,
        );

        // Verify AST roundtrip stability
        final reEncoded = await EpubConverter.bookToEpub(book);
        final reDecoded = await EpubConverter.epubToBook(reEncoded);
        expect(reDecoded.metadata.title, equals('Accessible EPUB 3'));
        expect(reDecoded.content.blocks.whereType<BookSection>().length, equals(22));
      },
    );

    test('Parses IDPF EPUB 3.0 Sample Book (moby-dick) end-to-end', () async {
      final sampleDir = Directory('test/fixtures/epub3-samples/30/moby-dick');
      expect(
        sampleDir.existsSync(),
        isTrue,
        reason: 'moby-dick sample folder must exist',
      );

      final epubBytes = packEpubDirectory(sampleDir);
      expect(epubBytes, isNotEmpty);

      final book = await DartBook.load(epubBytes, filename: 'moby-dick.epub');

      // Verify Metadata
      expect(book.metadata.title, equals('Moby-Dick'));
      expect(book.metadata.language, equals('en-US'));
      expect(
        book.metadata.contributors.first.name.display,
        equals('Herman Melville'),
      );

      // Verify 144 spine sections (136 chapters + frontmatter/epilogue)
      expect(book.content.blocks, isNotEmpty);
      final sections = book.content.blocks.whereType<BookSection>().toList();
      expect(sections.length, equals(144));

      // Verify first narrative chapter ("Chapter 1. Loomings" - "Call me Ishmael.")
      final chapter1 = sections.firstWhere((s) => s.id == 'xchapter_001');
      expect(chapter1.title.first, isA<BookText>());
      expect((chapter1.title.first as BookText).text, contains('Chapter 1'));
      String extractAllText(BookBlock block) {
        if (block is BookParagraph) {
          return block.inlines.whereType<BookText>().map((t) => t.text).join(' ');
        } else if (block is BookSection) {
          return block.blocks.map(extractAllText).join(' ');
        }
        return '';
      }
      final chapter1Text = chapter1.blocks.map(extractAllText).join(' ');
      expect(chapter1Text, contains('Call me Ishmael'));
    });
  });
}
