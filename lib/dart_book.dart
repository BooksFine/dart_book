library;

import 'dart:typed_data';
import 'src/models/converter.dart';
import 'src/converters/registry.dart';
import 'src/converters/resource_resolver.dart';
import 'src/models/book.dart';

export 'src/models/book.dart';
export 'src/models/converter.dart';
export 'src/models/exceptions.dart';
export 'src/models/parser.dart';
export 'src/models/resource_naming_policy.dart';
export 'src/builder/book_builder.dart';
export 'src/converters/registry.dart';
export 'src/converters/resource_resolver.dart';

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

export 'src/parsers/html_parser.dart';
export 'src/parsers/fb2_parser.dart';

/// Главная точка входа библиотеки `dart_book`.
///
/// Предоставляет удобный метод [load] для загрузки книги
/// из байт без необходимости вручную выбирать формат.
///
/// Поддерживаемые форматы: **EPUB** и **FB2** (FB2.zip).
///
/// Пример:
/// ```dart
/// final bytes = await File('book.epub').readAsBytes();
/// final book = await DartBook.load(bytes, filename: 'book.epub');
/// print(book.metadata.title);
/// ```
abstract class DartBook {
  /// Загружает книгу из [bytes], автоматически определяя формат.
  ///
  /// Юрмат определяется по сигнатуре байт и расширению из [filename]
  /// через [BookRegistry].
  ///
  /// - [filename] — имя файла; расширение извлекается автоматически.
  /// - [options] — опции декодирования: идентификатор книги и код языка.
  /// - [resourceResolver] — callback для загрузки внешних ресурсов.
  ///
  /// Бросает [Exception], если подходящий декодер не найден.
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
        'Не удалось найти подходящий декодер для файла ${filename ?? 'без имени'}',
      );
    }

    var book = await decoder.decode(bytes, options: options);

    if (resourceResolver != null) {
      book = await resolveBookResources(
        book,
        resourceResolver,
        baseUri: book.metadata.source,
      );
    }

    return book;
  }
}
