// ignore_for_file: annotate_overrides

import 'package:freezed_annotation/freezed_annotation.dart';
import 'content.dart';
import 'person.dart';
import 'resources.dart';

part '.gen/metadata.freezed.dart';

/// Метаданные книги: название, язык, авторы, жанры, обложка и т.д.
@freezed
class BookMetadata with _$BookMetadata {
  /// Название книги.
  final String title;

  /// Код языка книги (ISO 639-1, например `'ru'`, `'en'`).
  final String language;

  /// Участники создания книги: авторы, переводчики, редакторы и пр.
  final List<BookContributor> contributors;

  /// Жанры книги.
  final List<BookGenre> genres;

  /// Ключевые слова / теги.
  final List<String> keywords;

  /// Аннотация к книге в виде блоков контента.
  final BookContent? annotation;

  /// Серия, в которую входит книга.
  final BookSeries? series;

  /// Обложка книги.
  final BookCover? cover;

  /// Оригинальный URI источника (например, адрес веб-страницы или epub-файла).
  final Uri? source;

  /// Дата последнего обновления документа.
  final DateTime? updatedAt;

  /// Дата публикации книги.
  final DateTime? publishedAt;

  const BookMetadata({
    required this.title,
    required this.language,
    this.contributors = const [],
    this.genres = const [],
    this.keywords = const [],
    this.annotation,
    this.series,
    this.cover,
    this.source,
    this.updatedAt,
    this.publishedAt,
  });

  /// Возвращает всех участников с заданной [role].
  ///
  /// Пример:
  /// ```dart
  /// final authors = metadata.contributorsByRole(BookContributorRole.author);
  /// ```
  Iterable<BookContributor> contributorsByRole(BookContributorRole role) sync* {
    for (final contributor in contributors) {
      if (contributor.role == role) {
        yield contributor;
      }
    }
  }
}

/// Жанр книги.
@freezed
class BookGenre with _$BookGenre {
  /// Код жанра (например, `'sf_fantasy'`, `'detective'`).
  final String code;

  /// Человекочитаемое название жанра (опционально).
  final String? name;

  const BookGenre({required this.code, this.name});
}

/// Описание серии, в которую входит книга.
@freezed
class BookSeries with _$BookSeries {
  /// Название серии.
  final String name;

  /// Порядковый номер книги в серии.
  final int? number;

  /// Ссылка на страницу серии.
  final Uri? url;

  const BookSeries({required this.name, this.number, this.url});
}

/// Обложка книги.
@freezed
class BookCover with _$BookCover {
  /// Ссылка на ресурс с изображением обложки.
  final BookResourceRef ref;

  /// Альтернативный текст изображения.
  final String? alt;

  const BookCover({required this.ref, this.alt});
}
