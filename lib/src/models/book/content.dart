import 'resources.dart';

/// Основное содержимое книги: блоки текста и сноски.
class BookContent {
  /// Блоки основного текста книги в Хронологическом порядке.
  final List<BookBlock> blocks;

  /// Сноски книги.
  final List<BookFootnote> footnotes;

  const BookContent({this.blocks = const [], this.footnotes = const []});
}

/// Сноска к книге.
class BookFootnote {
  /// Идентификатор сноски, используемый в [BookFootnoteRef.id].
  final String id;

  /// Содержимое сноски.
  final List<BookBlock> blocks;

  const BookFootnote({required this.id, this.blocks = const []});
}

/// Базовый sealed-класс всех узлов модели контента.
///
/// Имеет опциональный словарь [attributes] для хранения
/// произвольных метаданных из исходного формата.
sealed class BookNode {
  /// Произвольные атрибуты, сохраняемые из исходной разметки.
  ///
  /// Примеры ключей HTML-парсера: `'source-id'`, `'source-src'`.
  final Map<String, String> attributes;

  const BookNode({this.attributes = const {}});
}

/// Блочный элемент контента.
///
/// Представляет параграф, заголовок, секцию и другие
/// самостоятельные блоки текста.
sealed class BookBlock extends BookNode {
  const BookBlock({super.attributes});
}

/// Строчный (инлайновый) элемент контента.
///
/// Размещается внутри блочных элементов: текст, ссылки, изображения и т.д.
sealed class BookInline extends BookNode {
  const BookInline({super.attributes});
}

/// Раздел / глава книги, может содержать вложенные подразделы.
class BookSection extends BookBlock {
  /// Идентификатор раздела (например, значение HTML-атрибута `id`).
  final String? id;

  /// Заголовок раздела в виде строчных элементов.
  final List<BookInline> title;

  /// Блоки основного текста раздела.
  final List<BookBlock> blocks;

  /// Вложенные подразделы.
  final List<BookSection> children;

  const BookSection({
    this.id,
    this.title = const [],
    this.blocks = const [],
    this.children = const [],
    super.attributes,
  });
}

/// Заголовок (h1–h6).
class BookHeading extends BookBlock {
  /// Уровень заголовка, от 1 до 6.
  final int level;

  /// Текст заголовка в виде строчных элементов.
  final List<BookInline> text;

  const BookHeading({
    required this.level,
    this.text = const [],
    super.attributes,
  }) : assert(level >= 1);
}

/// Текстовый абзац.
class BookParagraph extends BookBlock {
  /// Строчные элементы абзаца.
  final List<BookInline> inlines;

  const BookParagraph({this.inlines = const [], super.attributes});
}

/// Цитата / blockquote.
class BookQuote extends BookBlock {
  /// Цитируемые блоки.
  final List<BookBlock> blocks;

  /// Подпись (источник цитаты).
  final List<BookInline> citation;

  const BookQuote({
    this.blocks = const [],
    this.citation = const [],
    super.attributes,
  });
}

/// Список (маркированный или нумерованный).
class BookList extends BookBlock {
  /// `true` — нумерованный список, `false` — маркированный.
  final bool ordered;

  /// Элементы списка.
  final List<BookListItem> items;

  const BookList({
    required this.ordered,
    this.items = const [],
    super.attributes,
  });
}

/// Элемент списка.
class BookListItem {
  /// Блоки текста внутри элемента списка.
  final List<BookBlock> blocks;

  const BookListItem({this.blocks = const []});
}

/// Таблица.
class BookTable extends BookBlock {
  /// Строки таблицы.
  final List<BookTableRow> rows;

  const BookTable({this.rows = const [], super.attributes});
}

/// Строка таблицы.
class BookTableRow {
  /// Ячейки строки.
  final List<BookTableCell> cells;

  const BookTableRow({this.cells = const []});
}

/// Ячейка таблицы.
class BookTableCell {
  /// Содержимое ячейки.
  final List<BookBlock> blocks;

  /// Количество объединяемых столбцов (`colspan`).
  final int? colSpan;

  /// Количество объединяемых строк (`rowspan`).
  final int? rowSpan;

  const BookTableCell({this.blocks = const [], this.colSpan, this.rowSpan});
}

/// Стихотворное произведение, состоящее из строф.
class BookPoem extends BookBlock {
  /// Строфы стихотворения.
  final List<BookStanza> stanzas;

  const BookPoem({this.stanzas = const [], super.attributes});
}

/// Строфа стихотворения.
class BookStanza {
  /// Строки строфы.
  final List<BookPoemLine> lines;

  const BookStanza({this.lines = const []});
}

/// Одна строка стихотворения.
class BookPoemLine {
  /// Строчные элементы строки.
  final List<BookInline> inlines;

  const BookPoemLine({this.inlines = const []});
}

/// Блочное изображение.
class BookImageBlock extends BookBlock {
  /// Ссылка на ресурс изображения.
  final BookResourceRef ref;

  /// Альтернативный текст.
  final String? alt;

  /// Всплывающая подсказка.
  final String? title;

  const BookImageBlock({
    required this.ref,
    this.alt,
    this.title,
    super.attributes,
  });
}

class BookHorizontalRule extends BookBlock {
  const BookHorizontalRule({super.attributes});
}

class BookEmptyLine extends BookBlock {
  const BookEmptyLine({super.attributes});
}

class BookCodeBlock extends BookBlock {
  final String code;
  final String? language;

  const BookCodeBlock({required this.code, this.language, super.attributes});
}

class BookRawHtmlBlock extends BookBlock {
  final String html;

  const BookRawHtmlBlock(this.html, {super.attributes});
}

class BookRawXmlBlock extends BookBlock {
  final String xml;

  const BookRawXmlBlock(this.xml, {super.attributes});
}

class BookText extends BookInline {
  final String text;

  const BookText(this.text, {super.attributes});
}

class BookLineBreak extends BookInline {
  const BookLineBreak({super.attributes});
}

class BookEmphasis extends BookInline {
  final List<BookInline> children;

  const BookEmphasis({this.children = const [], super.attributes});
}

class BookStrong extends BookInline {
  final List<BookInline> children;

  const BookStrong({this.children = const [], super.attributes});
}

class BookStrike extends BookInline {
  final List<BookInline> children;

  const BookStrike({this.children = const [], super.attributes});
}

class BookCodeSpan extends BookInline {
  final String code;

  const BookCodeSpan(this.code, {super.attributes});
}

class BookLink extends BookInline {
  final Uri href;
  final List<BookInline> children;

  const BookLink({
    required this.href,
    this.children = const [],
    super.attributes,
  });
}

class BookAnchor extends BookInline {
  final String id;

  const BookAnchor(this.id, {super.attributes});
}

class BookImageInline extends BookInline {
  final BookResourceRef ref;
  final String? alt;

  const BookImageInline({required this.ref, this.alt, super.attributes});
}

class BookSuperscript extends BookInline {
  final List<BookInline> children;

  const BookSuperscript({this.children = const [], super.attributes});
}

class BookSubscript extends BookInline {
  final List<BookInline> children;

  const BookSubscript({this.children = const [], super.attributes});
}

class BookFootnoteRef extends BookInline {
  final String id;
  final List<BookInline> label;

  const BookFootnoteRef({
    required this.id,
    this.label = const [],
    super.attributes,
  });
}

class BookRawHtmlInline extends BookInline {
  final String html;

  const BookRawHtmlInline(this.html, {super.attributes});
}

class BookRawXmlInline extends BookInline {
  final String xml;

  const BookRawXmlInline(this.xml, {super.attributes});
}
