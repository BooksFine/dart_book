import 'dart:async';
import 'dart:typed_data';

import 'book.dart';

/// Совмещённый интерфейс конвертера книги: объединяет [BookEncoder] и [BookDecoder].
///
/// Реализуйте этот интерфейс, если ваш класс поддерживает
/// как чтение, так и запись одного и того же формата.
abstract interface class BookConverter implements BookEncoder, BookDecoder {}

/// Интерфейс кодировщика книги.
///
/// Отвечает за сериализацию модели [Book] в байты конкретного формата.
abstract interface class BookEncoder {
  /// Возвращает `true`, если данный энкодер поддерживает расширение [extension].
  ///
  /// Расширение передаётся **без** ведущей точки (например, `'epub'`, `'fb2'`).
  bool canEncode(String extension);

  /// Кодирует [book] в байты формата.
  FutureOr<Uint8List> encode(Book book);
}

/// Интерфейс декодировщика книги.
///
/// Отвечает за десериализацию байт конкретного формата в модель [Book].
abstract interface class BookDecoder {
  /// Возвращает `true`, если данный декодер способен обработать переданные [bytes].
  ///
  /// Решение может основываться на сигнатуре байт (magic bytes)
  /// и/или на расширении файла [extension] (без ведущей точки).
  bool canDecode(Uint8List bytes, {String? extension});

  /// Декодирует [bytes] в модель [Book].
  ///
  /// [options] — необязательные параметры: `id` книги и код языка `lang`.
  FutureOr<Book> decode(Uint8List bytes, {BookDecodingOptions? options});
}

/// Параметры декодирования книги.
///
/// - [id] — задать идентификатор книги явно (иначе генерируется автоматически).
/// - [lang] — код языка (ISO 639-1, например `'ru'`, `'en'`).
typedef BookDecodingOptions = ({String? id, String? lang});
