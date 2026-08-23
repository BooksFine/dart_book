import 'dart:math';
import 'dart:typed_data';
import 'package:dart_book/dart_book.dart';

/// Детерминированный генератор псевдослучайных деревьев AST [Book]
/// для Property-Based и Fuzzing тестирования.
class AstGenerator {
  final Random _random;

  AstGenerator([int? seed]) : _random = Random(seed ?? 42);

  /// Генерирует случайную книгу [Book] со всеми типами узлов.
  Book generateBook({
    int maxDepth = 3,
    int blockCount = 12,
    bool includeResources = true,
  }) {
    final resources = includeResources
        ? _generateSampleResources()
        : const <BookResource>[];
    return Book(
      metadata: BookMetadata(
        id: 'gen-book-${_random.nextInt(1000000)}',
        title: _generateString(10, 30),
        language: _random.nextBool() ? 'ru' : 'en',
        contributors: [
          BookContributor(
            role: BookContributorRole.author,
            name: PersonName(
              first: _generateString(4, 10),
              last: _generateString(5, 12),
              display: _generateString(10, 20),
            ),
          ),
        ],
        series: [
          BookSeries(
            name: 'Серия ${_generateString(5, 12)}',
            number: _random.nextInt(10) + 1,
          ),
        ],
        publishInfo: BookPublishInfo(
          publisher: 'Издательство ${_generateString(4, 10)}',
          year: 2020 + _random.nextInt(6),
          isbn:
              '978-5-${_random.nextInt(900) + 100}-${_random.nextInt(9000) + 1000}-0',
        ),
        cover: includeResources
            ? const BookCover(ref: BookResourceRef('img1.png'))
            : null,
      ),
      content: BookContent(
        blocks: List.generate(
          blockCount,
          (i) => _generateBlock(depth: maxDepth),
        ),
        footnotes: [
          BookFootnote(
            id: 'fn_1',
            blocks: [
              BookParagraph(
                inlines: [BookText('Сноска: ${_generateString(10, 30)}')],
              ),
            ],
          ),
        ],
      ),
      resources: resources,
    );
  }

  /// Генерирует блок [BookBlock] со всеми доступными типами блоков.
  BookBlock _generateBlock({required int depth}) {
    final availableTypes = depth > 1 ? 15 : 13;
    final type = _random.nextInt(availableTypes);

    switch (type) {
      case 0:
        return BookParagraph(
          inlines: _generateInlines(count: _random.nextInt(4) + 1),
        );
      case 1:
        return BookHeading(
          level: _random.nextInt(5) + 1,
          text: _generateInlines(count: 2),
        );
      case 2:
        return BookQuote(
          blocks: [BookParagraph(inlines: _generateInlines(count: 2))],
          citation: [BookText(_generateString(5, 15))],
        );
      case 3:
        return BookList(
          ordered: _random.nextBool(),
          items: List.generate(
            _random.nextInt(3) + 1,
            (_) => BookListItem(
              blocks: [BookParagraph(inlines: _generateInlines(count: 1))],
            ),
          ),
        );
      case 4:
        return BookTable(
          rows: [
            BookTableRow(
              cells: [
                BookTableCell(
                  blocks: [
                    BookParagraph(inlines: [BookText(_generateString(3, 8))]),
                  ],
                  colSpan: 1,
                  rowSpan: 1,
                  align: 'center',
                  vAlign: 'top',
                ),
                BookTableCell(
                  blocks: [
                    BookParagraph(inlines: [BookText(_generateString(3, 8))]),
                  ],
                  align: 'right',
                  vAlign: 'bottom',
                ),
              ],
            ),
          ],
        );
      case 5:
        return BookPoem(
          stanzas: [
            BookStanza(
              lines: [
                BookPoemLine(inlines: [BookText(_generateString(10, 25))]),
                BookPoemLine(inlines: [BookText(_generateString(10, 25))]),
              ],
            ),
          ],
        );
      case 6:
        return BookCodeBlock(
          code: 'void test() {\n  final x = ${_random.nextInt(100)};\n}',
          language: 'dart',
        );
      case 7:
        return BookImageBlock(
          id: 'fig-${_random.nextInt(100)}',
          ref: const BookResourceRef('img1.png'),
          alt: _generateString(5, 20),
          title: _generateString(5, 20),
        );
      case 8:
        return const BookAudioBlock(
          ref: BookResourceRef('audio1.mp3'),
          controls: true,
        );
      case 9:
        return const BookVideoBlock(
          ref: BookResourceRef('video1.mp4'),
          posterRef: BookResourceRef('img1.png'),
          controls: true,
        );
      case 10:
        return const BookSvgBlock(
          svg:
              '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><circle cx="50" cy="50" r="40" stroke="green" stroke-width="4" fill="yellow" /></svg>',
        );
      case 11:
        return const BookMathBlock(
          mathml:
              '<math xmlns="http://www.w3.org/1998/Math/MathML"><msup><mi>x</mi><mn>2</mn></msup></math>',
        );
      case 12:
        return const BookHorizontalRule();
      case 13:
        return const BookEmptyLine();
      case 14:
      default:
        final titleText = _generateString(5, 20);
        return BookSection(
          id: 'sec-${_random.nextInt(10000)}',
          title: [BookText(titleText)],
          blocks: [
            BookHeading(level: 2, text: [BookText(titleText)]),
            ...List.generate(
              _random.nextInt(2) + 1,
              (_) => _generateBlock(depth: depth - 1),
            ),
          ],
        );
    }
  }

  /// Генерирует список строчных узлов [BookInline] со всеми инлайн-типами.
  List<BookInline> _generateInlines({required int count}) {
    return List.generate(count, (_) {
      final type = _random.nextInt(12);
      return switch (type) {
        0 => BookText(_generateString(5, 20)),
        1 => BookEmphasis(children: [BookText(_generateString(3, 10))]),
        2 => BookStrong(children: [BookText(_generateString(3, 10))]),
        3 => BookStrike(children: [BookText(_generateString(3, 10))]),
        4 => BookCodeSpan(_generateString(4, 12)),
        5 => BookNamedStyle(
          name: 'style-${_random.nextInt(5)}',
          inlines: [BookText(_generateString(4, 15))],
        ),
        6 => BookLink(
          href: Uri.parse('https://example.com/${_generateString(3, 8)}'),
          children: [BookText(_generateString(4, 10))],
        ),
        7 => BookSuperscript(children: [BookText(_generateString(2, 5))]),
        8 => BookSubscript(children: [BookText(_generateString(2, 5))]),
        9 => BookImageInline(
          id: 'inline-img-${_random.nextInt(100)}',
          ref: const BookResourceRef('img1.png'),
          alt: _generateString(3, 10),
        ),
        10 => BookAnchor('anchor-${_random.nextInt(1000)}'),
        _ => const BookFootnoteRef(id: 'fn_1', label: [BookText('1')]),
      };
    });
  }

  /// Создает пример бинарных ресурсов книги.
  List<BookResource> _generateSampleResources() {
    return [
      BookResource(
        id: 'img1.png',
        mediaType: 'image/png',
        bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
      ),
      BookResource(
        id: 'audio1.mp3',
        mediaType: 'audio/mpeg',
        bytes: Uint8List.fromList([0xFF, 0xFB, 0x90, 0x00]),
      ),
      BookResource(
        id: 'video1.mp4',
        mediaType: 'video/mp4',
        bytes: Uint8List.fromList([
          0x00,
          0x00,
          0x00,
          0x18,
          0x66,
          0x74,
          0x79,
          0x70,
        ]),
      ),
    ];
  }

  /// Генерирует случайную строку на кириллице и латинице.
  String _generateString(int minLen, int maxLen) {
    const chars =
        'абвгдеёжзийклмнопрстуфхцчшщъыьэюя ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789';
    final len = minLen + _random.nextInt(maxLen - minLen + 1);
    return List.generate(
      len,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
  }

  /// Генерирует массив случайных/мутированных байт для фаззинга.
  Uint8List generateCorruptedBytes(int length) {
    return Uint8List.fromList(
      List.generate(length, (_) => _random.nextInt(256)),
    );
  }
}
