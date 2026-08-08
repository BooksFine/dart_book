import 'package:dart_book/dart_book.dart';

/// Интерфейс парсера, преобразующего разметку в дерево [BookBlock].
///
/// Параметр [T] — тип входных данных:
/// - [HtmlParser]: `Iterable<dom.Node>`
/// - [Fb2Parser]: `Iterable<XmlNode>`
abstract interface class Parser<T> {
  /// Разбирает строку [text] в список [BookBlock].
  /// Строка предварительно парсится во входной формат (HTML или XML).
  List<BookBlock> parseFromString(String text);

  /// Разбирает уже пропарсенные узлы ([data]) в список [BookBlock].
  List<BookBlock> parse(T data);

  /// Опциональный callback для нормализации ссылок на ресурсы
  /// в [BookResourceRef].
  final BookResourceRegistrar? registrar;
  Parser({this.registrar});
}

/// Callback-функция для регистрации ресурсов при парсинге.
///
/// Принимает исходный `src` (или `href`) атрибут изображения/ссылки
/// и возвращает нормализованный `id` для [BookResourceRef].
///
/// - [src] — исходный атрибут ресурса.
/// - [isInline] — `true`, если ресурс используется строчно.
typedef BookResourceRegistrar =
    String Function(String src, {required bool isInline});
