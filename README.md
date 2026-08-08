# dart_book

Dart-библиотека для чтения, генерации и конвертации электронных книг в форматах **EPUB** (EPUB 3.3 / 3.4) и **FB2** (FictionBook 2.0 / 2.1 / 2.2). Библиотека предоставляет единую формато-независимую модель данных (`Book`), набор парсеров и конвертеров, инспекцию сносок, а также утилиту `BookBuilder` с кастомной загрузкой и политиками именования ресурсов для скрейпинга и "качалок".

---

## Содержание

- [Установка](#установка)
- [Быстрый старт](#быстрый-старт)
- [Архитектура](#архитектура)
- [Модель данных](#модель-данных)
  - [Book](#book)
  - [BookMetadata](#bookmetadata)
  - [BookContent](#bookcontent)
  - [BookBlock — блочные элементы](#bookblock--блочные-элементы)
  - [BookInline — строчные элементы](#bookinline--строчные-элементы)
  - [BookResource](#bookresource)
  - [BookContributor и PersonName](#bookcontributor-и-personname)
- [Поглавная сборка и скрейпинг (BookBuilder)](#поглавная-сборка-и-скрейпинг-bookbuilder)
- [Политики именования ресурсов (BookResourceNamingPolicy)](#политики-именования-ресурсов-bookresourcenamingpolicy)
- [Политика Zero Fallbacks и Strict Mode](#политика-zero-fallbacks-и-strict-mode)
- [Основной API — класс DartBook](#основной-api--класс-dartbook)
- [Конвертеры](#конвертеры)
  - [EpubConverter / EpubDecoder / EpubEncoder](#epubconverter--epubdecoder--epubencoder)
  - [Fb2Converter / Fb2Decoder / Fb2Encoder](#fb2converter--fb2decoder--fb2encoder)
  - [Fb2ZipConverter / Fb2ZipDecoder / Fb2ZipEncoder](#fb2zipconverter--fb2zipdecoder--fb2zipencoder)
- [Реестр конвертеров (BookRegistry)](#реестр-конвертеров-bookregistry)
- [Парсеры](#парсеры)
  - [HtmlParser](#htmlparser)
  - [Fb2Parser](#fb2parser)
- [Разрешение ресурсов](#разрешение-ресурсов)
- [Зависимости](#зависимости)

---

## Установка

Добавьте в `pubspec.yaml`:

```yaml
dependencies:
  dart_book:
    path: .  # или укажите git-репозиторий
```

Минимальная версия SDK: `^3.12.0`.

---

## Быстрый старт

```dart
import 'dart:io';
import 'package:dart_book/dart_book.dart';

Future<void> main() async {
  // 1. Загрузить книгу из файла (формат EPUB или FB2 определяется автоматически)
  final bytes = await File('book.epub').readAsBytes();
  final book = await DartBook.load(
    bytes,
    filename: 'book.epub',
    options: BookDecodingOptions(
      strictMode: true, // Включает выброс явных ошибок при нераспознанной разметке
      logger: (warning) => print('[WARNING] $warning'),
    ),
  );

  print(book.metadata.title);   // Название книги
  print(book.metadata.language); // Код языка ('ru', 'en')
  print(book.resources.length); // Количество медиа-ресурсов

  // 2. Перекодировать EPUB → FB2
  final fb2Bytes = await Fb2Converter.bookToFb2(book);
  await File('book.fb2').writeAsBytes(fb2Bytes);

  // 3. Перекодировать FB2 → EPUB
  final epubBytes = await EpubConverter.bookToEpub(book);
  await File('output.epub').writeAsBytes(epubBytes);
}
```

---

## Архитектура

```
DartBook.load() / BookBuilder.build()
    │
    ▼
BookRegistry.findDecoder()   ←── EpubConverter / Fb2Converter
    │                                    │
    ▼                             EpubDecoder / Fb2Decoder
  Book (универсальная формато-независимая модель)
    │
    ├── BookMetadata (title, language, genres, annotation, cover, series, keywords)
    ├── BookContent (blocks, footnotes)
    └── List<BookResource> (images, fonts, audio, video, css)
```

| Уровень | Классы | Назначение |
|---------|--------|------------|
| Входная точка | `DartBook` | Загрузка книги из байт с автоопределением формата |
| Сборка книги | `BookBuilder` | Поглавное создание книги из HTML с загрузчиком медиа |
| Модель | `Book`, `BookMetadata`, `BookContent` | Универсальное представление книги |
| Конвертеры | `EpubConverter`, `Fb2Converter` | Чтение/запись спецификаций EPUB 3.3/3.4 и FB2 2.0/2.1/2.2 |
| Парсеры | `HtmlParser`, `Fb2Parser` | Разбор разметки HTML5/XML в AST-дерево `BookBlock` |
| Именования имён | `BookResourceNamingPolicy` | Стратегии наименования файлов (preserve, sequential, hash, custom) |
| Реестр | `BookRegistry` | Поиск конвертеров по байтам или расширению |
| Исключения | `BookParseException`, `BookMalformedMetadataException` | Строгие ошибки разборки в режиме `strictMode` |

---

## Модель данных

### Book

```dart
class Book {
  final String id;                    // Уникальный GUID книги
  final BookMetadata metadata;        // Метаданные (название, авторы, обложка, ...)
  final BookContent content;          // Содержимое (блоки, главы, сноски)
  final List<BookResource> resources; // Загруженные ресурсы (изображения, шрифты, стили)

  BookResource? resourceById(String id); // Поиск ресурса по ID
}
```

---

### BookMetadata

```dart
class BookMetadata {
  final String title;                       // Название книги
  final String language;                    // Код языка (ISO 639-1)
  final List<BookContributor> contributors;   // Авторы, переводчики, редакторы
  final List<BookGenre> genres;             // Жанры
  final List<String> keywords;              // Ключевые слова / теги
  final BookContent? annotation;            // Аннотация книги
  final BookSeries? series;                 // Серия книг (название и номер)
  final BookCover? cover;                   // Ресурс обложки
  final Uri? source;                        // Оригинальный URL/URI источника
  final DateTime? updatedAt;                // Дата изменения
  final DateTime? publishedAt;              // Дата публикации
}
```

---

### BookBlock — блочные элементы AST

All block elements inherit from `BookBlock`:

| Класс | Описание | Ключевые поля |
|-------|----------|---------------|
| `BookSection` | Раздел / глава | `id`, `title` (инлайны), `blocks`, `children` |
| `BookHeading` | Заголовок | `level` (1–6), `text` (инлайны) |
| `BookParagraph` | Абзац | `inlines` |
| `BookQuote` | Цитата / эпиграф | `blocks`, `citation` (инлайны) |
| `BookList` | Список | `ordered` (нумерованный/маркированный), `items` |
| `BookListItem` | Элемент списка | `blocks` |
| `BookTable` | Таблица | `rows` |
| `BookTableRow` | Строка таблицы | `cells` |
| `BookTableCell` | Ячейка таблицы | `blocks`, `colSpan`, `rowSpan` |
| `BookPoem` | Стихотворение | `stanzas` |
| `BookStanza` | Строфа | `lines` |
| `BookPoemLine` | Строка стихотворения | `inlines` |
| `BookImageBlock` | Изображение | `ref`, `alt`, `title` |
| `BookAudioBlock` | Аудиозапись | `src`, `controls`, `sources` |
| `BookVideoBlock` | Видеозапись | `src`, `controls`, `sources` |
| `BookMathBlock` | Математика (MathML) | `mathml` |
| `BookSvgBlock` | Векторная графика SVG | `svg` |
| `BookHorizontalRule` | Горизонтальная линия | — |
| `BookEmptyLine` | Пустая строка | — |
| `BookCodeBlock` | Блок кода | `code`, `language` |
| `BookRawHtmlBlock` | Сырой HTML-блок | `html` |
| `BookRawXmlBlock` | Сырой XML-блок | `xml` |

---

### BookInline — строчные элементы AST

| Класс | Описание | Ключевые поля |
|-------|----------|---------------|
| `BookText` | Обычный текст | `text` |
| `BookLineBreak` | Перенос строки | — |
| `BookEmphasis` | Курсив / акцент | `children` |
| `BookStrong` | Полужирный | `children` |
| `BookStrike` | Зачёркнутый | `children` |
| `BookCodeSpan` | Встроенный код | `code` |
| `BookLink` | Гиперссылка | `href` (Uri), `children` |
| `BookAnchor` | Внутренний якорь | `id` |
| `BookImageInline` | Строчное изображение | `ref`, `alt` |
| `BookSuperscript` | Надстрочный индекс | `children` |
| `BookSubscript` | Подстрочный индекс | `children` |
| `BookFootnoteRef` | Ссылка на сноску | `id`, `label` |
| `BookRawHtmlInline` | Сырой HTML-инлайн | `html` |
| `BookRawXmlInline` | Сырой XML-инлайн | `xml` |

---

## Поглавная сборка и скрейпинг (BookBuilder)

Специализированный класс `BookBuilder` предназначен для скрейпинга веб-ресурсов (ранобе, фикбук, электронные библиотеки) с поглавным добавлением HTML и кастомным скачиванием изображений:

```dart
import 'package:dart_book/dart_book.dart';

Future<void> downloadWebBook() async {
  final builder = BookBuilder(
    title: 'Моя скачанная книга',
    language: 'ru',
    // Кастомный асинхронный резолвер ресурсов (Headers, Cookies, User-Agent, Proxy)
    resourceResolver: (request) async {
      final bytes = await httpClient.get(
        request.source!,
        headers: {'User-Agent': 'CustomScraper/1.0', 'Cookie': 'session=abc'},
      );
      return BookResource(
        id: request.id,
        mediaType: 'image/png',
        bytes: bytes,
      );
    },
    // Политика именования файлов медиа
    namingPolicy: BookResourceNamingPolicy.sequential,
  );

  // Добавление глав по одной из сырого HTML
  await builder.addChapterHtml(
    '<h1>Глава 1</h1><p>Текст <img src="https://site.com/pic1.png"/></p>',
    title: 'Глава 1. Пробуждение',
  );

  await builder.addChapterHtml(
    '<h1>Глава 2</h1><p>Текст <img src="https://site.com/pic2.png"/></p>',
    title: 'Глава 2. Путь',
  );

  // Компиляция и сохранение в EPUB или FB2
  final book = await builder.build();
  final epubBytes = await EpubConverter.bookToEpub(book);
  final fb2Bytes = await Fb2Converter.bookToFb2(book);
}
```

---

## Политики именования ресурсов (BookResourceNamingPolicy)

Для управления именами сохраняемых медиа-файлов используется `BookResourceNamingPolicy`:

- **`BookResourceNamingPolicy.preserve` (по умолчанию)**: использует оригинальное имя файла из URL (`chapter1_pic.png`).
- **`BookResourceNamingPolicy.sequential`**: генерирует чистые порядковые имена (`img_001.png`, `img_002.jpg`).
- **`BookResourceNamingPolicy.hash`**: генерирует уникальные имена на основе хэша ссылки (`img_a3f89b1c.png`).
- **`BookResourceNamingPolicy.custom(...)`**: ваша собственная функция генерации имён:
  ```dart
  BookResourceNamingPolicy.custom((src, {required isInline, required index}) {
    return 'custom_ch1_res_$index.png';
  })
  ```

---

## Политика Zero Fallbacks и Strict Mode

В библиотеке строго соблюдается принцип **Zero Fallbacks**: неявные сбросы ошибок заменены на валидацию и исключения:

```dart
class BookDecodingOptions {
  final String? id;
  final String? lang;
  final bool strictMode; // true: выбрасывать явные исключения при ошибках
  final void Function(String warning)? logger; // Колбэк логирования некритичных фолбеков
}
```

### Иерархия исключений (`exceptions.dart`):
- `BookException` — базовое исключение.
- `BookFormatException` — ошибка сигнатуры или целостности ZIP/XML архива.
- `BookParseException` — выбрасывается при обнаружении неизвестных тегов разметки в `strictMode`.
- `BookMalformedMetadataException` — выбрасывается при отсутствии обязательных метаданных (`<dc:title>`, `<book-title>`).

---

## Основной API — класс DartBook

```dart
abstract class DartBook {
  static Future<Book> load(
    Uint8List bytes, {
    String? filename,
    BookDecodingOptions? options,
    BookResourceResolver? resourceResolver,
  });
}
```

---

## Конвертеры

### EpubConverter / EpubDecoder / EpubEncoder
Поддерживает спецификации **W3C EPUB 3.3 и EPUB 3.4**:
- Парсинг OCF Контейнера (`META-INF/container.xml`).
- Детектирование DRM защиты (`META-INF/encryption.xml`) ➔ выбрасывает `EpubEncryptedResourceException`.
- Навигация по EPUB 3 `NAV XHTML` и legacy EPUB 2 `toc.ncx`.
- Извлечение MathML, SVG, `<audio>`, `<video>`, SMIL Media Overlays, шрифтов (OpenType/TrueType) и CSS.

### Fb2Converter / Fb2Decoder / Fb2Encoder
Поддерживает спецификации **FictionBook 2.0, 2.1, 2.2**:
- Извлечение обложек (`<coverpage>`), аннотаций, жанров, серий, ключевых слов.
- Парсинг нативных таблиц `<table>` (`tr`, `td`, `th`, `colspan`, `rowspan`).
- Декодирование эпиграфов (`<epigraph>`), стихов (`<poem>`), `<sub>`, `<sup>`, `<strikethrough>`, `<code>`.
- Обработка второго тела сносок `<body name="notes">` и ссылок на сноски `<a type="note">`.

### Fb2ZipConverter / Fb2ZipDecoder / Fb2ZipEncoder
Специализированный декоратор формата **FB2.ZIP**:
- Упаковка и распаковка ZIP-архивов с сохранением кодировок (автодекодирование `Windows-1251`).
- Полное соблюдение принципа единственной ответственности (SRP).

---

## Зависимости

| Пакет | Версия | Назначение |
|-------|--------|------------|
| [`archive`](https://pub.dev/packages/archive) | `^4.0.7` | Чтение/запись ZIP-архивов (EPUB, FB2.zip) |
| [`html`](https://pub.dev/packages/html) | `^0.15.6` | Разбор HTML5 в `HtmlParser` |
| [`xml`](https://pub.dev/packages/xml) | `^6.5.0` | Разбор и генерация XML (FB2, OPF, NAV, SMIL) |
