import 'dart:async';
import 'dart:typed_data';

import '../../models/book.dart';
import '../../models/converter.dart';
import '../../models/encoding_options.dart';
import 'fb2_zip_decoder.dart';
import 'fb2_zip_encoder.dart';

/// Конвертер формата FB2.ZIP (ZIP-архив с FB2 XML документом).
class Fb2ZipConverter implements BookConverter {
  final _decoder = Fb2ZipDecoder();
  final _encoder = Fb2ZipEncoder();

  @override
  bool canDecode(Uint8List bytes, {String? extension}) =>
      _decoder.canDecode(bytes, extension: extension);

  @override
  Book decode(Uint8List bytes, {BookDecodingOptions? options}) =>
      _decoder.decode(bytes, options: options);

  @override
  bool canEncode(String extension) => _encoder.canEncode(extension);

  @override
  FutureOr<Uint8List> encode(Book book, {BookEncodingOptions? options}) =>
      _encoder.encode(book, options: options);

  /// Удобный статический метод: кодирует [book] прямо в `fb2.zip` архив.
  static Future<Uint8List> bookToFb2Zip(
    Book book, {
    BookResourceResolver? resourceResolver,
  }) async {
    return await Fb2ZipEncoder().encode(
      book,
      resourceResolver: resourceResolver,
    );
  }

  /// Удобный статический метод: декодирует книгу из байт `fb2.zip` архива.
  static Book fb2ZipToBook(Uint8List bytes, {BookDecodingOptions? options}) =>
      Fb2ZipDecoder().decode(bytes, options: options);
}
