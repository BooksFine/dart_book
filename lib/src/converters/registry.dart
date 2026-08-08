import 'dart:typed_data';

import 'package:dart_book/dart_book.dart';

/// Статический реестр зарегистрированных декодеров и энкодеров книг.
///
/// По умолчанию зарегистрированы [EpubConverter] и [Fb2Converter].
/// Добавить поддержку нового формата можно через [registerDecoder] / [registerEncoder].
class BookRegistry {
  static final List<BookDecoder> _decoders = [
    EpubDecoder(),
    Fb2ZipDecoder(),
    Fb2Decoder(),
  ];

  static final List<BookEncoder> _encoders = [
    EpubEncoder(),
    Fb2ZipEncoder(),
    Fb2Encoder(),
  ];

  /// Находит первый подходящий декодер для заданных [bytes].
  ///
  /// [extension] — расширение файла без точки для дополнительной подсказки.
  /// Возвращает `null`, если ни один декодер не подошёл.
  static BookDecoder? findDecoder(Uint8List bytes, {String? extension}) {
    for (final decoder in _decoders) {
      if (decoder.canDecode(bytes, extension: extension)) {
        return decoder;
      }
    }
    return null;
  }

  /// Находит первый подходящий энкодер для заданного [extension].
  ///
  /// Ведущая точка в [extension] удаляется автоматически.
  /// Возвращает `null`, если ни один энкодер не подошёл.
  static BookEncoder? findEncoder(String extension) {
    final ext = extension.startsWith('.') ? extension.substring(1) : extension;
    for (final encoder in _encoders) {
      if (encoder.canEncode(ext)) {
        return encoder;
      }
    }
    return null;
  }

  /// Регистрирует пользовательский декодер с приоритетом над встроенными.
  static void registerDecoder(BookDecoder decoder) {
    _decoders.insert(0, decoder);
  }

  /// Регистрирует пользовательский энкодер с приоритетом над встроенными.
  static void registerEncoder(BookEncoder encoder) {
    _encoders.insert(0, encoder);
  }
}
