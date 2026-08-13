import '../models/book.dart';

List<BookResourceRequest> collectResourceRequestsFromBook(Book book) {
  final output = <BookResourceRequest>[];
  if (book.metadata.cover != null) {
    output.add(
      BookResourceRequest(
        id: book.metadata.cover!.ref.id,
        source: book.metadata.cover!.ref.id,
        isInline: false,
      ),
    );
  }
  _crrFromBlocks(book.content.blocks, output);
  if (book.metadata.annotation != null) {
    _crrFromBlocks(book.metadata.annotation!.blocks, output);
  }
  return output;
}

void _crrFromBlocks(List<BookBlock> blocks, List<BookResourceRequest> output) {
  for (final block in blocks) {
    switch (block) {
      case BookSection section:
        _crrFromInlines(section.title, output);
        _crrFromBlocks(section.blocks, output);
        _crrFromBlocks(section.children, output);
      case BookParagraph paragraph:
        _crrFromInlines(paragraph.inlines, output);
      case BookHeading heading:
        _crrFromInlines(heading.text, output);
      case BookQuote quote:
        _crrFromBlocks(quote.blocks, output);
        _crrFromInlines(quote.citation, output);
      case BookList list:
        for (final item in list.items) {
          _crrFromBlocks(item.blocks, output);
        }
      case BookTable table:
        for (final row in table.rows) {
          for (final cell in row.cells) {
            _crrFromBlocks(cell.blocks, output);
          }
        }
      case BookPoem poem:
        for (final stanza in poem.stanzas) {
          for (final line in stanza.lines) {
            _crrFromInlines(line.inlines, output);
          }
        }
      case BookImageBlock image:
        output.add(
          BookResourceRequest(
            id: image.ref.id,
            source: image.attributes['source-src'],
            isInline: false,
          ),
        );
      default:
        break;
    }
  }
}

void _crrFromInlines(
  List<BookInline> inlines,
  List<BookResourceRequest> output,
) {
  for (final inline in inlines) {
    switch (inline) {
      case BookImageInline image:
        output.add(
          BookResourceRequest(
            id: image.ref.id,
            source: image.attributes['source-src'],
            isInline: true,
          ),
        );
      case BookLink link:
        _crrFromInlines(link.children, output);
      case BookEmphasis emphasis:
        _crrFromInlines(emphasis.children, output);
      case BookStrong strong:
        _crrFromInlines(strong.children, output);
      case BookStrike strike:
        _crrFromInlines(strike.children, output);
      case BookSuperscript superscript:
        _crrFromInlines(superscript.children, output);
      case BookSubscript subscript:
        _crrFromInlines(subscript.children, output);
      case BookFootnoteRef footnoteRef:
        _crrFromInlines(footnoteRef.label, output);
      default:
        break;
    }
  }
}
