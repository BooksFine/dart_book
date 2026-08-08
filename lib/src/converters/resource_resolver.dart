import '../models/book.dart';
import 'resource_requests_collector.dart';

/// Дозаполняет [book] ресурсами, загруженными через [resourceResolver].
///
/// Алгоритм работы:
/// 1. Собирает все запросы на ресурсы внутри книги.
/// 2. Пропускает ресурсы, которые уже есть в `book.resources`.
/// 3. Для остальных запрашивает [resourceResolver].
/// 4. Возвращает новый [Book] со 合вокупным набором ресурсов.
///
/// [baseUri] — основной URI для разрешения относительных ссылок.
Future<Book> resolveBookResources(
  Book book,
  BookResourceResolver resourceResolver, {
  Uri? baseUri,
}) async {
  final resourcesById = <String, BookResource>{
    for (final resource in book.resources) resource.id: resource,
  };

  final requests = collectResourceRequestsFromBook(book);

  for (final request in requests) {
    if (resourcesById.containsKey(request.id)) continue;

    final resolved = await resourceResolver(
      BookResourceRequest(
        id: request.id,
        source: request.source,
        baseUri: baseUri,
        isInline: request.isInline,
      ),
    );
    if (resolved != null) {
      resourcesById[resolved.id] = resolved;
    }
  }

  return Book(
    id: book.id,
    metadata: book.metadata,
    content: book.content,
    resources: resourcesById.values.toList(growable: false),
  );
}
