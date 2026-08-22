library;

import 'dart:isolate';
import 'dart:typed_data';
import 'src/models/converter.dart';
import 'src/models/encoding_options.dart';
import 'src/converters/registry.dart';
import 'src/converters/resource_resolver.dart';
import 'src/models/book.dart';

export 'src/models/book.dart';
export 'src/models/converter.dart';
export 'src/models/encoding_options.dart';
export 'src/models/exceptions.dart';
export 'src/models/parser.dart';
export 'src/models/resource_naming_policy.dart';
export 'src/builder/book_builder.dart';
export 'src/converters/registry.dart';
export 'src/converters/resource_resolver.dart';
export 'src/converters/resource_requests_collector.dart';

export 'src/converters/epub/epub_converter.dart';
export 'src/converters/epub/epub_decoder.dart';
export 'src/converters/epub/epub_encoder.dart';
export 'src/converters/epub/epub_exceptions.dart';
export 'src/converters/epub/ocf/ocf_container.dart';
export 'src/converters/epub/parsers/epub_nav_parser.dart';
export 'src/converters/epub/parsers/epub_ncx_parser.dart';
export 'src/converters/epub/parsers/epub_smil_parser.dart';

export 'src/converters/fb2/fb2_converter.dart';
export 'src/converters/fb2/fb2_decoder.dart';
export 'src/converters/fb2/fb2_encoder.dart';
export 'src/converters/fb2/fb2_zip_converter.dart';
export 'src/converters/fb2/fb2_zip_decoder.dart';
export 'src/converters/fb2/fb2_zip_encoder.dart';

export 'src/parsers/html_parser.dart';
export 'src/parsers/fb2_parser.dart';

/// Main entry point for the `dart_book` library.
///
/// Provides convenient methods like [load] to read and decode books
/// without needing to manually determine or specify the format.
///
/// Supported formats: **EPUB** and **FB2** (including FB2.zip).
///
/// Example:
/// ```dart
/// final bytes = await File('book.epub').readAsBytes();
/// final book = await DartBook.load(bytes, filename: 'book.epub');
/// print(book.metadata.title);
/// ```
abstract class DartBook {
  /// Loads a book from [bytes], automatically detecting the format.
  ///
  /// Format detection is performed using byte signatures and optional extension
  /// from [filename] via [BookRegistry].
  ///
  /// - [filename]: file name/path; extension is extracted automatically.
  /// - [options]: decoding options (strictMode, custom logger, etc.).
  /// - [resourceResolver]: optional callback to resolve external resources.
  ///
  /// Throws [Exception] if no suitable decoder is found.
  static Future<Book> load(
    Uint8List bytes, {
    String? filename,
    BookDecodingOptions? options,
    BookResourceResolver? resourceResolver,
  }) async {
    final decoder = BookRegistry.findDecoder(
      bytes,
      extension: filename?.split('.').last.toLowerCase(),
    );

    if (decoder == null) {
      throw Exception(
        'Could not find a suitable decoder for file ${filename ?? 'unnamed'}',
      );
    }

    var book = await decoder.decode(bytes, options: options);

    if (resourceResolver != null) {
      book = await book.resolveResources(
        resourceResolver,
        baseUri: book.metadata.source,
      );
    }

    return book;
  }

  /// Loads a book inside a background isolate (`Isolate.run`).
  ///
  /// Recommended for high refresh rate UI apps (120 Hz / 144 FPS)
  /// to ensure 0 ms main UI thread blocking.
  static Future<Book> loadIsolated(
    Uint8List bytes, {
    String? filename,
    BookDecodingOptions? options,
    BookResourceResolver? resourceResolver,
  }) {
    return Isolate.run(
      () => load(
        bytes,
        filename: filename,
        options: options,
        resourceResolver: resourceResolver,
      ),
    );
  }

  /// Encodes a book to the specified format in a background isolate (`Isolate.run`).
  ///
  /// Recommended for heavy encoding workloads (e.g. compressing FB2.ZIP / EPUB)
  /// to ensure 0 ms main UI thread blocking.
  static Future<Uint8List> encodeIsolated(
    Book book,
    String extension, {
    BookEncodingOptions? options,
  }) {
    return Isolate.run(() async {
      final encoder = BookRegistry.findEncoder(extension);
      if (encoder == null) {
        throw Exception(
          'Could not find a suitable encoder for extension $extension',
        );
      }
      return await encoder.encode(book, options: options);
    });
  }
}
