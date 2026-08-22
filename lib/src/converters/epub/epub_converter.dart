import 'dart:async';
import 'dart:typed_data';

import '../../models/book.dart';
import '../../models/converter.dart';
import '../../models/encoding_options.dart';
import 'epub_decoder.dart';
import 'epub_encoder.dart';

/// Конвертер для формата EPUB (Electronic Publication).
///
/// Реализует [BookConverter], объединяя [EpubDecoder] и [EpubEncoder].
///
/// Определение формата:
/// - Расширение `epub`, **или**
/// - ZIP-сигнатура (`PK\x03\x04`) + запись `mimetype` = `application/epub+zip`.
///
/// Пример:
/// ```dart
/// final book = await EpubConverter.epubToBook(bytes);
/// final epub = await EpubConverter.bookToEpub(book);
/// ```
class EpubConverter implements BookConverter {
  final _decoder = EpubDecoder();
  final _encoder = EpubEncoder();

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

  /// Удобный статический метод: кодирует [book] в EPUB.
  static Future<Uint8List> bookToEpub(
    Book book, {
    BookEncodingOptions? options,
  }) async => EpubEncoder().encode(book, options: options);

  /// Удобный статический метод: декодирует EPUB из [bytes].
  static Future<Book> epubToBook(
    Uint8List bytes, {
    BookDecodingOptions? options,
  }) async => EpubDecoder().decode(bytes, options: options);
}
