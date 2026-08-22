// ignore_for_file: annotate_overrides

import 'package:freezed_annotation/freezed_annotation.dart';
import 'content.dart';
import 'person.dart';
import 'resources.dart';

part '.gen/metadata.freezed.dart';

/// Режим отображения/верстки книги.
enum BookLayout {
  /// Адаптивная текстовая верстка (по умолчанию).
  reflowable,

  /// Фиксированная верстка (комиксы, манга, фотокниги).
  fixedLayout,

  /// Непрерывный вертикальный скролл (вебтуны).
  roll,
}

/// Метаданные книги: название, язык, авторы, жанры, обложка, издательство и т.д.
@freezed
class BookMetadata with _$BookMetadata {
  /// Уникальный идентификатор книги.
  final String id;

  /// Название книги.
  final String title;

  /// Код языка книги (ISO 639-1, например `'ru'`, `'en'`).
  final String language;

  /// Флаг завершенности книги.
  final bool isFinished;

  /// Длина текста (в символах или словах).
  final int? textLength;

  /// Участники создания книги: авторы, переводчики, редакторы и пр.
  final List<BookContributor> contributors;

  /// Жанры книги.
  final List<BookGenre> genres;

  /// Ключевые слова / теги.
  final List<String> keywords;

  /// Аннотация к книге в виде блоков контента.
  final BookContent? annotation;

  /// Серии, в которые входит книга.
  final List<BookSeries> series;

  /// Обложка книги.
  final BookCover? cover;

  /// Оригинальный URI источника (например, адрес веб-страницы или epub-файла).
  final Uri? source;

  /// Сведения об издании (издательство, город, год, ISBN).
  final BookPublishInfo? publishInfo;

  /// Язык оригинального произведения (для переводных книг).
  final String? srcLang;

  /// Сведения об оригинальном произведении.
  final BookSourceTitleInfo? srcTitleInfo;

  /// Режим верстки/отображения (reflowable, fixedLayout, roll).
  final BookLayout layout;

  /// Дата последнего обновления документа.
  final DateTime? updatedAt;

  /// Дата публикации книги.
  final DateTime? publishedAt;

  const BookMetadata({
    required this.id,
    required this.title,
    required this.language,
    this.isFinished = true,
    this.textLength,
    this.contributors = const [],
    this.genres = const [],
    this.keywords = const [],
    this.annotation,
    this.series = const [],
    this.cover,
    this.source,
    this.publishInfo,
    this.srcLang,
    this.srcTitleInfo,
    this.layout = BookLayout.reflowable,
    this.updatedAt,
    this.publishedAt,
  });

  /// Возвращает первую (основную) серию книги для удобства.
  BookSeries? get primarySeries => series.firstOrNull;

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

/// Сведения об издании книги (издательство, город, год, ISBN).
@freezed
class BookPublishInfo with _$BookPublishInfo {
  /// Название издательства.
  final String? publisher;

  /// Город издания.
  final String? city;

  /// Год издания.
  final int? year;

  /// Международный стандартный книжный номер (ISBN).
  final String? isbn;

  const BookPublishInfo({this.publisher, this.city, this.year, this.isbn});
}

/// Сведения об оригинале произведения (для переводных книг).
@freezed
class BookSourceTitleInfo with _$BookSourceTitleInfo {
  /// Оригинальное название.
  final String? title;

  /// Язык оригинала.
  final String? language;

  /// Авторы оригинального произведения.
  final List<BookContributor> authors;

  const BookSourceTitleInfo({
    this.title,
    this.language,
    this.authors = const [],
  });
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
