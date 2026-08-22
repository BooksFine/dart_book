# dart_book

[![Tests](https://img.shields.io/badge/tests-158%20passed-brightgreen.svg)](#)
[![Coverage](https://img.shields.io/badge/coverage-96.8%25-brightgreen.svg)](#)
[![Branch Coverage](https://img.shields.io/badge/branch%20coverage-93.6%25-brightgreen.svg)](#)
[![Dart SDK](https://img.shields.io/badge/Dart-3.12+-blue.svg)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Библиотека на Dart для парсинга, сериализации и конвертации электронных книг форматов **EPUB** (2.0.1, 3.0–3.4) и **FB2** (2.0, 2.1, 2.2, FB2.zip).

В основе библиотеки лежит единое дерево синтаксических узлов (`Book` AST). Форматы приводятся к типизированным блокам и инлайновым элементам, что позволяет работать с контентом книги независимо от исходной разметки.

---

## Возможности

- **Форматы и конвертация:** чтение, сборка и двусторонняя конвертация между EPUB (2.0.1, 3.0–3.4), FB2 (2.0–2.2) и архивами FB2.zip.
- **Структура и элементы книги:** разбор глав, оглавления, сносок, таблиц (`colspan`, `rowspan`), блоков кода, стихов, цитат, формул MathML, векторного SVG, аудио и видео.
- **Метаданные и ресурсы:** извлечение авторов, переводчиков, серий, издательских данных, языка/названия оригинала, графических обложек и медиафайлов.
- **Синхронизация звука (SMIL 3.0):** извлечение аудиодорожек и разбор временных меток для аудиокниг (Media Overlays).

## Архитектура и надежность

- **Единое AST:** книга представляется строго типизированным деревом Dart 3 `sealed class` с поддержкой исчерпывающего pattern matching.
- **Фоновые изоляты:** возможность разбора и кодирования в `Isolate.run` без блокировки главного UI-потока.
- **Устойчивость к ошибкам:** автоопределение кодировок (UTF-8, Windows-1251), санитизация некорректного XML 1.0, автоматическая деобфускация шрифтов (IDPF, Adobe) и безопасная работа с архивами в памяти.

---

## Быстрый старт

### 1. Чтение книги и получение метаданных

```dart
import 'dart:io';
import 'package:dart_book/dart_book.dart';

void main() async {
  final bytes = await File('book.epub').readAsBytes();
  final book = await DartBook.load(bytes);

  print(book.metadata.title);
  print(book.metadata.language);
  print(book.metadata.contributors.map((c) => c.name.display).join(', '));
  print('Количество блоков: ${book.content.blocks.length}');
}
```

### 2. Конвертация между форматами

```dart
import 'dart:io';
import 'package:dart_book/dart_book.dart';

void main() async {
  final fb2Bytes = await File('input.fb2').readAsBytes();
  final book = await DartBook.load(fb2Bytes);

  // Конвертация в EPUB
  final epubBytes = EpubConverter.bookToEpub(book);
  await File('output.epub').writeAsBytes(epubBytes);

  // Конвертация в FB2.zip
  final fb2ZipBytes = Fb2Converter.bookToFb2Zip(book);
  await File('output.fb2.zip').writeAsBytes(fb2ZipBytes);
}
```

### 3. Обход блоков контента

```dart
import 'package:dart_book/dart_book.dart';

void processBlocks(Book book) {
  for (final block in book.content.blocks) {
    switch (block) {
      case BookHeading(:final level, :final text):
        print('H$level: $text');

      case BookParagraph(:final inlines):
        final text = inlines.whereType<BookText>().map((t) => t.text).join();
        print('Параграф: $text');

      case BookTable(:final rows):
        print('Таблица: ${rows.length} строк');

      case BookQuote(:final blocks, :final citation):
        print('Цитата: $citation');

      case BookSection(:final title, :final blocks):
        print('Раздел');
    }
  }
}
```

### 4. Разбор в фоновом изоляте

```dart
// Разбор книги без блокировки главного потока
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
- `Fb2Converter.bookToFb2Zip(book, {options})` — сериализация в `.fb2.zip`.

### Опции

```dart
const decodingOptions = BookDecodingOptions(
  strictMode: false,             // true — выбрасывать исключения при неизвестных тегах
  logger: (warn) => print(warn), // Обработчик предупреждений
);

const encodingOptions = BookEncodingOptions(
  documentId: 'DOC-12345',
  programUsed: 'dart_book',
  entryFilename: 'book.fb2',
  namingPolicy: BookResourceNamingPolicy.sequential,
  pretty: false,
  compressZip: true,
);
```

### Исключения

- `BookException` — базовый класс исключений.
  - `BookFormatException` — ошибка формата файла или повреждённая ZIP-сигнатура.
  - `BookParseException` — синтаксическая ошибка разметки (содержит поля `tag` и `line`).
  - `BookMalformedMetadataException` — отсутствие обязательных метаданных в strict-режиме.
  - `EpubException` — базовое исключение EPUB.
    - `EpubEncryptedResourceException` — обнаружены DRM-ресурсы.
    - `EpubInvalidPackageException` — нарушение структуры OCF/OPF пакета.

---

## Модель данных (AST)

- **`Book`**: корневой объект (`metadata`, `content`, `resources`).
- **`BookMetadata`**: название, язык, авторы (`BookContributor`), переводчики, жанры, серии, издательские данные (`BookPublishInfo`), язык/название оригинала (`srcLang`, `srcTitleInfo`), режим вёрстки (`layout`), аннотация, обложка.
- **`BookBlock`**:
  - `BookSection` — раздел / глава (`title`, `blocks`, `children`).
  - `BookHeading` — заголовок (`level`, `text`, `inlines`).
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

## Производительность

Замеры производительности на синтетических и реальных данных (Dart 3, чистый Dart без FFI):

| Компонент / Сценарий | Объем данных | Время выполнения |
| :--- | :--- | :---: |
| `HtmlParser` | 10 000 параграфов с инлайновыми стилями | ~370 мс |
| `Fb2Decoder` | 5 000 секций со сносками | ~340 мс |
| **Тест на объёме 1 000 глав (~1.8 МБ)** |
| 🔹 `Fb2Encoder` | Сборка FB2 XML | ~45 мс |
| 🔹 `Fb2Decoder` | Полный парсинг FB2 в AST | ~185 мс |
| 🔹 `EpubEncoder` | Упаковка EPUB (1 000 XHTML + манифест) | ~205 мс |
| 🔹 `EpubDecoder` | Распаковка и разбор EPUB | ~240 мс |

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
[SPECIFICATIONS.md](SPECIFICATIONS.md)

---

## Лицензия

MIT. См. файл [LICENSE](LICENSE).
