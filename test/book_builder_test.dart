import 'dart:typed_data';
import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';

void main() {
  group('BookBuilder & Custom Resource Downloader Scraper Tests', () {
    test('Builds book chapter by chapter with custom async resource resolver', () async {
      final downloadedUrls = <String>[];

      final builder = BookBuilder(
        title: 'Скачанная Книга с Ranobe',
        language: 'ru',
        contributors: const [
          BookContributor(
            role: BookContributorRole.author,
            name: PersonName(display: 'Автор Веб-Ранобэ'),
          ),
        ],
        resourceResolver: (request) async {
          // Кастомная функция загрузки с ресурса (поддержка User-Agent, Cookies, Proxy)
          if (request.source != null) {
            downloadedUrls.add(request.source!);
          }
          return BookResource(
            id: request.id,
            mediaType: 'image/png',
            bytes: Uint8List.fromList([137, 80, 78, 71]),
          );
        },
      );

      // 1. Загрузка Глава 1
      await builder.addChapterHtml(
        '<h1>Начало приключений</h1><p>Первый абзац <img src="https://media.site.com/img1.png"/></p>',
        title: 'Глава 1. Пробуждение',
      );

      // 2. Загрузка Глава 2
      await builder.addChapterHtml(
        '<h1>Второй день</h1><p>Второй абзац <img src="https://media.site.com/img2.png"/></p>',
        title: 'Глава 2. Путь',
      );

      final book = await builder.build();

      expect(book.metadata.title, equals('Скачанная Книга с Ranobe'));
      expect(book.content.blocks.length, equals(2)); // 2 главы
      expect(book.resources.length, equals(2)); // 2 ресурса
      expect(downloadedUrls, contains('https://media.site.com/img1.png'));
      expect(downloadedUrls, contains('https://media.site.com/img2.png'));

      // 3. Проверяем конвертацию в EPUB и FB2
      final epubBytes = await EpubConverter.bookToEpub(book);
      final fb2Bytes = await Fb2Converter.bookToFb2(book);

      expect(epubBytes, isNotEmpty);
      expect(fb2Bytes, isNotEmpty);
    });
  });
}
