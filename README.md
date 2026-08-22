# dart_book

[English version](README.md) | [Русская версия](README.ru.md)

[![Tests](https://img.shields.io/badge/tests-158%20passed-brightgreen.svg)](#)
[![Coverage](https://img.shields.io/badge/coverage-96.8%25-brightgreen.svg)](#)
[![Branch Coverage](https://img.shields.io/badge/branch%20coverage-93.6%25-brightgreen.svg)](#)
[![Dart SDK](https://img.shields.io/badge/Dart-3.3+-blue.svg)](pubspec.yaml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

A high-performance Dart library for parsing, serializing, and converting electronic book formats: **EPUB** (2.0.1, 3.0–3.4) and **FB2** (2.0, 2.1, 2.2, FB2.zip).

At the core of the library is a unified syntax tree (`Book` AST). Book formats are converted into strongly-typed blocks and inline elements, allowing you to manipulate book content completely independently of the underlying markup.

---

## Features

- **Formats & Conversion:** Read, assemble, and perform bidirectional conversion between EPUB (2.0.1, 3.0–3.4), FB2 (2.0–2.2), and FB2.zip archives.
- **HTML5 Parsing & Book Building:** Direct HTML5 parsing (`HtmlParser`) into AST blocks and a chapter-by-chapter `BookBuilder` for assembling books from web scrapers, CMS, or feeds.
- **Rich Document Structure:** Full support for chapters, hierarchical table of contents, footnotes, complex tables (`colspan`, `rowspan`), code blocks, poems, blockquotes, MathML formulas, vector SVG, audio, and video.
- **Metadata & Resources:** Extract authors, translators, series/sequences, publishing info, original language/title, book covers, fonts, stylesheets, and media files.
- **Audio Synchronization (SMIL 3.0):** Extract audio tracks and parse sync timestamps for audiobooks (Media Overlays).

## Architecture & Reliability

- **Unified AST:** The document is modeled as a strongly typed Dart 3 `sealed class` hierarchy with exhaustive pattern matching support.
- **Background Isolates:** Offload heavy parsing and encoding to `Isolate.run` to ensure 0 ms UI thread blocking (60/120/144 FPS friendly).
- **Error Resilient:** Automatic character encoding detection (UTF-8, Windows-1251), sanitization of malformed XML 1.0, automatic font deobfuscation (IDPF, Adobe), and safe in-memory archive operations.
- **Extensible:** Register custom decoders and encoders with priority overrides via `BookRegistry`.

---

## Installation

Add `dart_book` as a Git dependency in your `pubspec.yaml`:

```yaml
dependencies:
  dart_book:
    git:
      url: https://github.com/BooksFine/dart_book.git
      ref: v0.1.0
```

Or install the latest commit from `main`:
```yaml
dependencies:
  dart_book:
    git:
      url: https://github.com/BooksFine/dart_book.git
      ref: main
```

---

## Quick Start

### 1. Read a Book and Inspect Metadata

```dart
import 'dart:io';
import 'package:dart_book/dart_book.dart';

void main() async {
  final bytes = await File('book.epub').readAsBytes();
  final book = await DartBook.load(bytes);

  print('Title: ${book.metadata.title}');
  print('Language: ${book.metadata.language}');
  print('Authors: ${book.metadata.contributors.map((c) => c.name.display).join(', ')}');
  print('Chapters: ${book.content.blocks.length}');
}
```

### 2. Format Conversion

```dart
import 'dart:io';
import 'package:dart_book/dart_book.dart';

void main() async {
  final fb2Bytes = await File('input.fb2').readAsBytes();
  final book = await DartBook.load(fb2Bytes);

  // Convert to EPUB 3 with Dual Navigation (NAV + NCX)
  final epubBytes = await EpubConverter.bookToEpub(book);
  await File('output.epub').writeAsBytes(epubBytes);

  // Convert to FB2.zip
  final fb2ZipBytes = await Fb2Converter.bookToFb2Zip(book);
  await File('output.fb2.zip').writeAsBytes(fb2ZipBytes);
}
```

### 3. Extract Cover and Binary Resources

```dart
import 'package:dart_book/dart_book.dart';

void extractAssets(Book book) {
  // Extract book cover
  if (book.metadata.cover != null) {
    final coverRef = book.metadata.cover!.ref.id;
    final coverResource = book.resourceById(coverRef);
    if (coverResource != null) {
      print('Cover: ${coverResource.mediaType}, ${coverResource.bytes.length} bytes');
    }
  }

  // Iterate over all image resources
  final images = book.resources.where((r) => r.mediaType.startsWith('image/'));
  for (final img in images) {
    print('Image: ${img.id} (${img.mediaType})');
  }
}
```

### 4. Step-by-Step Book Assembly with `BookBuilder`

```dart
import 'package:dart_book/dart_book.dart';

Future<Book> createBook() async {
  final builder = BookBuilder(
    title: 'The Chronicles',
    language: 'en',
    contributors: const [
      BookContributor(
        role: BookContributorRole.author,
        name: PersonName(first: 'John', last: 'Doe', display: 'John Doe'),
      ),
    ],
    genres: const [BookGenre(code: 'sf_fantasy', name: 'Fantasy')],
  );

  // Add annotation and chapters from HTML
  builder.setAnnotationHtml('<p>A brief summary of the book.</p>');
  await builder.addChapterHtml('<h2>Chapter 1</h2><p>The story begins...</p>', title: 'Chapter 1');
  await builder.addChapterHtml('<h2>Chapter 2</h2><p>The journey continues...</p>', title: 'Chapter 2');

  return await builder.build();
}
```

### 5. Content Traversal (Pattern Matching)

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
        print('Paragraph: $text');

      case BookTable(:final rows):
        print('Table: ${rows.length} rows');

      case BookQuote(:final citation):
        final cite = citation.whereType<BookText>().map((c) => c.text).join();
        print('Quote: $cite');

      case BookSection(:final title):
        final titleText = title.whereType<BookText>().map((t) => t.text).join();
        print('Section: $titleText');

      default:
    }
  }
}
```

### 6. Background Parsing with Isolates

```dart
// Parse heavy book files in Isolate.run without blocking the UI thread
final book = await DartBook.loadIsolated(
  bytes,
  filename: 'large_book.epub',
);
```

---

## API

### Class `DartBook`

```dart
abstract class DartBook {
  /// Loads a book with automatic format detection
  static Future<Book> load(
    Uint8List bytes, {
    String? filename,
    BookDecodingOptions? options,
    BookResourceResolver? resourceResolver,
  });

  /// Loads a book in a background isolate
  static Future<Book> loadIsolated(
    Uint8List bytes, {
    String? filename,
    BookDecodingOptions? options,
    BookResourceResolver? resourceResolver,
  });

  /// Encodes a book in an isolate ('epub', 'fb2', 'fb2.zip')
  static Future<Uint8List> encodeIsolated(
    Book book,
    String extension, {
    BookEncodingOptions? options,
  });
}
```

### Converters

- `EpubConverter.epubToBook(bytes, {options})` — decode an EPUB archive into `Book`.
- `EpubConverter.bookToEpub(book, {options})` — encode a `Book` into EPUB 3 with dual navigation (NAV + NCX).
- `Fb2Converter.fb2ToBook(bytes, {options})` — decode FB2 XML (UTF-8, Windows-1251).
- `Fb2Converter.bookToFb2(book, {isZip = false, options})` — serialize a `Book` to FB2 XML.
- `Fb2Converter.bookToFb2Zip(book, {resourceResolver})` — package a `Book` into `.fb2.zip`.

### HTML Parser `HtmlParser`

Parses HTML5 strings or document fragments directly into AST blocks:

```dart
final parser = HtmlParser();
final blocks = parser.parseFromString('<p>Article text with <strong>bold</strong> styling</p>');
```

### Book Builder `BookBuilder`

Enables incremental book construction from HTML with automatic parallel image fetching:

```dart
final builder = BookBuilder(title: 'My Book', language: 'en');
await builder.addChapterHtml('<h2>Chapter 1</h2><p>Content...</p>', title: 'Chapter 1');
final book = await builder.build();
```

### Format Registry `BookRegistry`

Register custom decoders and encoders with priority over built-in handlers:

```dart
// Register a custom decoder
BookRegistry.registerDecoder(MyCustomFormatDecoder());

// Register a custom encoder
BookRegistry.registerEncoder(MyCustomFormatEncoder());
```

### Remote Resource Resolver `BookResourceResolver`

For books referencing external resources, supply an asynchronous resolver:

```dart
final book = await DartBook.load(
  bytes,
  resourceResolver: (request, {onByteProgress}) async {
    // request.source contains the original URL or relative path
    // onByteProgress(received, total) streams download progress
    final response = await http.get(Uri.parse(request.source!));
    return BookResource(
      id: request.id,
      mediaType: response.headers['content-type'] ?? 'image/jpeg',
      bytes: response.bodyBytes,
    );
  },
);
```

### Options

```dart
final decodingOptions = BookDecodingOptions(
  strictMode: false,             // true to throw on unknown tags or validation errors
  logger: (warn) => print(warn), // Custom warning logger
);

const encodingOptions = BookEncodingOptions(
  documentId: 'DOC-12345',
  programUsed: 'dart_book',
  entryFilename: 'book.fb2',
  namingPolicy: BookResourceNamingPolicy.preserve, // preserve, sequential, hash, custom
  pretty: true,
  compressZip: true,                              // false disables Deflate compression for fast exports
);
```

### Exceptions

- `BookException` — Base exception class.
  - `BookFormatException` — Invalid file format or corrupted ZIP signature.
  - `BookParseException` — Markup parsing error (includes `tag` and `line` information).
  - `BookMalformedMetadataException` — Missing mandatory metadata in strict mode.
  - `EpubException` — Base EPUB exception.
    - `EpubEncryptedResourceException` — Detected DRM-encrypted resources.
    - `EpubInvalidPackageException` — Malformed OCF/OPF container structure.

---

## Data Model (AST)

- **`Book`**: Root node (`metadata`, `content`, `resources`).
  - `resourceById(id)` — Find a resource by its identifier.
- **`BookMetadata`**: Title, language, authors (`BookContributor`), translators, genres, series/sequences, publishing info (`BookPublishInfo`), original language/title (`srcLang`, `srcTitleInfo`), layout mode (`layout`), annotation, cover (`BookCover`).
  - `primarySeries` — Primary series of the book.
  - `contributorsByRole(role)` — Filter contributors by role.
- **`BookBlock`**:
  - `BookSection` — Section / Chapter (`title`, `blocks`, `children`).
  - `BookHeading` — Heading (`level`, `text`).
  - `BookParagraph` — Paragraph (`inlines`).
  - `BookQuote` — Blockquote or epigraph (`blocks`, `citation`).
  - `BookList` — Ordered or unordered list (`ordered`, `items`).
  - `BookTable` — Table (`rows` -> `cells` with `colSpan`, `rowSpan`, `align`, `vAlign`).
  - `BookPoem` — Poem (`stanzas` -> `lines`).
  - `BookCodeBlock` — Code snippet block (`code`, `language`).
  - `BookImageBlock` — Block image (`ref`, `id`, `alt`, `title`).
  - `BookAudioBlock` / `BookVideoBlock` — Embedded media (`ref`, `posterRef`, `controls`).
  - `BookMathBlock` — MathML block (`mathml`).
  - `BookSvgBlock` — SVG block (`svg`).
  - `BookHorizontalRule` / `BookEmptyLine` — Dividers and spacing.
  - `BookRawHtmlBlock` / `BookRawXmlBlock` — Raw markup fallback.
- **`BookInline`**:
  - `BookText`, `BookEmphasis`, `BookStrong`, `BookStrike`.
  - `BookCodeSpan`, `BookNamedStyle`.
  - `BookLink`, `BookAnchor`, `BookFootnoteRef`.
  - `BookImageInline`.
  - `BookSuperscript`, `BookSubscript`.
  - `BookLineBreak`.
- **`BookResource`**: Binary payload (images, fonts, audio, CSS) with MIME types and IDs.


---

## Testing

The test suite consists of **158 tests**:

| Metric | Value | Details |
| :--- | :---: | :--- |
| **Tests** | 158 / 158 passed | Unit, Integration, Golden Master, Security, Fuzzing |
| **Line Coverage** | 96.83% | Handwritten library code line coverage |
| **Branch Coverage** | 93.6% | Logic and branch coverage |
| **Static Analysis** | 0 issues | `dart analyze --fatal-infos` |

### Running Tests:
```bash
# Static analysis
dart analyze

# Run test suite
dart test

# Calculate code coverage
dart run tool/calculate_handwritten_coverage.dart

# Cyclomatic complexity check
dart run tool/calculate_ccn.dart

# Run performance benchmarks
dart test test/stress/performance_benchmark_test.dart
```

---

## Specifications Compliance

A detailed compliance matrix for EPUB (2.0.1, 3.0–3.4) and FB2 (2.0–2.2) standards is available in:  
[SPECIFICATIONS.md](SPECIFICATIONS.md) ([Русская версия](SPECIFICATIONS.ru.md))

---

## License

Apache 2.0. See [LICENSE](LICENSE).
