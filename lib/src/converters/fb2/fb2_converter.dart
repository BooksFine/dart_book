import 'dart:async';
import 'dart:typed_data';

import '../../models/book.dart';
import '../../models/converter.dart';
import '../../models/encoding_options.dart';
import 'fb2_decoder.dart';
import 'fb2_encoder.dart';
import 'fb2_zip_converter.dart';

/// Конвертер для формата FictionBook 2 (FB2).
///
/// Реализует [BookConverter], объединяя [Fb2Decoder] и [Fb2Encoder].
/// Поддерживает расширения `fb2`, `xml` для кодирования,
/// а также чтение FB2 из ZIP-архивов (`fb2.zip`).
///
/// Пример:
/// ```dart
/// final book = Fb2Converter.fb2ToBook(bytes);
/// final fb2  = await Fb2Converter.bookToFb2(book);
/// ```
class Fb2Converter implements BookConverter {
  final _decoder = Fb2Decoder();
  final _encoder = Fb2Encoder();

  @override
  bool canDecode(Uint8List bytes, {String? extension}) =>
      _decoder.canDecode(bytes, extension: extension);

  @override
  FutureOr<Book> decode(Uint8List bytes, {BookDecodingOptions? options}) =>
      _decoder.decode(bytes, options: options);

  @override
  bool canEncode(String extension) => _encoder.canEncode(extension);

  @override
  FutureOr<Uint8List> encode(Book book, {BookEncodingOptions? options}) =>
      _encoder.encode(book, options: options);

  /// Удобный статический метод: кодирует [book] в FB2 (байты UTF-8 XML или ZIP-архив).
  ///
  /// [isZip] — при `true` упаковывает результат в `fb2.zip`.
  /// [resourceResolver] — если передан, сначала дополняет ресурсы за счёт
  /// загрузки внешних ресурсов перед кодированием.
  static Future<Uint8List> bookToFb2(
    Book book, {
    bool isZip = false,
    BookResourceResolver? resourceResolver,
  }) async {
    if (isZip) {
      return await Fb2ZipConverter.bookToFb2Zip(
        book,
        resourceResolver: resourceResolver,
      );
    }
    return await Fb2Encoder().encode(
      book,
      resourceResolver: resourceResolver,
    );
  }

  /// Удобный статический метод: кодирует [book] прямо в `fb2.zip` архив.
  static Future<Uint8List> bookToFb2Zip(
    Book book, {
    BookResourceResolver? resourceResolver,
  }) async {
    return await bookToFb2(
      book,
      isZip: true,
      resourceResolver: resourceResolver,
    );
  }

  /// Удобный статический метод: декодирует FB2 из [bytes].
  static Book fb2ToBook(Uint8List bytes, {BookDecodingOptions? options}) =>
      Fb2Decoder().decode(bytes, options: options);
}
