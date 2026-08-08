# dart_book

Dart-библиотека для чтения и записи электронных книг в форматах **EPUB** и **FB2**. Библиотека предоставляет единую формато-независимую модель данных (`Book`), набор парсеров и конвертеров, а также инфраструктуру для разрешения ресурсов (изображений и т.д.).

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
- [Основной API — класс DartBook](#основной-api--класс-dartbook)
- [Конвертеры](#конвертеры)
  - [EpubConverter / EpubDecoder / EpubEncoder](#epubconverter--epubdecoder--epubencoder)
  - [Fb2Converter / Fb2Decoder / Fb2Encoder](#fb2converter--fb2decoder--fb2encoder)
- [Реестр конвертеров (BookRegistry)](#реестр-конвертеров-bookregistry)
- [Парсеры](#парсеры)
  - [HtmlParser](#htmlparser)
  - [Fb2Parser](#fb2parser)
- [Разрешение ресурсов](#разрешение-ресурсов)
- [Интерфейсы конвертеров](#интерфейсы-конвертеров)
- [Зависимости](#зависимости)

---

## Установка

Добавьте в `pubspec.yaml`:

```yaml
dependencies:
  dart_book:
    path: .  # или укажите git-репозиторий / путь к пакету
```

Минимальная версия SDK: `^3.12.0`.

---

## Быстрый старт

```dart
import 'dart:io';
import 'package:dart_book/dart_book.dart';

Future<void> main() async {
  // 1. Загрузить книгу из файла (формат определяется автоматически)
  final bytes = await File('book.epub').readAsBytes();
  final book = await DartBook.load(bytes, filename: 'book.epub');

  print(book.metadata.title);   // название книги
  print(book.metadata.language); // язык
  print(book.resources.length); // количество ресурсов (изображений)

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
DartBook.load()
    │
    ▼
BookRegistry.findDecoder()   ←── EpubConverter / Fb2Converter
    │                                    │
    ▼                             EpubDecoder / Fb2Decoder
  Book (формато-независимая модель)
    │
    ├── BookMetadata
    ├── BookContent
    │     ├── BookBlock (sealed)
    │     └── BookFootnote
    └── List<BookResource>
```

Ключевые уровни абстракции:

| Уровень | Классы | Назначение |
|---------|--------|------------|
| Входная точка | `DartBook` | Загрузка книги из байт с авторазбором формата |
| Модель | `Book`, `BookMetadata`, `BookContent` | Универсальное представление книги |
| Конвертеры | `EpubConverter`, `Fb2Converter` | Чтение/запись конкретных форматов |
| Парсеры | `HtmlParser`, `Fb2Parser` | Разбор разметки в дерево `BookBlock` |
| Реестр | `BookRegistry` | Поиск нужного конвертера по байтам/расширению |
| Ресурсы | `BookResourceResolver`, `resolveBookResources` | Загрузка внешних ресурсов |

---

## Модель данных

### Book

```dart
class Book {
  final String id;                  // уникальный идентификатор книги
  final BookMetadata metadata;      // метаданные (заголовок, авторы, …)
  final BookContent content;        // содержимое (блоки, сноски)
  final List<BookResource> resources; // бинарные ресурсы (изображения, …)

  BookResource? resourceById(String id); // поиск ресурса по id
}
```

`Book` — корневой объект. Все остальные данные доступны через него.

---

### BookMetadata

```dart
class BookMetadata {
  final String title;                     // название книги
  final String language;                  // код языка (ISO 639-1, напр. 'ru')
  final List<BookContributor> contributors; // авторы, переводчики, редакторы, …
  final List<BookGenre> genres;           // жанры
  final List<String> keywords;            // ключевые слова
  final BookContent? annotation;          // аннотация в виде блоков контента
  final BookSeries? series;               // серия книг
  final BookCover? cover;                 // обложка
  final Uri? source;                      // оригинальный URI источника
  final DateTime? updatedAt;              // дата последнего обновления
  final DateTime? publishedAt;            // дата публикации

  /// Возвращает участников с заданной ролью (авторов, переводчиков и т.д.)
  Iterable<BookContributor> contributorsByRole(BookContributorRole role);
}
```

**Вспомогательные классы:**

```dart
class BookGenre {
  final String code;   // код жанра (например, 'sf_fantasy')
  final String? name;  // человекочитаемое название
}

class BookSeries {
  final String name;   // название серии
  final int? number;   // номер книги в серии
  final Uri? url;      // ссылка на серию
}

class BookCover {
  final BookResourceRef ref; // ссылка на ресурс-обложку
  final String? alt;         // альтернативный текст
}
```

---

### BookContent

```dart
class BookContent {
  final List<BookBlock> blocks;        // основные блоки содержимого
  final List<BookFootnote> footnotes;  // сноски
}

class BookFootnote {
  final String id;                     // идентификатор сноски
  final List<BookBlock> blocks;        // содержимое сноски
}
```

---

### BookBlock — блочные элементы

`BookBlock` — sealed-класс. Все блочные элементы являются его подклассами.

| Класс | Описание | Ключевые поля |
|-------|----------|---------------|
| `BookSection` | Раздел/глава | `id`, `title` (инлайны), `blocks`, `children` |
| `BookHeading` | Заголовок | `level` (1–6), `text` (инлайны) |
| `BookParagraph` | Абзац | `inlines` |
| `BookQuote` | Цитата/blockquote | `blocks`, `citation` (инлайны) |
| `BookList` | Список | `ordered` (нумерованный/маркированный), `items` |
| `BookListItem` | Элемент списка | `blocks` |
| `BookTable` | Таблица | `rows` |
| `BookTableRow` | Строка таблицы | `cells` |
| `BookTableCell` | Ячейка таблицы | `blocks`, `colSpan`, `rowSpan` |
| `BookPoem` | Стихотворение | `stanzas` |
| `BookStanza` | Строфа | `lines` |
| `BookPoemLine` | Строка стихотворения | `inlines` |
| `BookImageBlock` | Изображение (блочное) | `ref`, `alt`, `title` |
| `BookHorizontalRule` | Горизонтальная линия | — |
| `BookEmptyLine` | Пустая строка | — |
| `BookCodeBlock` | Блок кода | `code`, `language` |
| `BookRawHtmlBlock` | Сырой HTML-блок | `html` |
| `BookRawXmlBlock` | Сырой XML-блок | `xml` |

Общий базовый класс `BookNode` имеет поле `attributes: Map<String, String>` — словарь произвольных атрибутов, сохраняющих метаинформацию из исходного формата (например, `source-id`, `source-src`).

**Пример обхода контента:**

```dart
void printContent(List<BookBlock> blocks, {int depth = 0}) {
  final indent = '  ' * depth;
  for (final block in blocks) {
    switch (block) {
      case BookSection s:
        print('${indent}[Section] ${_inlinesToText(s.title)}');
        printContent(s.blocks, depth: depth + 1);
      case BookHeading h:
        print('${indent}[H${h.level}] ${_inlinesToText(h.text)}');
      case BookParagraph p:
        print('${indent}[P] ${_inlinesToText(p.inlines)}');
      case BookImageBlock img:
        print('${indent}[Image] ref=${img.ref.id}');
      default:
        print('${indent}[${block.runtimeType}]');
    }
  }
}
```

---

### BookInline — строчные элементы

`BookInline` — sealed-класс для строчного (inline) контента внутри абзацев, заголовков и т.д.

| Класс | Описание | Ключевые поля |
|-------|----------|---------------|
| `BookText` | Обычный текст | `text` |
| `BookLineBreak` | Перенос строки | — |
| `BookEmphasis` | Курсив / выделение | `children` |
| `BookStrong` | Жирный текст | `children` |
| `BookStrike` | Зачёркнутый текст | `children` |
| `BookCodeSpan` | Строчный код | `code` |
| `BookLink` | Гиперссылка | `href` (Uri), `children` |
| `BookAnchor` | Якорь | `id` |
| `BookImageInline` | Строчное изображение | `ref`, `alt` |
| `BookSuperscript` | Надстрочный индекс | `children` |
| `BookSubscript` | Подстрочный индекс | `children` |
| `BookFootnoteRef` | Ссылка на сноску | `id`, `label` |
| `BookRawHtmlInline` | Сырой HTML-инлайн | `html` |
| `BookRawXmlInline` | Сырой XML-инлайн | `xml` |

---

### BookResource

Представляет бинарный ресурс (изображение, шрифт и т.д.), встроенный в книгу.

```dart
class BookResource {
  final String id;           // уникальный идентификатор ресурса
  final String mediaType;    // MIME-тип (например, 'image/jpeg')
  final Uint8List bytes;     // бинарные данные
  final String? fileName;    // исходное имя файла (опционально)
  final Uri? originalUri;    // исходный URI (опционально)
}

class BookResourceRef {
  final String id; // ссылка на BookResource.id
}
```

---

### BookContributor и PersonName

```dart
class BookContributor {
  final BookContributorRole role; // роль участника
  final PersonName name;          // имя
  final Uri? homePage;            // личная страница
  final String? email;            // e-mail
}

enum BookContributorRole {
  author,       // автор
  translator,   // переводчик
  editor,       // редактор
  illustrator,  // иллюстратор
  narrator,     // чтец
  compiler,     // составитель
  other,        // иная роль
}

class PersonName {
  final String? first;    // имя
  final String? middle;   // отчество
  final String? last;     // фамилия
  final String? nickname; // псевдоним
  final String? display;  // явное отображаемое имя (приоритетно)

  /// Возвращает строку для отображения: display > "Имя Отчество Фамилия" > nickname
  String toDisplayString();
}
```

---

## Основной API — класс DartBook

```dart
abstract class DartBook {
  static Future<Book> load(
    Uint8List bytes, {
    String? filename,              // имя файла (используется для определения расширения)
    BookDecodingOptions? options,  // параметры декодирования: ({String? id, String? lang})
    BookResourceResolver? resourceResolver, // функция для загрузки внешних ресурсов
  });
}
```

`DartBook.load()` — единая точка входа для загрузки книги:

1. Ищет подходящий декодер через `BookRegistry.findDecoder()` (по сигнатуре байт и/или расширению файла).
2. Декодирует байты в объект `Book`.
3. Если передан `resourceResolver`, вызывает `resolveBookResources()` для подгрузки внешних ресурсов.

```dart
// Пример с resourceResolver (например, для HTML-источника)
final book = await DartBook.load(
  htmlBytes,
  filename: 'article.html',
  options: (id: 'article-001', lang: 'ru'),
  resourceResolver: (request) async {
    final response = await http.get(Uri.parse(request.id));
    return BookResource(
      id: request.id,
      mediaType: response.headers['content-type'] ?? 'application/octet-stream',
      bytes: response.bodyBytes,
    );
  },
);
```

**`BookDecodingOptions`** — именованный record:

```dart
typedef BookDecodingOptions = ({String? id, String? lang});

// Использование:
const options = (id: 'my-book-id', lang: 'ru');
```

---

## Конвертеры

### EpubConverter / EpubDecoder / EpubEncoder

**`EpubConverter`** реализует `BookConverter` (объединяет `BookDecoder` + `BookEncoder`).

```dart
// Декодирование
final book = await EpubConverter().decode(epubBytes);

// Кодирование
final epubBytes = await EpubConverter().encode(book);

// Статические хелперы
final book = await EpubConverter.epubToBook(bytes, id: 'my-id');
final epub = await EpubConverter.bookToEpub(book);
```

**`EpubDecoder`** — логика декодирования EPUB:

- Разбирает ZIP-архив.
- Читает `META-INF/container.xml` → находит OPF-файл.
- Из OPF извлекает метаданные (заголовок, язык, авторы), manifest и spine.
- Каждый spine-элемент парсится через `HtmlParser`.
- Все изображения из manifest упаковываются в `BookResource`.

**`EpubEncoder`** — логика кодирования в EPUB 3.0:

- Создаёт валидный ZIP со структурой EPUB.
- Генерирует `mimetype`, `META-INF/container.xml`, `OEBPS/content.opf`, `OEBPS/nav.xhtml`.
- Каждую `BookSection` из content преобразует в отдельный XHTML-файл.
- Все `BookResource` сохраняются в `OEBPS/resources/`.

**Определение формата:**

`EpubConverter.canDecode()` принимает файл за EPUB если:
- расширение == `epub`, **или**
- первые байты — ZIP-сигнатура (`PK\x03\x04`) **и** байты 30–58 содержат `mimetypeapplication/epub+zip`.

---

### Fb2Converter / Fb2Decoder / Fb2Encoder

**`Fb2Converter`** реализует `BookConverter`.

```dart
// Декодирование
final book = Fb2Converter().decode(fb2Bytes);

// Кодирование
final fb2Bytes = await Fb2Converter().encode(book);

// Статические хелперы
final book = Fb2Converter.fb2ToBook(bytes, options: (id: null, lang: null));
final fb2  = await Fb2Converter.bookToFb2(book);
```

**`Fb2Decoder`** — логика декодирования FB2:

- Поддерживает FB2 как в виде чистого XML, так и упакованным в ZIP (`fb2.zip`).
- Извлекает метаданные из `<description>/<title-info>` (заголовок, язык, авторы).
- `<binary>` элементы раскодируются из Base64 и сохраняются как `BookResource`.
- Контент из `<body>` парсится через `Fb2Parser`; body с `name="notes"` обрабатывается как сноски (игнорируется в основном контенте).

**Определение формата:**

`Fb2Decoder.canDecode()` принимает файл за FB2 если:
- расширение == `fb2` или `fb2.zip`, **или**
- начало файла содержит `<?xml` или `<fictionbook`, **или**
- это ZIP-файл без EPUB-сигнатуры.

**`Fb2Encoder`** — логика кодирования в FB2:

Генерирует полноценный XML-документ в формате FictionBook 2.0:

```
<FictionBook>
  <description>
    <title-info>     ← метаданные
    <document-info>  ← сервисная информация
  <body>             ← основной контент
  <body name="notes"> ← сноски (если есть)
  <binary id="...">  ← Base64-закодированные ресурсы
```

Таблица соответствия модели и FB2-тегов:

| `BookBlock` / `BookInline` | FB2 тег |
|--------------------------|---------|
| `BookSection` | `<section>` |
| `BookParagraph` | `<p>` |
| `BookHeading` | `<subtitle>` |
| `BookQuote` | `<cite>` |
| `BookList` | `<p>` с префиксом `• ` / `1.` |
| `BookTable` | `<p>` (строки объединяются через ` | `) |
| `BookPoem` | `<poem>/<stanza>/<v>` |
| `BookImageBlock` | `<image l:href="#id">` |
| `BookEmptyLine` / `BookHorizontalRule` | `<empty-line>` |
| `BookCodeBlock` | `<p>` (по строке) |
| `BookEmphasis` | `<emphasis>` |
| `BookStrong` | `<strong>` |
| `BookStrike` | `<strikethrough>` |
| `BookLink` | `<a l:href="...">` |
| `BookFootnoteRef` | `<a l:href="#id" type="note">` |
| `BookSuperscript` | `<sup>` |
| `BookSubscript` | `<sub>` |

> **Примечание:** FB2 поддерживает не все элементы модели нативно. `BookTable` приводится к текстовому представлению, сырой HTML/XML оборачивается в `<p>`.

---

## Реестр конвертеров (BookRegistry)

`BookRegistry` — статический реестр, хранящий списки зарегистрированных декодеров и энкодеров.

```dart
// Найти декодер автоматически (по сигнатуре байт и/или расширению)
BookDecoder? decoder = BookRegistry.findDecoder(bytes, extension: 'epub');

// Найти энкодер по расширению
BookEncoder? encoder = BookRegistry.findEncoder('fb2');

// Зарегистрировать собственный конвертер (вставляется в начало списка,
// то есть имеет приоритет над встроенными)
BookRegistry.registerDecoder(MyCustomDecoder());
BookRegistry.registerEncoder(MyCustomEncoder());
```

По умолчанию зарегистрированы: `EpubConverter` и `Fb2Converter`.

`findDecoder` перебирает декодеры и возвращает первый, для которого `canDecode()` вернул `true`. Возвращает `null`, если подходящего декодера нет.

---

## Парсеры

Парсеры преобразуют разметку (HTML/XML) в список `BookBlock`. Оба реализуют интерфейс:

```dart
abstract interface class Parser<T> {
  BookResourceRegistrar? get registrar;

  List<BookBlock> parseFragment(String text);  // парсинг строки
  List<BookBlock> parse(T data);               // парсинг структурированных данных
}

typedef BookResourceRegistrar = String Function(
  String src, {
  required bool isInline,
});
```

`BookResourceRegistrar` — callback, вызываемый при встрече ресурса (`<img src="...">`, `<image l:href="...">`). Принимает оригинальный `src`, возвращает нормализованный `id` ресурса для `BookResourceRef`.

### HtmlParser

Парсит HTML в `List<BookBlock>`. Использует пакет `html`.

```dart
final parser = HtmlParser(
  registrar: (src, {required isInline}) {
    // нормализовать URL → id ресурса
    return Uri.parse(src).pathSegments.last;
  },
);

// Из строки HTML
final blocks = parser.parseFragment('<h1>Заголовок</h1><p>Текст</p>');

// Из уже разобранных узлов
import 'package:html/dom.dart' as dom;
final blocks = parser.parse(domElement.nodes);
```

**Таблица соответствия HTML → модель:**

| HTML тег | `BookBlock` / `BookInline` |
|----------|--------------------------|
| `<section>`, `<article>` | `BookSection` |
| `<h1>`–`<h6>` | `BookHeading` (level соответственно) |
| `<p>` | `BookParagraph` |
| `<blockquote>` | `BookQuote` |
| `<ul>` | `BookList(ordered: false)` |
| `<ol>` | `BookList(ordered: true)` |
| `<pre>` | `BookCodeBlock` |
| `<hr>` | `BookHorizontalRule` |
| `<br>` (блочный) | `BookEmptyLine` |
| `<img>` (блочный) | `BookImageBlock` |
| `<table>` | `BookTable` |
| `<div>`, `<main>`, `<body>` | прозрачный контейнер (рекурсивный разбор) |
| прочие блочные теги | `BookRawHtmlBlock` |
| `<strong>`, `<b>` | `BookStrong` |
| `<em>`, `<i>`, `<u>` | `BookEmphasis` |
| `<s>`, `<del>`, `<strike>` | `BookStrike` |
| `<code>` | `BookCodeSpan` |
| `<sup>` | `BookSuperscript` |
| `<sub>` | `BookSubscript` |
| `<a href="...">` | `BookLink` |
| `<img>` (строчный) | `BookImageInline` |
| `<br>` (строчный) | `BookLineBreak` |
| `<span>`, `<small>`, `<mark>`, `<abbr>` | прозрачный контейнер |
| прочие строчные теги | `BookRawHtmlInline` |

Языка кода в `BookCodeBlock` определяется из атрибутов `data-language`, `lang` или `class` тега `<pre>`.

### Fb2Parser

Парсит XML-узлы FictionBook 2 в `List<BookBlock>`.

```dart
final parser = Fb2Parser(
  registrar: (src, {required isInline}) {
    // FB2: внутренние ресурсы имеют вид '#image-id'
    return src.startsWith('#') ? src.substring(1) : src;
  },
);

// Из строки (может быть полный документ FictionBook или фрагмент)
final blocks = parser.parseFragment(xmlString);

// Из XML-узлов
final blocks = parser.parse(xmlElement.children);
```

**Таблица соответствия FB2 → модель:**

| FB2 элемент | `BookBlock` / `BookInline` |
|-------------|--------------------------|
| `<section>` | `BookSection` |
| `<p>` | `BookParagraph` |
| `<subtitle>` | `BookHeading(level: 2)` |
| `<empty-line>` | `BookEmptyLine` |
| `<image>` (блочный) | `BookImageBlock` |
| `<body>` | прозрачный контейнер |
| `<strong>` | `BookStrong` |
| `<emphasis>` | `BookEmphasis` |
| `<a l:href="...">` | `BookLink` |
| `<image>` (строчный) | `BookImageInline` |

При передаче полного документа (`<FictionBook>`) в `parseFragment`, тела (`<body>`) с атрибутом `name="notes"` пропускаются.

---

## Разрешение ресурсов

Функция `resolveBookResources` позволяет дополнить книгу ресурсами, отсутствующими в исходном архиве (например, загрузить изображения по URL).

```dart
import 'package:dart_book/dart_book.dart';

final enrichedBook = await resolveBookResources(
  book,
  (BookResourceRequest request) async {
    if (request.baseUri != null) {
      final uri = request.baseUri!.resolve(request.id);
      final response = await http.get(uri);
      return BookResource(
        id: request.id,
        mediaType: response.headers['content-type'] ?? 'image/jpeg',
        bytes: response.bodyBytes,
      );
    }
    return null; // ресурс недоступен — пропустить
  },
  baseUri: Uri.parse('https://example.com/books/'),
);
```

**`BookResourceRequest`** — описывает запрос на ресурс:

```dart
class BookResourceRequest {
  final String id;      // идентификатор/путь ресурса
  final String? source; // оригинальный src (если сохранён в attributes)
  final Uri? baseUri;   // базовый URI книги
  final bool isInline;  // true — строчный ресурс, false — блочный
}
```

**`BookResourceResolver`** — тип функции-резолвера:

```dart
typedef BookResourceResolver = FutureOr<BookResource?> Function(
  BookResourceRequest request,
);
```

### Внутренний сборщик ресурсов

`collectResourceRequestsFromBook(Book book)` — возвращает список всех `BookResourceRequest`, встречающихся в:
- `book.content.blocks` (рекурсивно)
- `book.metadata.annotation` (если есть)

Используется внутри `resolveBookResources` для определения необходимых запросов.

---

## Интерфейсы конвертеров

```dart
abstract interface class BookDecoder {
  /// Возвращает true, если декодер поддерживает данный формат.
  /// Определение может основываться на сигнатуре байт и/или расширении файла.
  bool canDecode(Uint8List bytes, {String? extension});

  /// Декодирует байты в модель Book.
  FutureOr<Book> decode(Uint8List bytes, {BookDecodingOptions? options});
}

abstract interface class BookEncoder {
  /// Возвращает true, если энкодер поддерживает данное расширение файла.
  bool canEncode(String extension);

  /// Кодирует модель Book в байты.
  FutureOr<Uint8List> encode(Book book);
}

/// Объединяет BookDecoder и BookEncoder.
abstract interface class BookConverter implements BookEncoder, BookDecoder {}
```

Для реализации поддержки нового формата достаточно реализовать `BookConverter` и зарегистрировать его:

```dart
class MyFormatConverter implements BookConverter {
  @override
  bool canDecode(Uint8List bytes, {String? extension}) =>
      extension == 'myformat';

  @override
  FutureOr<Book> decode(Uint8List bytes, {BookDecodingOptions? options}) {
    // … разбор формата …
  }

  @override
  bool canEncode(String extension) => extension == 'myformat';

  @override
  FutureOr<Uint8List> encode(Book book) {
    // … сборка формата …
  }
}

// Регистрация
BookRegistry.registerDecoder(MyFormatConverter());
BookRegistry.registerEncoder(MyFormatConverter());
```

---

## Зависимости

| Пакет | Версия | Использование |
|-------|--------|---------------|
| [`archive`](https://pub.dev/packages/archive) | `^4.0.7` | Чтение/запись ZIP-архивов (EPUB, FB2.zip) |
| [`html`](https://pub.dev/packages/html) | `^0.15.6` | Разбор HTML в `HtmlParser` |
| [`xml`](https://pub.dev/packages/xml) | `^6.5.0` | Разбор и построение XML для FB2/EPUB |

Dev-зависимости: `lints ^6.1.0`, `test ^1.29.0`.
