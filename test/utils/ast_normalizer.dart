import 'package:dart_book/dart_book.dart';

/// Утилита для нормализации AST-деревьев перед сравнением.
///
/// Устраняет косметические различия, возникающие из-за форматирования:
/// - Сливает идущие подряд текстовые узлы [BookText].
/// - Удаляет пустые текстовые узлы [BookText] (`""`).
/// - Рекурсивно нормализует все дочерние узлы во всех блоках и инлайнах.
///
/// Внимание: Все типы [BookBlock] и [BookInline] матчатся исчерпывающе без `_ =>`.
class AstNormalizer {
  /// Нормализует всю книгу [Book].
  static Book normalizeBook(Book book) {
    return book.copyWith(
      metadata: normalizeMetadata(book.metadata),
      content: normalizeContent(book.content),
    );
  }

  /// Нормализует метаданные книги [BookMetadata].
  static BookMetadata normalizeMetadata(BookMetadata metadata) {
    return metadata.copyWith(
      title: metadata.title.trim(),
      annotation: metadata.annotation != null
          ? normalizeContent(metadata.annotation!)
          : null,
    );
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

  /// Исчерпывающий нормализатор блоков [BookBlock] без wildcard `_ =>`.
  static BookBlock? normalizeBlock(BookBlock block) {
    return switch (block) {
      BookParagraph p => BookParagraph(
          inlines: normalizeInlines(p.inlines),
          attributes: p.attributes,
        ),
      BookHeading h => BookHeading(
          level: h.level,
          text: normalizeInlines(h.text),
          attributes: h.attributes,
        ),
      BookSection s => BookSection(
          id: s.id,
          title: normalizeInlines(s.title),
          blocks: normalizeBlocks(s.blocks),
          children: s.children
              .map(normalizeBlock)
              .whereType<BookSection>()
              .toList(),
          attributes: s.attributes,
        ),
      BookQuote q => BookQuote(
          blocks: normalizeBlocks(q.blocks),
          citation: normalizeInlines(q.citation),
          attributes: q.attributes,
        ),
      BookList l => BookList(
          ordered: l.ordered,
          items: l.items
              .map((item) => BookListItem(blocks: normalizeBlocks(item.blocks)))
              .toList(),
          attributes: l.attributes,
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
          attributes: t.attributes,
        ),
      BookPoem poem => BookPoem(
          stanzas: poem.stanzas
              .map(
                (s) => BookStanza(
                  lines: s.lines
                      .map(
                        (l) => BookPoemLine(
                          inlines: normalizeInlines(l.inlines),
                        ),
                      )
                      .toList(),
                ),
              )
              .toList(),
          attributes: poem.attributes,
        ),
      BookCodeBlock c => BookCodeBlock(
          code: c.code,
          language: c.language,
          attributes: c.attributes,
        ),
      BookImageBlock img => BookImageBlock(
          id: img.id,
          ref: img.ref,
          alt: img.alt,
          title: img.title,
          attributes: img.attributes,
        ),
      BookAudioBlock a => BookAudioBlock(
          ref: a.ref,
          controls: a.controls,
          attributes: a.attributes,
        ),
      BookVideoBlock v => BookVideoBlock(
          ref: v.ref,
          posterRef: v.posterRef,
          controls: v.controls,
          attributes: v.attributes,
        ),
      BookMathBlock m => BookMathBlock(
          mathml: m.mathml.trim(),
          attributes: m.attributes,
        ),
      BookSvgBlock svg => BookSvgBlock(
          svg: svg.svg.trim(),
          attributes: svg.attributes,
        ),
      BookHorizontalRule hr => BookHorizontalRule(
          attributes: hr.attributes,
        ),
      BookEmptyLine el => BookEmptyLine(
          attributes: el.attributes,
        ),
      BookRawHtmlBlock rawHtml => BookRawHtmlBlock(
          rawHtml.html,
          attributes: rawHtml.attributes,
        ),
      BookRawXmlBlock rawXml => BookRawXmlBlock(
          rawXml.xml,
          attributes: rawXml.attributes,
        ),
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

  /// Исчерпывающий нормализатор инлайнов [BookInline] без wildcard `_ =>`.
  static BookInline? normalizeInline(BookInline inline) {
    return switch (inline) {
      BookText t => t.text.isEmpty ? null : BookText(t.text, attributes: t.attributes),
      BookEmphasis e => BookEmphasis(
          children: normalizeInlines(e.children),
          attributes: e.attributes,
        ),
      BookStrong s => BookStrong(
          children: normalizeInlines(s.children),
          attributes: s.attributes,
        ),
      BookStrike st => BookStrike(
          children: normalizeInlines(st.children),
          attributes: st.attributes,
        ),
      BookCodeSpan c => BookCodeSpan(
          c.code,
          attributes: c.attributes,
        ),
      BookNamedStyle ns => BookNamedStyle(
          name: ns.name,
          inlines: normalizeInlines(ns.inlines),
          attributes: ns.attributes,
        ),
      BookLink l => BookLink(
          href: l.href,
          children: normalizeInlines(l.children),
          attributes: l.attributes,
        ),
      BookAnchor a => BookAnchor(
          a.id,
          attributes: a.attributes,
        ),

      BookImageInline img => BookImageInline(
          id: img.id,
          ref: img.ref,
          alt: img.alt,
          title: img.title,
          attributes: img.attributes,
        ),
      BookFootnoteRef fn => BookFootnoteRef(
          id: fn.id,
          label: normalizeInlines(fn.label),
          attributes: fn.attributes,
        ),
      BookSuperscript sup => BookSuperscript(
          children: normalizeInlines(sup.children),
          attributes: sup.attributes,
        ),
      BookSubscript sub => BookSubscript(
          children: normalizeInlines(sub.children),
          attributes: sub.attributes,
        ),
      BookLineBreak lb => BookLineBreak(
          attributes: lb.attributes,
        ),
      BookRawHtmlInline rawHtml => BookRawHtmlInline(
          rawHtml.html,
          attributes: rawHtml.attributes,
        ),
      BookRawXmlInline rawXml => BookRawXmlInline(
          rawXml.xml,
          attributes: rawXml.attributes,
        ),
    };
  }
}
