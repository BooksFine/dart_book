# dart_book

[![Tests](https://img.shields.io/badge/tests-158%20passed-brightgreen.svg)](#)
[![Coverage](https://img.shields.io/badge/coverage-96.8%25-brightgreen.svg)](#)
[![Branch Coverage](https://img.shields.io/badge/branch%20coverage-93.6%25-brightgreen.svg)](#)
[![Dart SDK](https://img.shields.io/badge/Dart-3.12+-blue.svg)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Высокопроизводительная библиотека на чистом Dart для чтения, создания и взаимной конвертации электронных книг в форматах **EPUB** (EPUB 2.0.1, EPUB 3.0–3.4) и **FB2** (FB2 2.0, 2.1, 2.2, FB2.zip).

В основе библиотеки лежит **единая модель данных (AST)** — книга представляется в виде типобезопасного дерева блоков и инлайновых элементов, абстрагируя разработчика от нюансов XML, XHTML и OCF-контейнеров.

---

## ✨ Возможности

- 📚 **Полная поддержка форматов:** Чтение и запись EPUB (EPUB 2/3), FB2 (2.0/2.1/2.2) и упакованных FB2.zip архивов.
- 🌳 **Единое абстрактное синтаксическое дерево (AST):** Любая книга представляется типобезопасной иерархией `BookNode` на базе Dart 3 `sealed class`.
- ⚡ **Zero-Jank и 144 FPS:** Встроенная поддержка неблокирующего парсинга и кодирования в фоновых воркер-изолятах (`DartBook.loadIsolated` / `DartBook.encodeIsolated`).
- 🔄 **Lossless Roundtrip & Idempotence:** Математически выверенная конвертация между форматами ($AST_2 \equiv AST_3$) без накопления дрейфа разметки, склейки слов или потери структуры.
- 🛡️ **Устойчивость к грязным данным:** Автоматическая санитизация невалидного XML 1.0 (контрольные символы, незаэкранированные `&`, незадекларированные сущности), терпимость к поврежденному Base64, автоопределение кодировок (UTF-8, Windows-1251 / CP1251).
- 🔒 **Встроенная безопасность:** Защита от **Zip Slip** (path traversal `../../` в оперативной памяти), бомб декомпрессии и бесконечных циклов в оглавлении и сносках (Visited Set + глубина $\le 32$).
- 🔤 **Криптографическая деобфускация шрифтов:** Восстановление оригинальных OpenType / TrueType шрифтов алгоритмами IDPF (SHA-1) и Adobe (UUID XOR).
- 🧩 **Богатый контент:** Поддержка сложных таблиц (`colspan`, `rowspan`, выравнивание), блоков кода с подсветкой, стихов, цитат, формул MathML, векторной графики SVG, аудио, видео и обложек.
- ⏱️ **Media Overlays (SMIL 3.0):** Разбор документов синхронизации аудио и текста с поддержкой всех форматов времени (`hh:mm:ss`, `mm:ss`, `ms`, `min`, `h`).

---

## 🚀 Быстрый старт

### 1. Чтение книги и извлечение метаданных

```dart
import 'dart:io';
import 'package:dart_book/dart_book.dart';

void main() async {
  final bytes = await File('book.epub').readAsBytes();

  // Автоматическое определение формата (EPUB, FB2 или FB2.zip)
  final book = await DartBook.load(bytes);

  print('Название: ${book.metadata.title}');
  print('Язык: ${book.metadata.language}');
  print('Авторы: ${book.metadata.contributors.map((c) => c.name.display).join(', ')}');
  print('Глав в книге: ${book.content.blocks.length}');
  print('Встроенных ресурсов: ${book.resources.length}');
}
```

### 2. Конвертация между форматами (EPUB ↔ FB2)

```dart
import 'dart:io';
import 'package:dart_book/dart_book.dart';

void main() async {
  // Читаем FB2 (или FB2.zip)
  final fb2Bytes = await File('input.fb2').readAsBytes();
  final book = await DartBook.load(fb2Bytes);

  // Конвертируем в EPUB 3 с Dual Navigation (NAV + NCX)
  final epubBytes = EpubConverter.bookToEpub(book);
  await File('output.epub').writeAsBytes(epubBytes);

  // Конвертируем обратно в FB2.zip
  final fb2ZipBytes = Fb2Converter.bookToFb2Zip(book);
  await File('output.fb2.zip').writeAsBytes(fb2ZipBytes);
}
```

### 3. Рендеринг и обход контента через Dart 3 Pattern Matching

```dart
import 'package:dart_book/dart_book.dart';

void renderBook(Book book) {
  for (final block in book.content.blocks) {
    switch (block) {
      case BookHeading(:final level, :final text):
        print('Заголовок H$level: $text');

      case BookParagraph(:final inlines):
        final buffer = StringBuffer();
        for (final inline in inlines) {
          switch (inline) {
            case BookText(:final text): buffer.write(text);
            case BookStrong(:final children): buffer.write('[B]');
            case BookEmphasis(:final children): buffer.write('[I]');
            case BookFootnoteRef(:final id): buffer.write('[$id]');
            default: break;
          }
        }
        print('Абзац: $buffer');

      case BookTable(:final rows):
        print('Таблица на ${rows.length} строк');

      case BookQuote(:final blocks, :final citation):
        print('Цитата (автор: $citation)');

      case BookSection(:final title, :final blocks):
        print('Секция: ${title?.map((t) => t.text).join()}');
    }
  }
}
```

### 4. Zero-Jank: загрузка в фоновом изоляте (Flutter)

```dart
// Выполняется в фоновом Isolate.run — 0 мс блокировки UI-потока
final book = await DartBook.loadIsolated(
  bytes,
  filename: 'large_book.epub',
);
```

---

## 🛠 Подробное руководство по API

### Класс `DartBook`
Главный фасад для высокоуровневой работы:

```dart
abstract class DartBook {
  /// Синхронно-асинхронная загрузка книги в текущем изоляте с автодетектом формата
  static Future<Book> load(
    Uint8List bytes, {
    String? filename,
    BookDecodingOptions? options,
    BookResourceResolver? resourceResolver,
  });

  /// Загрузка книги в отдельном изоляте (рекомендуется для UI / Flutter)
  static Future<Book> loadIsolated(
    Uint8List bytes, {
    String? filename,
    BookDecodingOptions? options,
    BookResourceResolver? resourceResolver,
  });

  /// Кодирование книги в указанный формат в изоляте ('epub', 'fb2', 'fb2.zip')
  static Future<Uint8List> encodeIsolated(
    Book book,
    String extension, {
    BookEncodingOptions? options,
  });
}
```

### Специализированные конвертеры

#### `EpubConverter`
- `EpubConverter.epubToBook(bytes, {options})` — декодирование EPUB 2/3 архива в `Book`.
- `EpubConverter.bookToEpub(book, {options})` — упаковка `Book` в валидный EPUB 3.3 архив с несжатым `mimetype` и Dual Navigation.

#### `Fb2Converter` & `Fb2ZipConverter`
- `Fb2Converter.fb2ToBook(bytes, {options})` — разбор FB2 XML (поддерживает UTF-8 и Windows-1251).
- `Fb2Converter.bookToFb2(book, {isZip = false, options})` — генерация FB2 XML.
- `Fb2Converter.bookToFb2Zip(book, {options})` — упаковка в `.fb2.zip`.

### Опции декодирования и кодирования

#### `BookDecodingOptions`
```dart
const options = BookDecodingOptions(
  strictMode: true,              // Выбрасывать BookParseException при нераспознанных элементах
  logger: (warn) => print(warn), // Callback для перехвата предупреждений
);
```

#### `BookEncodingOptions`
```dart
const options = BookEncodingOptions(
  documentId: 'DOC-12345',                           // Уникальный ID документа
  programUsed: 'dart_book 1.0',                      // Название программы-генератора
  entryFilename: 'book.fb2',                         // Имя файла внутри архива для FB2.zip
  namingPolicy: BookResourceNamingPolicy.sequential, // Политика имен ресурсов (sequential, preserve, hash)
  pretty: true,                                      // Форматировать XML с отступами
  compressZip: true,                                 // Сжимать ZIP-архив
);
```

### Иерархия исключений
Все ошибки библиотеки наследуются от `BookException`:
- `BookException` — базовый класс всех исключений.
  - `BookFormatException` — повреждённый архив, неверная сигнатура ZIP или нераспознанный формат.
  - `BookParseException` — синтаксическая ошибка структуры разметки (содержит поля `tag` и `line`).
  - `BookMalformedMetadataException` — отсутствуют обязательные метаданные (`<dc:title>`, `<book-title>`) в strict-режиме.
  - `EpubException` — базовое исключение формата EPUB.
    - `EpubEncryptedResourceException` — обнаружены зашифрованные DRM-ресурсы.
    - `EpubInvalidPackageException` — нарушение структуры OCF-пакета или манифеста OPF.

---

## 🌳 Единая модель данных (AST)

- **`Book`**: Корневой объект (`metadata`, `content`, `resources`).
- **`BookMetadata`**: Название, язык, авторы (`BookContributor`), переводчики, жанры (`BookGenre`), серии (`BookSeries`), издатель (`BookPublishInfo`), оригинальное издание (`srcTitleInfo`, `srcLang`), режим вёрстки (`layout`), аннотация (`BookContent`), обложка (`BookCover`).
- **`BookBlock`** (17 типов узлов):
  - `BookSection` — глава / подраздел (`title`, `blocks`, `children`).
  - `BookHeading` — заголовок уровня 1–6 (`level`, `text`, `inlines`).
  - `BookParagraph` — абзац текста (`inlines`).
  - `BookQuote` — цитата или эпиграф (`blocks`, `citation`).
  - `BookList` — нумерованный или маркированный список (`ordered`, `items`).
  - `BookTable` — таблица (`rows` -> `cells` с `colSpan`, `rowSpan`, `align`, `vAlign`).
  - `BookPoem` — стихотворение (`stanzas` -> `lines`).
  - `BookCodeBlock` — блок кода (`code`, `language`).
  - `BookImageBlock` — иллюстрация (`ref`, `id`, `alt`, `title`).
  - `BookAudioBlock` / `BookVideoBlock` — медиаплеер (`ref`, `posterRef`, `controls`).
  - `BookMathBlock` — блок MathML XML (`mathml`).
  - `BookSvgBlock` — векторная SVG графика (`svg`).
  - `BookHorizontalRule` / `BookEmptyLine` — разделители.
  - `BookRawHtmlBlock` / `BookRawXmlBlock` — сохранение произвольной нестандартной разметки.
- **`BookInline`** (15 типов инлайнов):
  - `BookText`, `BookEmphasis` (курсив), `BookStrong` (жирный), `BookStrike` (зачёркнутый).
  - `BookCodeSpan` (строчный код), `BookNamedStyle` (пользовательский стиль).
  - `BookLink` (гиперссылка), `BookAnchor` (якорь), `BookFootnoteRef` (сноска).
  - `BookImageInline` (строчная иконка/картинка).
  - `BookSuperscript` / `BookSubscript` (верхний/нижний индекс).
  - `BookLineBreak` (перенос строки `<br/>`).
- **`BookResource`**: Бинарные ресурсы книги (изображения, шрифты, аудио, CSS) с MIME-типами и ID.

---

## ⚡ Производительность и бенчмарки

Библиотека оптимизирована для работы с гигантскими книгами на чистом Dart без внешних C/C++ FFI зависимостей:

| Компонент / Сценарий | Объем данных | Время выполнения | Скорость обработки |
| :--- | :--- | :---: | :---: |
| **`HtmlParser`** | 10 000 параграфов (жирный, курсив, ссылки, код) | **~370 ms** | ~26 500 параграфов / сек |
| **`Fb2Decoder`** | 5 000 секций с оглавлением и сносками | **~340 ms** | ~14 400 секций / сек |
| **Масштаб «Войны и мира» (1 000 глав, 10 000 параграфов, ~1.8 МБ)** |
| 🔹 `Fb2Encoder` | Сборка FB2 XML | **~45 ms** | ~40 МБ/сек |
| 🔹 `Fb2Decoder` | Полный парсинг FB2 в AST | **~185 ms** | ~10 МБ/сек |
| 🔹 `EpubEncoder` | Сборка ZIP (1 000 XHTML + OPF + NAV + NCX) | **~205 ms** | ~5 000 глав/сек |
| 🔹 `EpubDecoder` | Распаковка и полный разбор EPUB архива | **~240 ms** | ~4 150 глав/сек |

---

## 🛡️ Архитектура тестирования и надежность

Тестовый набор библиотеки насчитывает **158 тестов (100% passing)** и проверен 4 независимыми аудитами:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              ПИРАМИДА ТЕСТИРОВАНИЯ DART_BOOK                           │
├────────────────────────────────────────────────────────────────────────────────────────┤
│  Этап 4: Безопасность, Фаззинг и Стресс-тесты (Security, Fuzzing & Resilience)         │
│  Этап 3: Интеграционные Golden Master и Кросс-раундтрип (Real-World Books & Snapshots) │
│  Этап 2: Изолированные Unit-тесты парсеров и кодеков (XHTML, FB2, Win-1251, Шрифты)   │
│  Этап 1: Фундамент тестовой инфраструктуры и Фикстуры (Normalizer, Generator, Goldens) │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

| Метрика качества | Значение | Описание |
| :--- | :---: | :--- |
| **Unit & Integration тесты** | **158 / 158 (100% green)** | Проверка парсеров, кодеков, шрифтов, таблиц и SMIL |
| **Покрытие строк (Line Coverage)** | **96.83%** (2351 / 2428) | Покрытие рукописного кода библиотеки без учёта кодогенерации |
| **Покрытие ветвей (Branch Coverage)** | **93.6%** | Проверка всех условий, граничных случаев и fallback-веток |
| **Статический анализ** | **0 issues** | Строгие линты (`dart analyze --fatal-infos`) |
| **Crash-Free Invariant** | **100%** | Генеративный фаззинг (50 мутированных потоков байт) без unhandled Errors |
| **Fixed-Point Idempotence** | **$AST_2 \equiv AST_3$** | Доказанная сходимость при циклических конвертациях `EPUB ↔ FB2` |

### Запуск тестов локально:
```bash
# Анализ кодовой базы
dart analyze

# Запуск полного набора тестов
dart test

# Расчет покрытия рукописного кода
dart run tool/calculate_handwritten_coverage.dart

# Анализ цикломатической сложности
dart run tool/calculate_ccn.dart

# Запуск стресс-тестов и бенчмарков производительности
dart test test/stress/performance_benchmark_test.dart
```

---

## 📋 Соответствие стандартам

Подробные таблицы соответствия спецификациям **EPUB 2.0.1, 3.0–3.4** и **FictionBook (FB2 2.0–2.2)** вынесены в отдельный документ:
👉 **[SPECIFICATIONS.md](SPECIFICATIONS.md)**

---

## 📄 Лицензия

Библиотека распространяется под свободной лицензией **MIT**. Подробности в файле [LICENSE](LICENSE).
