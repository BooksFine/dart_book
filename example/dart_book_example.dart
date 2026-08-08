import 'package:dart_book/dart_book.dart';

Future<void> main() async {
  // 1. Распарсить HTML-фрагмент в блоки книги через HtmlParser
  final htmlParser = HtmlParser(
    registrar: (src, {required isInline}) => 'resource-$src',
  );
  final blocks = htmlParser.parseFromString(
    '<h1>Demo Book</h1><p>Hello <strong>World</strong>!</p>',
  );
  print('Parsed ${blocks.length} blocks from HTML content.');

  // 2. Сформировать универсальную модель Book
  final book = Book(
    id: 'demo-1',
    metadata: const BookMetadata(
      title: 'Demo Book',
      language: 'en',
      contributors: [
        BookContributor(
          role: BookContributorRole.author,
          name: PersonName(first: 'John', last: 'Doe', display: 'John Doe'),
        ),
      ],
    ),
    content: BookContent(blocks: blocks),
    resources: const [],
  );

  // 3. Закодировать в FB2 и EPUB
  final fb2Bytes = await Fb2Converter.bookToFb2(book);
  print('Generated FB2 size: ${fb2Bytes.length} bytes');

  final epubBytes = await EpubConverter.bookToEpub(book);
  print('Generated EPUB size: ${epubBytes.length} bytes');

  // 4. Загрузить обратно из байт через DartBook.load (авторазбор формата)
  final loadedFb2 = await DartBook.load(fb2Bytes, filename: 'book.fb2');
  print('Loaded FB2 title: ${loadedFb2.metadata.title}');

  final loadedEpub = await DartBook.load(epubBytes, filename: 'book.epub');
  print('Loaded EPUB title: ${loadedEpub.metadata.title}');
}
