// ignore_for_file: annotate_overrides

import 'dart:async';
import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part '.gen/resources.freezed.dart';

/// Бинарный ресурс, встроенный в книгу (изображение, шрифт и т.д.).
@freezed
class BookResource with _$BookResource {
  /// Уникальный идентификатор ресурса внутри книги.
  final String id;

  /// MIME-тип ресурса (например, `'image/jpeg'`, `'image/png'`).
  final String mediaType;

  /// Бинарные данные ресурса.
  final Uint8List bytes;

  /// Исходное имя файла (опционально).
  final String? fileName;

  /// Исходный URI ресурса до встраивания в книгу (опционально).
  final Uri? originalUri;

  const BookResource({
    required this.id,
    required this.mediaType,
    required this.bytes,
    this.fileName,
    this.originalUri,
  });
}

/// Ссылка на ресурс [BookResource] по идентификатору.
@freezed
class BookResourceRef with _$BookResourceRef {
  /// Идентификатор ресурса, совпадающий с [BookResource.id].
  final String id;

  const BookResourceRef(this.id);
}

/// Функция-резолвер для загрузки внешних ресурсов.
///
/// Вызывается при необходимости получить ресурс (изображение), отсутствующий
/// в `book.resources`. Должна вернуть [BookResource] или `null`, если ресурс
/// недоступен.
///
/// Используется в [DartBook.load] и [resolveBookResources].
typedef BookResourceResolver =
    FutureOr<BookResource?> Function(BookResourceRequest request);

/// Запрос на получение ресурса от резолвера.
@freezed
class BookResourceRequest with _$BookResourceRequest {
  /// Идентификатор или путь запрашиваемого ресурса.
  final String id;

  /// Исходный `src`-атрибут, из которого был получен [id] (если сохранён).
  final String? source;

  /// Базовый URI книги, относительно которого может быть разрешён [id].
  final Uri? baseUri;

  /// `true` — ресурс используется строчно (внутри текста);
  /// `false` — ресурс является блочным элементом.
  final bool isInline;

  const BookResourceRequest({
    required this.id,
    this.source,
    this.baseUri,
    this.isInline = false,
  });
}
