import 'dart:typed_data';
import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';

void main() {
  group('Book Models Unit Tests', () {
    group('1. Freezed Models Immutability and copyWith()', () {
      test('BookMetadata is immutable and copyWith creates a new instance with updated fields', () {
        const originalMeta = BookMetadata(
          id: 'meta-001',
          title: 'Original Title',
          language: 'ru',
          isFinished: true,
          textLength: 100000,
          genres: [BookGenre(code: 'sf_fantasy', name: 'Фантастика')],
          series: [BookSeries(name: 'Трилогия', number: 1)],
          publishInfo: BookPublishInfo(publisher: 'Эксмо', year: 2024),
          layout: BookLayout.reflowable,
        );

        final updatedMeta = originalMeta.copyWith(
          title: 'Updated Title',
          isFinished: false,
          textLength: 120000,
          layout: BookLayout.fixedLayout,
        );

        // Original object remains unchanged
        expect(originalMeta.title, equals('Original Title'));
        expect(originalMeta.isFinished, isTrue);
        expect(originalMeta.textLength, equals(100000));
        expect(originalMeta.layout, equals(BookLayout.reflowable));

        // New object has updated fields and retains untouched fields
        expect(updatedMeta.title, equals('Updated Title'));
        expect(updatedMeta.id, equals('meta-001'));
        expect(updatedMeta.language, equals('ru'));
        expect(updatedMeta.isFinished, isFalse);
        expect(updatedMeta.textLength, equals(120000));
        expect(updatedMeta.layout, equals(BookLayout.fixedLayout));
        expect(updatedMeta.genres.first.code, equals('sf_fantasy'));
        expect(updatedMeta.series.first.name, equals('Трилогия'));
        expect(updatedMeta.publishInfo?.publisher, equals('Эксмо'));
      });

      test('BookPublishInfo is immutable and copyWith updates fields correctly', () {
        const originalInfo = BookPublishInfo(
          publisher: 'АСТ',
          city: 'Москва',
          year: 2020,
          isbn: '978-5-17-123456-7',
        );

        final updatedInfo = originalInfo.copyWith(
          year: 2026,
          city: 'Санкт-Петербург',
        );

        expect(originalInfo.year, equals(2020));
        expect(originalInfo.city, equals('Москва'));
        expect(updatedInfo.year, equals(2026));
        expect(updatedInfo.city, equals('Санкт-Петербург'));
        expect(updatedInfo.publisher, equals('АСТ'));
        expect(updatedInfo.isbn, equals('978-5-17-123456-7'));
      });

      test('BookSourceTitleInfo is immutable and copyWith updates fields correctly', () {
        const originalSrc = BookSourceTitleInfo(
          title: 'Original English Title',
          language: 'en',
          authors: [
            BookContributor(
              role: BookContributorRole.author,
              name: PersonName(first: 'John', last: 'Doe'),
            ),
          ],
        );

        final updatedSrc = originalSrc.copyWith(
          title: 'Title in French',
          language: 'fr',
        );

        expect(originalSrc.title, equals('Original English Title'));
        expect(originalSrc.language, equals('en'));
        expect(updatedSrc.title, equals('Title in French'));
        expect(updatedSrc.language, equals('fr'));
        expect(updatedSrc.authors.length, equals(1));
        expect(updatedSrc.authors.first.name.last, equals('Doe'));
      });

      test('BookSeries is immutable and copyWith updates number and URL', () {
        const originalSeries = BookSeries(
          name: 'Властелин Колец',
          number: 1,
        );

        final updatedSeries = originalSeries.copyWith(
          number: 2,
          url: Uri.parse('https://lotr.fandom.com/wiki/The_Two_Towers'),
        );

        expect(originalSeries.number, equals(1));
        expect(originalSeries.url, isNull);
        expect(updatedSeries.name, equals('Властелин Колец'));
        expect(updatedSeries.number, equals(2));
        expect(updatedSeries.url, equals(Uri.parse('https://lotr.fandom.com/wiki/The_Two_Towers')));
      });

      test('Book root model is immutable and copyWith updates metadata and content', () {
        const originalBook = Book(
          metadata: BookMetadata(id: 'b1', title: 'Book 1', language: 'ru'),
          content: BookContent(),
          resources: [],
        );

        final updatedBook = originalBook.copyWith(
          metadata: originalBook.metadata.copyWith(title: 'Book 1 - Revised'),
        );

        expect(originalBook.metadata.title, equals('Book 1'));
        expect(updatedBook.metadata.title, equals('Book 1 - Revised'));
      });
    });

    group('2. Deep Value Equality and HashCode', () {
      test('Identical BookMetadata instances evaluate to equal with identical hashCode', () {
        const meta1 = BookMetadata(
          id: 'meta-eq',
          title: 'Равенство',
          language: 'ru',
          contributors: [
            BookContributor(
              role: BookContributorRole.author,
              name: PersonName(first: 'Лев', last: 'Толстой'),
            ),
          ],
          genres: [BookGenre(code: 'classic', name: 'Классика')],
          series: [BookSeries(name: 'Золотой фонд', number: 5)],
          keywords: ['литература', 'классика'],
        );

        const meta2 = BookMetadata(
          id: 'meta-eq',
          title: 'Равенство',
          language: 'ru',
          contributors: [
            BookContributor(
              role: BookContributorRole.author,
              name: PersonName(first: 'Лев', last: 'Толстой'),
            ),
          ],
          genres: [BookGenre(code: 'classic', name: 'Классика')],
          series: [BookSeries(name: 'Золотой фонд', number: 5)],
          keywords: ['литература', 'классика'],
        );

        expect(meta1, equals(meta2));
        expect(meta1.hashCode, equals(meta2.hashCode));

        final metaDifferent = meta1.copyWith(isFinished: false);
        expect(meta1, isNot(equals(metaDifferent)));
      });

      test('BookResource byte comparison and equality', () {
        final res1 = BookResource(
          id: 'img1.png',
          mediaType: 'image/png',
          bytes: Uint8List.fromList([1, 2, 3, 4]),
        );

        final res2 = BookResource(
          id: 'img1.png',
          mediaType: 'image/png',
          bytes: Uint8List.fromList([1, 2, 3, 4]),
        );

        final res3 = BookResource(
          id: 'img1.png',
          mediaType: 'image/png',
          bytes: Uint8List.fromList([1, 2, 3, 5]),
        );

        expect(res1, equals(res2));
        expect(res1.hashCode, equals(res2.hashCode));
        expect(res1, isNot(equals(res3)));
      });
    });

    group('3. Model Helper Methods and Logic', () {
      test('BookMetadata primarySeries returns the first series or null', () {
        const metaWithSeries = BookMetadata(
          id: 'm1',
          title: 'T',
          language: 'ru',
          series: [
            BookSeries(name: 'Primary Series', number: 1),
            BookSeries(name: 'Secondary Series', number: 2),
          ],
        );
        expect(metaWithSeries.primarySeries?.name, equals('Primary Series'));

        const metaWithoutSeries = BookMetadata(id: 'm2', title: 'T', language: 'ru');
        expect(metaWithoutSeries.primarySeries, isNull);
      });

      test('BookMetadata contributorsByRole filters contributors by role', () {
        const meta = BookMetadata(
          id: 'm3',
          title: 'T',
          language: 'ru',
          contributors: [
            BookContributor(
              role: BookContributorRole.author,
              name: PersonName(first: 'Author', last: 'One'),
            ),
            BookContributor(
              role: BookContributorRole.author,
              name: PersonName(first: 'Author', last: 'Two'),
            ),
            BookContributor(
              role: BookContributorRole.translator,
              name: PersonName(first: 'Translator', last: 'One'),
            ),
          ],
        );

        final authors = meta.contributorsByRole(BookContributorRole.author).toList();
        expect(authors.length, equals(2));
        expect(authors[0].name.first, equals('Author'));
        expect(authors[0].name.last, equals('One'));
        expect(authors[1].name.last, equals('Two'));

        final translators = meta.contributorsByRole(BookContributorRole.translator).toList();
        expect(translators.length, equals(1));
        expect(translators.first.name.first, equals('Translator'));

        final illustrators = meta.contributorsByRole(BookContributorRole.illustrator).toList();
        expect(illustrators, isEmpty);
      });

      test('PersonName toDisplayString formats display string across variations', () {
        // Explicit display name has highest priority
        const pDisplay = PersonName(
          first: 'Александр',
          last: 'Пушкин',
          display: 'А. С. Пушкин',
        );
        expect(pDisplay.toDisplayString(), equals('А. С. Пушкин'));

        // First, Middle, Last
        const pFull = PersonName(
          first: 'Александр',
          middle: 'Сергеевич',
          last: 'Пушкин',
        );
        expect(pFull.toDisplayString(), equals('Александр Сергеевич Пушкин'));

        // First, Last
        const pFirstLast = PersonName(first: 'Лев', last: 'Толстой');
        expect(pFirstLast.toDisplayString(), equals('Лев Толстой'));

        // Nickname only
        const pNick = PersonName(nickname: 'Stargazer');
        expect(pNick.toDisplayString(), equals('Stargazer'));

        // Empty name
        const pEmpty = PersonName();
        expect(pEmpty.toDisplayString(), equals(''));

        // Whitespace trimming
        const pWhitespace = PersonName(first: '  Иван  ', last: '  Иванов  ');
        expect(pWhitespace.toDisplayString(), equals('Иван Иванов'));
      });

      test('Book resourceById finds resource by ID or returns null', () {
        final res = BookResource(
          id: 'cover.jpg',
          mediaType: 'image/jpeg',
          bytes: Uint8List.fromList([1, 2, 3]),
        );

        final book = Book(
          metadata: const BookMetadata(id: 'b', title: 'T', language: 'ru'),
          content: const BookContent(),
          resources: [res],
        );

        expect(book.resourceById('cover.jpg'), isNotNull);
        expect(book.resourceById('cover.jpg')?.mediaType, equals('image/jpeg'));
        expect(book.resourceById('non_existent.png'), isNull);
      });
    });

    group('4. BookBuilder Fluent Interface and Step-by-Step Construction', () {
      test('Builds complete book step-by-step using builder methods', () async {
        final builder = BookBuilder(
          title: 'Полная Книга через BookBuilder',
          language: 'ru',
          contributors: const [
            BookContributor(
              role: BookContributorRole.author,
              name: PersonName(display: 'Главный Автор'),
            ),
          ],
          genres: const [BookGenre(code: 'sf_space', name: 'Космическая фантастика')],
          keywords: const ['космос', 'звезды'],
          series: const [BookSeries(name: 'Галактическая Сага', number: 1)],
          source: Uri.parse('https://example.com/books/galaxy-saga-1'),
        );

        // 1. Set cover
        builder.setCover(const BookResourceRef('cover.png'), alt: 'Обложка книги');

        // 2. Set annotation HTML
        builder.setAnnotationHtml('<p>Захватывающая история о покорении <strong>дальних миров</strong>.</p>');

        // 3. Add Chapter 1
        final ch1 = await builder.addChapterHtml(
          '<h1>Глава 1: Старт</h1><p>Корабль покинул орбиту Земли.</p>',
          title: 'Глава 1: Старт',
          id: 'chapter-1',
        );
        expect(ch1.id, equals('chapter-1'));

        // 4. Add Chapter 2
        final ch2 = await builder.addChapterHtml(
          '<h1>Глава 2: Гиперпрыжок</h1><p>Пространство вокруг сжалось в точку.</p>',
          title: 'Глава 2: Гиперпрыжок',
          id: 'chapter-2',
        );
        expect(ch2.id, equals('chapter-2'));

        // 5. Add manual binary resource
        builder.addResource(
          BookResource(
            id: 'cover.png',
            mediaType: 'image/png',
            bytes: Uint8List.fromList([137, 80, 78, 71]),
          ),
        );

        // 6. Build the book
        final book = await builder.build();

        // Verify metadata
        expect(book.metadata.title, equals('Полная Книга через BookBuilder'));
        expect(book.metadata.language, equals('ru'));
        expect(book.metadata.contributors.length, equals(1));
        expect(book.metadata.genres.length, equals(1));
        expect(book.metadata.series.length, equals(1));
        expect(book.metadata.keywords, contains('космос'));
        expect(book.metadata.source, equals(Uri.parse('https://example.com/books/galaxy-saga-1')));
        expect(book.metadata.cover?.ref.id, equals('cover.png'));
        expect(book.metadata.cover?.alt, equals('Обложка книги'));

        // Verify annotation
        expect(book.metadata.annotation, isNotNull);
        expect(book.metadata.annotation!.blocks.length, equals(1));
        final annotP = book.metadata.annotation!.blocks.first as BookParagraph;
        expect(annotP.inlines.any((i) => i is BookStrong), isTrue);

        // Verify content sections
        expect(book.content.blocks.length, equals(2));
        final sec1 = book.content.blocks[0] as BookSection;
        final sec2 = book.content.blocks[1] as BookSection;

        expect(sec1.id, equals('chapter-1'));
        expect((sec1.title.first as BookText).text, equals('Глава 1: Старт'));

        expect(sec2.id, equals('chapter-2'));
        expect((sec2.title.first as BookText).text, equals('Глава 2: Гиперпрыжок'));

        // Verify resources
        expect(book.resources.length, equals(1));
        expect(book.resourceById('cover.png'), isNotNull);
      });

      test('Supports custom and sequential resource naming policies', () async {
        final sequentialBuilder = BookBuilder(
          title: 'Sequential Naming Test',
          namingPolicy: BookResourceNamingPolicy.sequential,
        );

        await sequentialBuilder.addChapterHtml('<p><img src="https://cdn.site.com/assets/photos/pic1.jpeg"/></p>');
        final book = await sequentialBuilder.build();

        final section = book.content.blocks.first as BookSection;
        final paragraph = section.blocks.first as BookParagraph;
        final img = paragraph.inlines.first as BookImageInline;

        expect(img.ref.id, equals('img_001.jpeg'));
      });

      test('Resolves pending resources asynchronously with custom resource resolver', () async {
        final resolvedRequests = <BookResourceRequest>[];

        final builder = BookBuilder(
          title: 'Async Resolver Test',
          resourceResolver: (req, {onByteProgress}) async {
            resolvedRequests.add(req);
            return BookResource(
              id: req.id,
              mediaType: 'image/png',
              bytes: Uint8List.fromList([10, 20, 30]),
            );
          },
        );

        await builder.addChapterHtml(
          '<p>Here is an image: <img src="https://images.site.com/hero.png"/></p>',
          title: 'Chapter with Image',
        );

        final book = await builder.build();

        expect(resolvedRequests.length, equals(1));
        expect(resolvedRequests.first.source, equals('https://images.site.com/hero.png'));
        expect(book.resources.length, equals(1));
        expect(book.resources.first.bytes, equals(Uint8List.fromList([10, 20, 30])));
      });

      test('Propagates strictMode and logger in addChapterHtml', () async {
        final warnings = <String>[];
        final builder = BookBuilder(title: 'Logging Test');

        await builder.addChapterHtml(
          '<p>Text with <custom-tag>custom element</custom-tag></p>',
          strictMode: false,
          logger: (w) => warnings.add(w),
        );

        expect(warnings.isNotEmpty, isTrue);
        expect(warnings.first, contains('custom-tag'));

        final strictBuilder = BookBuilder(title: 'Strict Mode Test');
        expect(
          () => strictBuilder.addChapterHtml(
            '<p><unhandled-tag>fail</unhandled-tag></p>',
            strictMode: true,
          ),
          throwsA(isA<BookParseException>()),
        );
      });
    });
  });
}
