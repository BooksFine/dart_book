import 'dart:async';
import 'package:dart_book/dart_book.dart';

/// Удобный билдер для постепенного (поглавного) создания книги
/// из HTML-фрагментов с веб-ресурсов ("качалок"/скрейперов).
class BookBuilder {
  final String title;
  final String language;
  final List<BookContributor> contributors;
  final List<BookGenre> genres;
  final List<String> keywords;
  final BookSeries? series;
  final Uri? source;
  final BookResourceResolver? resourceResolver;
  final BookResourceNamingPolicy namingPolicy;

  BookContent? _annotation;
  BookCover? _cover;
  final List<BookSection> _sections = [];
  final Map<String, BookResource> _resources = {};
  int _resourceCounter = 0;

  BookBuilder({
    required this.title,
    this.language = 'ru',
    this.contributors = const [],
    this.genres = const [],
    this.keywords = const [],
    this.series,
    this.source,
    this.resourceResolver,
    this.namingPolicy = BookResourceNamingPolicy.preserve,
  });

  /// Устанавливает обложку книги по ссылке [ref] или байтам.
  void setCover(BookResourceRef ref, {String? alt}) {
    _cover = BookCover(ref: ref, alt: alt);
  }

  /// Устанавливает аннотацию из HTML-фрагмента.
  void setAnnotationHtml(String html) {
    final parser = HtmlParser();
    final blocks = parser.parseFromString(html);
    _annotation = BookContent(blocks: blocks);
  }

  /// Добавляет главу из HTML-фрагмента или веб-страницы.
  ///
  /// [html] — сырой HTML разметки главы.
  /// [title] — название главы (например, `'Глава 1. Начало'`).
  /// [id] — идентификатор секции главы (опционально).
  /// [strictMode] — режим строгой проверки на нераспознанные HTML5 элементы.
  /// [logger] — колбэк для логгирования фолбеков и предупреждений.
  Future<BookSection> addChapterHtml(
    String html, {
    String? title,
    String? id,
    bool strictMode = false,
    void Function(String warning)? logger,
  }) async {
    final pendingResources = <String, String>{}; // resId -> src

    final parser = HtmlParser(
      strictMode: strictMode,
      logger: logger,
      registrar: (src, {required isInline}) {
        final resId = namingPolicy.generateName(
          src,
          isInline: isInline,
          index: ++_resourceCounter,
        );
        pendingResources[resId] = src;
        return resId;
      },
    );

    final blocks = parser.parseFromString(html);

    final section = BookSection(
      id: id ?? 'section-${_sections.length + 1}',
      title: title != null && title.isNotEmpty ? [BookText(title)] : const [],
      blocks: blocks,
    );

    _sections.add(section);

    // Дозагружаем медиа-ресурсы через кастомный resourceResolver при его наличии (параллельно)
    if (resourceResolver != null) {
      await Future.wait(
        pendingResources.entries.map((entry) async {
          final resId = entry.key;
          final src = entry.value;

          if (_resources.containsKey(resId)) return;

          final resolved = await resourceResolver!(
            BookResourceRequest(
              id: resId,
              source: src,
              baseUri: source,
              isInline: false,
            ),
          );
          if (resolved != null) {
            _resources[resId] = resolved;
          }
        }),
      );
    }

    return section;
  }

  /// Добавляет готовый бинарный ресурс (картинку, шрифт, аудио, стиль).
  void addResource(BookResource resource) {
    _resources[resource.id] = resource;
  }

  /// Собирает итоговую готовую модель [Book].
  Future<Book> build() async {
    final bookId = title.hashCode.abs().toString();
    var book = Book(
      metadata: BookMetadata(
        id: bookId,
        title: title,
        language: language,
        contributors: contributors,
        genres: genres,
        keywords: keywords,
        annotation: _annotation,
        series: series,
        cover: _cover,
        source: source,
      ),
      content: BookContent(blocks: _sections),
      resources: _resources.values.toList(),
    );

    // Финальная проверка и загрузка отсутствующих ресурсов при наличии resolver
    if (resourceResolver != null) {
      book = await book.resolveResources(resourceResolver!, baseUri: source);
    }

    return book;
  }
}
