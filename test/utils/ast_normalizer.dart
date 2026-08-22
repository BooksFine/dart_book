import 'package:dart_book/dart_book.dart';

/// Утилита для нормализации AST-деревьев перед сравнением.
///
/// Устраняет косметические различия, возникающие из-за форматирования:
/// - Сливает идущие подряд текстовые узлы [BookText].
/// - Удаляет пустые текстовые узлы [BookText] (`""`).
/// - Рекурсивно нормализует дочерние узлы в блоках и инлайнах.
class AstNormalizer {
  /// Нормализует всю книгу [Book].
  static Book normalizeBook(Book book) {
    return book.copyWith(content: normalizeContent(book.content));
  }

  /// Нормализует контент книги [BookContent].
  static BookContent normalizeContent(BookContent content) {
    return BookContent(
      blocks: normalizeBlocks(content.blocks),
      footnotes: content.footnotes.map(normalizeFootnote).toList(),
    );
  }

  /// Нормализует отдельную сноску [BookFootnote].
  static BookFootnote normalizeFootnote(BookFootnote footnote) {
    return BookFootnote(
      id: footnote.id,
      blocks: normalizeBlocks(footnote.blocks),
    );
  }

  /// Рекурсивно нормализует список блоков [BookBlock].
  static List<BookBlock> normalizeBlocks(List<BookBlock> blocks) {
    final result = <BookBlock>[];
    for (final block in blocks) {
      final normalized = normalizeBlock(block);
      if (normalized != null) {
        result.add(normalized);
      }
    }
    return result;
  }

  /// Нормализует отдельный блок [BookBlock].
  static BookBlock? normalizeBlock(BookBlock block) {
    return switch (block) {
      BookParagraph p => BookParagraph(inlines: normalizeInlines(p.inlines)),
      BookHeading h => BookHeading(
        level: h.level,
        text: normalizeInlines(h.text),
      ),
      BookSection s => BookSection(
        id: s.id,
        title: normalizeInlines(s.title),
        blocks: normalizeBlocks(s.blocks),
        children: s.children
            .map(normalizeBlock)
            .whereType<BookSection>()
            .toList(),
      ),
      BookQuote q => BookQuote(
        blocks: normalizeBlocks(q.blocks),
        citation: normalizeInlines(q.citation),
      ),
      BookList l => BookList(
        ordered: l.ordered,
        items: l.items
            .map((item) => BookListItem(blocks: normalizeBlocks(item.blocks)))
            .toList(),
      ),
      BookTable t => BookTable(
        rows: t.rows
            .map(
              (row) => BookTableRow(
                cells: row.cells
                    .map(
                      (cell) => BookTableCell(
                        blocks: normalizeBlocks(cell.blocks),
                        colSpan: cell.colSpan,
                        rowSpan: cell.rowSpan,
                        align: cell.align,
                        vAlign: cell.vAlign,
                      ),
                    )
                    .toList(),
              ),
            )
            .toList(),
      ),
      BookPoem poem => BookPoem(
        stanzas: poem.stanzas
            .map(
              (s) => BookStanza(
                lines: s.lines
                    .map(
                      (l) => BookPoemLine(inlines: normalizeInlines(l.inlines)),
                    )
                    .toList(),
              ),
            )
            .toList(),
      ),
      _ => block,
    };
  }

  /// Рекурсивно нормализует список строчных элементов [BookInline]:
  /// - Склеивает смежные текстовые узлы [BookText].
  /// - Удаляет пустые узлы [BookText].
  static List<BookInline> normalizeInlines(List<BookInline> inlines) {
    final merged = <BookInline>[];
    for (final inline in inlines) {
      final norm = normalizeInline(inline);
      if (norm == null) continue;

      if (norm is BookText && merged.isNotEmpty && merged.last is BookText) {
        final prev = merged.removeLast() as BookText;
        final combined = '${prev.text}${norm.text}';
        if (combined.isNotEmpty) {
          merged.add(BookText(combined));
        }
      } else {
        merged.add(norm);
      }
    }
    return merged;
  }

  /// Нормализует отдельный строчный узел [BookInline].
  static BookInline? normalizeInline(BookInline inline) {
    return switch (inline) {
      BookText t => t.text.isEmpty ? null : BookText(t.text),
      BookEmphasis e => BookEmphasis(children: normalizeInlines(e.children)),
      BookStrong s => BookStrong(children: normalizeInlines(s.children)),
      BookStrike st => BookStrike(children: normalizeInlines(st.children)),
      BookCodeSpan c => c,
      BookNamedStyle ns => BookNamedStyle(
        name: ns.name,
        inlines: normalizeInlines(ns.inlines),
      ),
      BookLink l => BookLink(
        href: l.href,
        children: normalizeInlines(l.children),
      ),
      BookSuperscript sup => BookSuperscript(
        children: normalizeInlines(sup.children),
      ),
      BookSubscript sub => BookSubscript(
        children: normalizeInlines(sub.children),
      ),
      BookFootnoteRef fn => BookFootnoteRef(
        id: fn.id,
        label: normalizeInlines(fn.label),
      ),
      _ => inline,
    };
  }
}
