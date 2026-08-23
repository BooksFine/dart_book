# dart_book

[English version](README.md) | [Русская версия](README.ru.md)

[![Tests](https://img.shields.io/badge/tests-166%20passed-brightgreen.svg)](#)
[![Coverage](https://img.shields.io/badge/coverage-96.8%25-brightgreen.svg)](#)
[![Branch Coverage](https://img.shields.io/badge/branch%20coverage-93.6%25-brightgreen.svg)](#)
[![Dart SDK](https://img.shields.io/badge/Dart-3.3+-blue.svg)](pubspec.yaml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

Библиотека на Dart для парсинга, сериализации и конвертации электронных книг форматов **EPUB** (2.0.1, 3.0–3.4) и **FB2** (2.0, 2.1, 2.2, FB2.zip).

В основе библиотеки лежит единое дерево синтаксических узлов (`Book` AST). Форматы приводятся к типизированным блокам и инлайновым элементам, что позволяет работать с контентом книги независимо от исходной разметки.

---

## Возможности

- **Форматы и конвертация:** чтение, сборка и двусторонняя конвертация между EPUB (2.0.1, 3.0–3.4), FB2 (2.0–2.2) и архивами FB2.zip.
- **Парсинг HTML5 и сборка книг:** прямой разбор HTML5 (`HtmlParser`) в блоки AST с устойчивостью к битому HTML (tag soup, некорректная вложенность, незакрытые теги) и умным разделением на абзацы (сохранение инлайн-стилей, переносов и Unicode-разделителей), а также конструктор `BookBuilder` для поглавной сборки книг из веб-источников и CMS.
- **Структура и элементы книги:** разбор глав, оглавления, сносок, таблиц (`colspan`, `rowspan`), блоков кода, стихов, цитат, формул MathML, векторного SVG, аудио и видео.
- **Метаданные и ресурсы:** извлечение авторов, переводчиков, серий, издательских данных, языка/названия оригинала, графических обложек и медиафайлов.
- **Синхронизация звука (SMIL 3.0):** извлечение аудиодорожек и разбор временных меток для аудиокниг (Media Overlays).

## Архитектура и надежность

- **Единое AST:** книга представляется строго типизированным деревом Dart 3 `sealed class` с поддержкой исчерпывающего pattern matching.
- **Фоновые изоляты:** возможность разбора и кодирования в `Isolate.run` без блокировки главного UI-потока.
- **Устойчивость к ошибкам:** автоопределение кодировок (UTF-8, Windows-1251), санитизация некорректного XML 1.0, устойчивый парсинг некорректного веб-HTML, автоматическая деобфускация шрифтов (IDPF, Adobe) и безопасная работа с архивами в памяти.
- **Расширяемость:** регистрация собственных декодеров и энкодеров через `BookRegistry`.

---

## Установка

Подключите `dart_book` как Git-зависимость в вашем `pubspec.yaml`:

```yaml
dependencies:
  dart_book:
    git:
      url: https://github.com/BooksFine/dart_book.git
      ref: v0.1.0
```

Или последнюю версию из ветки `main`:
```yaml
dependencies:
  dart_book:
    git:
      url: https://github.com/BooksFine/dart_book.git
      ref: main
```

---

## Быстрый старт

### 1. Чтение книги и получение метаданных

```dart
import 'dart:io';
import 'package:dart_book/dart_book.dart';

void main() async {
  final bytes = await File('book.epub').readAsBytes();
  final book = await DartBook.load(bytes);

  print('Название: ${book.metadata.title}');
  print('Язык: ${book.metadata.language}');
  print('Авторы: ${book.metadata.contributors.map((c) => c.name.display).join(', ')}');
  print('Глав: ${book.content.blocks.length}');
}
```

### 2. Конвертация между форматами

```dart
import 'dart:io';
import 'package:dart_book/dart_book.dart';

void main() async {
  final fb2Bytes = await File('input.fb2').readAsBytes();
  final book = await DartBook.load(fb2Bytes);

  // Конвертация в EPUB 3 с Dual Navigation (NAV + NCX)
  final epubBytes = await EpubConverter.bookToEpub(book);
  await File('output.epub').writeAsBytes(epubBytes);

  // Конвертация в FB2.zip
  final fb2ZipBytes = await Fb2Converter.bookToFb2Zip(book);
  await File('output.fb2.zip').writeAsBytes(fb2ZipBytes);
}
```

### 3. Извлечение обложки и бинарных ресурсов

```dart
import 'package:dart_book/dart_book.dart';

void extractAssets(Book book) {
  // Получение обложки книги
  if (book.metadata.cover != null) {
    final coverRef = book.metadata.cover!.ref.id;
    final coverResource = book.resourceById(coverRef);
    if (coverResource != null) {
      print('Обложка: ${coverResource.mediaType}, ${coverResource.bytes.length} байт');
    }
  }

  // Список всех изображений
  final images = book.resources.where((r) => r.mediaType.startsWith('image/'));
  for (final img in images) {
    print('Изображение: ${img.id} (${img.mediaType})');
  }
}
```

### 4. Пошаговая сборка книги через `BookBuilder`

```dart
import 'package:dart_book/dart_book.dart';

Future<Book> createBook() async {
  final builder = BookBuilder(
    title: 'Хроники',
    language: 'ru',
    contributors: const [
      BookContributor(
        role: BookContributorRole.author,
        name: PersonName(first: 'Иван', last: 'Иванов', display: 'Иван Иванов'),
      ),
    ],
    genres: const [BookGenre(code: 'sf_fantasy', name: 'Фэнтези')],
  );

  // Добавление аннотации и глав из HTML
  builder.setAnnotationHtml('<p>Краткое описание книги.</p>');
  await builder.addChapterHtml('<h2>Глава 1</h2><p>Начало истории...</p>', title: 'Глава 1');
  await builder.addChapterHtml('<h2>Глава 2</h2><p>Продолжение...</p>', title: 'Глава 2');

  return await builder.build();
}
```

### 5. Обход блоков контента (Pattern Matching)

```dart
import 'package:dart_book/dart_book.dart';

void processBlocks(Book book) {
  for (final block in book.content.blocks) {
    switch (block) {
      case BookHeading(:final level, :final text):
        final headingText = text.whereType<BookText>().map((t) => t.text).join();
        print('H$level: $headingText');

      case BookParagraph(:final inlines):
        final text = inlines.whereType<BookText>().map((t) => t.text).join();
        print('Параграф: $text');

      case BookTable(:final rows):
        print('Таблица: ${rows.length} строк');

      case BookQuote(:final citation):
        final cite = citation.whereType<BookText>().map((c) => c.text).join();
        print('Цитата: $cite');

      case BookSection(:final title):
        final titleText = title.whereType<BookText>().map((t) => t.text).join();
        print('Раздел: $titleText');

      default:
    }
  }
}
```

### 6. Разбор в фоновом изоляте

```dart
// Разбор книги в Isolate.run без блокировки главного потока UI
final book = await DartBook.loadIsolated(
  bytes,
  filename: 'large_book.epub',
);
```

---

## API

### Класс `DartBook`

```dart
abstract class DartBook {
  /// Загрузка книги с автоматическим определением формата
  static Future<Book> load(
    Uint8List bytes, {
    String? filename,
    BookDecodingOptions? options,
    BookResourceResolver? resourceResolver,
  });

  /// Загрузка книги в отдельном изоляте
  static Future<Book> loadIsolated(
    Uint8List bytes, {
    String? filename,
    BookDecodingOptions? options,
    BookResourceResolver? resourceResolver,
  });

  /// Кодирование книги в изоляте ('epub', 'fb2', 'fb2.zip')
  static Future<Uint8List> encodeIsolated(
    Book book,
    String extension, {
    BookEncodingOptions? options,
  });
}
```

### Конвертеры

- `EpubConverter.epubToBook(bytes, {options})` — декодирование архива EPUB в `Book`.
- `EpubConverter.bookToEpub(book, {options})` — сборка EPUB 3 с оглавлением (NAV + NCX).
- `Fb2Converter.fb2ToBook(bytes, {options})` — декодирование FB2 (UTF-8, Windows-1251).
- `Fb2Converter.bookToFb2(book, {isZip = false, options})` — сериализация в FB2 XML.
- `Fb2Converter.bookToFb2Zip(book, {resourceResolver})` — упаковка книги в `.fb2.zip`.

### Парсер HTML `HtmlParser`

Парсит HTML5 строки или фрагменты документов в блоки AST:

```dart
final parser = HtmlParser();
final blocks = parser.parseFromString('<p>Текст статьи с <strong>жирным</strong> шрифтом</p>');
```

### Конструктор книг `BookBuilder`

Позволяет поглавно собирать книгу из HTML-разметки с автоматической параллельной загрузкой изображений:

```dart
final builder = BookBuilder(title: 'Моя книга', language: 'ru');
await builder.addChapterHtml('<h2>Глава 1</h2><p>Текст...</p>', title: 'Глава 1');
final book = await builder.build();
```

### Реестр форматов `BookRegistry`

Позволяет зарегистрировать собственный декодер или энкодер с приоритетом над стандартными:

```dart
// Регистрация кастомного декодера
BookRegistry.registerDecoder(MyCustomFormatDecoder());

// Регистрация кастомного энкодера
BookRegistry.registerEncoder(MyCustomFormatEncoder());
```

### Загрузка внешних ресурсов `BookResourceResolver`

Для книг со ссылками на внешние изображения поддерживается асинхронный резолвер:

```dart
final book = await DartBook.load(
  bytes,
  resourceResolver: (request, {onByteProgress}) async {
    // request.source содержит исходный URL или путь
    // onByteProgress(received, total) позволяет стримить прогресс
    final response = await http.get(Uri.parse(request.source!));
    return BookResource(
      id: request.id,
      mediaType: response.headers['content-type'] ?? 'image/jpeg',
      bytes: response.bodyBytes,
    );
  },
);
```

### Опции

```dart
final decodingOptions = BookDecodingOptions(
  strictMode: false,             // true — выбрасывать исключения при неизвестных тегах/ошибках
  logger: (warn) => print(warn), // Обработчик предупреждений
);

const encodingOptions = BookEncodingOptions(
  documentId: 'DOC-12345',
  programUsed: 'dart_book',
  entryFilename: 'book.fb2',
  namingPolicy: BookResourceNamingPolicy.preserve, // preserve, sequential, hash, custom
  pretty: true,
  compressZip: true,                              // false отключает Deflate для быстрого экспорта
);
```

### Исключения

- `BookException` — базовый класс исключений.
  - `BookFormatException` — ошибка формата файла или повреждённая ZIP-сигнатура.
  - `BookParseException` — синтаксическая ошибка разметки (содержит поля `tag` и `line`).
  - `BookMalformedMetadataException` — отсутствие обязательных метаданных в strict-режиме.
  - `EpubException` — базовое исключение EPUB.
    - `EpubEncryptedResourceException` — обнаружены зашифрованные DRM-ресурсы.
    - `EpubInvalidPackageException` — нарушение структуры OCF/OPF пакета.

---

## Модель данных (AST)

- **`Book`**: корневой объект (`metadata`, `content`, `resources`).
  - `resourceById(id)` — поиск ресурса по идентификатору.
- **`BookMetadata`**: название, язык, авторы (`BookContributor`), переводчики, жанры, серии, издательские данные (`BookPublishInfo`), язык/название оригинала (`srcLang`, `srcTitleInfo`), режим вёрстки (`layout`), аннотация, обложка (`BookCover`).
  - `primarySeries` — первая серия книги.
  - `contributorsByRole(role)` — фильтрация участников по роли.
- **`BookBlock`**:
  - `BookSection` — раздел / глава (`title`, `blocks`, `children`).
  - `BookHeading` — заголовок (`level`, `text`).
  - `BookParagraph` — абзац (`inlines`).
  - `BookQuote` — цитата или эпиграф (`blocks`, `citation`).
  - `BookList` — нумерованный/маркированный список (`ordered`, `items`).
  - `BookTable` — таблица (`rows` -> `cells` с `colSpan`, `rowSpan`, `align`, `vAlign`).
  - `BookPoem` — стихотворение (`stanzas` -> `lines`).
  - `BookCodeBlock` — блок исходного кода (`code`, `language`).
  - `BookImageBlock` — блочное изображение (`ref`, `id`, `alt`, `title`).
  - `BookAudioBlock` / `BookVideoBlock` — медиа (`ref`, `posterRef`, `controls`).
  - `BookMathBlock` — блок MathML (`mathml`).
  - `BookSvgBlock` — блок SVG (`svg`).
  - `BookHorizontalRule` / `BookEmptyLine` — разделители.
  - `BookRawHtmlBlock` / `BookRawXmlBlock` — исходная разметка при отсутствии маппинга.
- **`BookInline`**:
  - `BookText`, `BookEmphasis`, `BookStrong`, `BookStrike`.
  - `BookCodeSpan`, `BookNamedStyle`.
  - `BookLink`, `BookAnchor`, `BookFootnoteRef`.
  - `BookImageInline`.
  - `BookSuperscript`, `BookSubscript`.
  - `BookLineBreak`.
- **`BookResource`**: бинарные данные (изображения, шрифты, аудио, стили) с MIME-типами и идентификаторами.


---

## Тестирование

Тестовый набор включает **158 тестов**:

| Показатель | Значение | Примечание |
| :--- | :---: | :--- |
| **Тесты** | 158 / 158 passed | Unit, Integration, Golden Master, Security, Fuzzing |
| **Line Coverage** | 96.83% | Покрытие строк рукописного кода библиотеки |
| **Branch Coverage** | 93.6% | Покрытие ветвей логики и условий |
| **Статический анализ** | 0 issues | `dart analyze --fatal-infos` |

### Запуск тестов:
```bash
# Статический анализ
dart analyze

# Запуск тестов
dart test

# Расчёт покрытия кода
dart run tool/calculate_handwritten_coverage.dart

# Анализ цикломатической сложности
dart run tool/calculate_ccn.dart

# Запуск замеров производительности
dart test test/stress/performance_benchmark_test.dart
```

---

## Соответствие спецификациям

Детальная таблица поддержки стандартов EPUB (2.0.1, 3.0–3.4) и FB2 (2.0–2.2) приведена в документе:  
[SPECIFICATIONS.ru.md](SPECIFICATIONS.ru.md) ([English version](SPECIFICATIONS.md))

---

## Лицензия

Apache 2.0. См. файл [LICENSE](LICENSE).
