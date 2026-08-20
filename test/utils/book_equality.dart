import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';

/// Утилита глубокой проверки равенства деревьев BookBlock и BookInline.
void assertBookContentEquals(BookContent actual, BookContent expected) {
  assertBlockListEquals(actual.blocks, expected.blocks);
}

void assertBlockListEquals(List<BookBlock> actual, List<BookBlock> expected) {
  expect(
    actual.length,
    equals(expected.length),
    reason: 'Количество блоков должно совпадать (${actual.length} vs ${expected.length})',
  );

  for (var i = 0; i < actual.length; i++) {
    assertBlockEquals(actual[i], expected[i], path: 'blocks[$i]');
  }
}

void assertBlockEquals(BookBlock actual, BookBlock expected, {required String path}) {
  expect(actual.runtimeType, equals(expected.runtimeType), reason: '$path: типы блоков должны совпадать');

  // Гарантируем, что стандартный блок не сбросился в сырой HTML/XML
  if (expected is! BookRawHtmlBlock && expected is! BookRawXmlBlock) {
    expect(
      actual,
      isNot(isA<BookRawHtmlBlock>()),
      reason: '$path: блок ${expected.runtimeType} не должен превращаться в BookRawHtmlBlock',
    );
    expect(
      actual,
      isNot(isA<BookRawXmlBlock>()),
      reason: '$path: блок ${expected.runtimeType} не должен превращаться в BookRawXmlBlock',
    );
  }

  switch ((actual, expected)) {
    case (BookParagraph a, BookParagraph e):
      assertInlineListEquals(a.inlines, e.inlines, path: '$path.inlines');

    case (BookHeading a, BookHeading e):
      expect(a.level, equals(e.level), reason: '$path: уровень заголовка должен совпадать');
      assertInlineListEquals(a.text, e.text, path: '$path.text');

    case (BookSection a, BookSection e):
      expect(a.id, equals(e.id), reason: '$path: id секции должен совпадать');
      assertInlineListEquals(a.title, e.title, path: '$path.title');
      assertBlockListEquals(a.blocks, e.blocks);
      assertBlockListEquals(a.children, e.children);

    case (BookQuote a, BookQuote e):
      assertBlockListEquals(a.blocks, e.blocks);
      assertInlineListEquals(a.citation, e.citation, path: '$path.citation');

    case (BookList a, BookList e):
      expect(a.ordered, equals(e.ordered), reason: '$path: тип списка (ordered) должен совпадать');
      expect(a.items.length, equals(e.items.length), reason: '$path: число элементов списка должно совпадать');
      for (var i = 0; i < a.items.length; i++) {
        assertBlockListEquals(a.items[i].blocks, e.items[i].blocks);
      }

    case (BookTable a, BookTable e):
      expect(a.rows.length, equals(e.rows.length), reason: '$path: число строк таблицы должно совпадать');
      for (var r = 0; r < a.rows.length; r++) {
        expect(
          a.rows[r].cells.length,
          equals(e.rows[r].cells.length),
          reason: '$path: число ячеек в строке $r должно совпадать',
        );
        for (var c = 0; c < a.rows[r].cells.length; c++) {
          final ac = a.rows[r].cells[c];
          final ec = e.rows[r].cells[c];
          expect(ac.colSpan, equals(ec.colSpan), reason: '$path.rows[$r].cells[$c].colSpan');
          expect(ac.rowSpan, equals(ec.rowSpan), reason: '$path.rows[$r].cells[$c].rowSpan');
          expect(ac.align, equals(ec.align), reason: '$path.rows[$r].cells[$c].align');
          expect(ac.vAlign, equals(ec.vAlign), reason: '$path.rows[$r].cells[$c].vAlign');
          assertBlockListEquals(ac.blocks, ec.blocks);
        }
      }

    case (BookPoem a, BookPoem e):
      expect(a.stanzas.length, equals(e.stanzas.length), reason: '$path: число строф должно совпадать');
      for (var s = 0; s < a.stanzas.length; s++) {
        expect(
          a.stanzas[s].lines.length,
          equals(e.stanzas[s].lines.length),
          reason: '$path: число строк в строфе $s должно совпадать',
        );
        for (var l = 0; l < a.stanzas[s].lines.length; l++) {
          assertInlineListEquals(a.stanzas[s].lines[l].inlines, e.stanzas[s].lines[l].inlines, path: '$path.stanza[$s].line[$l]');
        }
      }

    case (BookCodeBlock a, BookCodeBlock e):
      expect(a.code, equals(e.code), reason: '$path: код должен совпадать');

    case (BookImageBlock a, BookImageBlock e):
      expect(a.ref.id.endsWith(e.ref.id), isTrue, reason: '$path: id ресурса изображения должен совпадать');
      expect(a.id, equals(e.id), reason: '$path: id изображения должен совпадать');
      expect(a.alt, equals(e.alt), reason: '$path: alt изображения должен совпадать');
      expect(a.title, equals(e.title), reason: '$path: title изображения должен совпадать');

    case (BookAudioBlock a, BookAudioBlock e):
      expect(a.ref.id, equals(e.ref.id), reason: '$path: id аудиоресурса должен совпадать');

    case (BookVideoBlock a, BookVideoBlock e):
      expect(a.ref.id, equals(e.ref.id), reason: '$path: id видеоресурса должен совпадать');

    case (BookMathBlock a, BookMathBlock e):
      expect(a.mathml, equals(e.mathml), reason: '$path: формулы MathML должны совпадать');

    case (BookSvgBlock a, BookSvgBlock e):
      expect(a.svg, equals(e.svg), reason: '$path: SVG графика должна совпадать');

    case (BookHorizontalRule(), BookHorizontalRule()):
    case (BookEmptyLine(), BookEmptyLine()):
      break;

    case (BookRawHtmlBlock a, BookRawHtmlBlock e):
      expect(a.html, equals(e.html));

    case (BookRawXmlBlock a, BookRawXmlBlock e):
      expect(a.xml, equals(e.xml));

    default:
      fail('$path: несовместимые типы блоков $actual vs $expected');
  }
}

void assertInlineListEquals(List<BookInline> actual, List<BookInline> expected, {required String path}) {
  expect(actual.length, equals(expected.length), reason: '$path: число инлайновых элементов должно совпадать');
  for (var i = 0; i < actual.length; i++) {
    assertInlineEquals(actual[i], expected[i], path: '$path[$i]');
  }
}

void assertInlineEquals(BookInline actual, BookInline expected, {required String path}) {
  expect(actual.runtimeType, equals(expected.runtimeType), reason: '$path: типы инлайнов должны совпадать');

  switch ((actual, expected)) {
    case (BookText a, BookText e):
      expect(a.text, equals(e.text), reason: '$path: текст должен совпадать');

    case (BookStrong a, BookStrong e):
      assertInlineListEquals(a.children, e.children, path: '$path.children');

    case (BookEmphasis a, BookEmphasis e):
      assertInlineListEquals(a.children, e.children, path: '$path.children');

    case (BookStrike a, BookStrike e):
      assertInlineListEquals(a.children, e.children, path: '$path.children');

    case (BookCodeSpan a, BookCodeSpan e):
      expect(a.code, equals(e.code), reason: '$path: код инлайна должен совпадать');

    case (BookLink a, BookLink e):
      expect(a.href.toString(), equals(e.href.toString()), reason: '$path: ссылка href должна совпадать');
      assertInlineListEquals(a.children, e.children, path: '$path.children');

    case (BookAnchor a, BookAnchor e):
      expect(a.id, equals(e.id), reason: '$path: id якоря должен совпадать');

    case (BookImageInline a, BookImageInline e):
      expect(a.ref.id.endsWith(e.ref.id), isTrue, reason: '$path: id встроенного изображения должен совпадать');
      expect(a.id, equals(e.id), reason: '$path: id инлайн-изображения должен совпадать');
      expect(a.alt, equals(e.alt), reason: '$path: alt инлайн-изображения должен совпадать');
      expect(a.title, equals(e.title), reason: '$path: title инлайн-изображения должен совпадать');

    case (BookSuperscript a, BookSuperscript e):
      assertInlineListEquals(a.children, e.children, path: '$path.children');

    case (BookSubscript a, BookSubscript e):
      assertInlineListEquals(a.children, e.children, path: '$path.children');

    case (BookFootnoteRef a, BookFootnoteRef e):
      expect(a.id, equals(e.id), reason: '$path: id сноски должен совпадать');

    case (BookLineBreak(), BookLineBreak()):
      break;

    default:
      break;
  }
}
