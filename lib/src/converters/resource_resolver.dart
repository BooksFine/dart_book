import 'dart:async';
import '../models/book.dart';
import 'resource_requests_collector.dart';

class BookResourceDownloadState {
  final String id;
  int receivedBytes;
  int? totalBytes;
  bool isCompleted;
  bool isFailed;

  BookResourceDownloadState({
    required this.id,
    this.receivedBytes = 0,
    this.totalBytes,
    this.isCompleted = false,
    this.isFailed = false,
  });
}

/// Расширение для модели [Book], добавляющее метод асинхронного насыщения ресурсами.
extension BookResourceResolverX on Book {
  /// Дозаполняет [Book] ресурсами, загруженными через [resourceResolver].
  Future<Book> resolveResources(
    BookResourceResolver resourceResolver, {
    Uri? baseUri,
    void Function(
      int completedCount,
      int totalCount,
      List<BookResourceDownloadState> states,
    )? onProgress,
    int? maxConcurrent,
  }) async {
    final resourcesById = <String, BookResource>{
      for (final resource in resources) resource.id: resource,
    };

    final requests = collectResourceRequestsFromBook(this);
    final pendingRequests =
        requests.where((r) => !resourcesById.containsKey(r.id)).toList();

    if (pendingRequests.isEmpty) {
      return this;
    }

    final states = <String, BookResourceDownloadState>{
      for (final req in pendingRequests)
        req.id: BookResourceDownloadState(id: req.id),
    };

    var completedCount = 0;
    final totalCount = pendingRequests.length;

    void emitProgress() {
      onProgress?.call(
        completedCount,
        totalCount,
        states.values.toList(growable: false),
      );
    }

    emitProgress();

    var nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        if (nextIndex >= pendingRequests.length) break;
        final req = pendingRequests[nextIndex++];

        final state = states[req.id]!;
        try {
          final resolved = await resourceResolver(
            BookResourceRequest(
              id: req.id,
              source: req.source ?? req.id,
              baseUri: baseUri,
              isInline: req.isInline,
            ),
            onByteProgress: (received, total) {
              state.receivedBytes = received;
              state.totalBytes = total;
              emitProgress();
            },
          );

          if (resolved != null) {
            resourcesById[resolved.id] = resolved;
            state.isCompleted = true;
          } else {
            state.isFailed = true;
          }
        } catch (_) {
          state.isFailed = true;
        } finally {
          completedCount++;
          emitProgress();
        }
      }
    }

    final concurrency = maxConcurrent ?? 4;
    final poolSize = concurrency < 1 ? 1 : concurrency;
    final workers = List.generate(
      poolSize < pendingRequests.length ? poolSize : pendingRequests.length,
      (_) => worker(),
    );

    await Future.wait(workers);

    return Book(
      metadata: metadata,
      content: content,
      resources: resourcesById.values.toList(growable: false),
    );
  }
}

