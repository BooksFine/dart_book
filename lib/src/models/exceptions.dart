/// Базовое исключение библиотеки `dart_book`.
abstract class BookException implements Exception {
  final String message;
  const BookException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// Ошибка формата файла (неверная сигнатура, испорченный ZIP/XML архив).
class BookFormatException extends BookException {
  const BookFormatException(super.message);
}

/// Ошибка синтаксического анализа разметки (HTML, FB2, OPF, NCX, SMIL).
class BookParseException extends BookException {
  final String? tag;
  final int? line;

  const BookParseException(super.message, {this.tag, this.line});

  @override
  String toString() {
    final details = [
      if (tag != null) 'tag: <$tag>',
      if (line != null) 'line: $line',
    ];
    return 'BookParseException: $message${details.isNotEmpty ? ' (${details.join(', ')})' : ''}';
  }
}

/// Ошибка валидации метаданных или структуры книги.
class BookMalformedMetadataException extends BookException {
  const BookMalformedMetadataException(super.message);
}
