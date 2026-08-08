// ignore_for_file: annotate_overrides

import 'package:freezed_annotation/freezed_annotation.dart';

import 'content.dart';
import 'metadata.dart';
import 'resources.dart';

part '.gen/book.freezed.dart';

/// Корневой объект, представляющий электронную книгу.
///
/// Содержит метаданные ([metadata]), контент ([content])
/// и встроенные ресурсы ([resources]) в формато-независимом виде.
@freezed
class Book with _$Book {
  /// Уникальный идентификатор книги.
  final String id;

  /// Метаданные: название, авторы, язык, жанры и пр.
  final BookMetadata metadata;

  /// Основное содержимое: блоки текста, сноски.
  final BookContent content;

  /// Бинарные ресурсы книги (изображения, шрифты и т.д.).
  final List<BookResource> resources;

  const Book({
    required this.id,
    required this.metadata,
    required this.content,
    required this.resources,
  });

  /// Возвращает ресурс по его [id] или `null`, если ресурс не найден.
  BookResource? resourceById(String id) {
    for (final resource in resources) {
      if (resource.id == id) return resource;
    }
    return null;
  }
}
