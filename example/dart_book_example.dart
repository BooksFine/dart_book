import 'dart:typed_data';

import 'package:dart_book/dart_book.dart';

Future<void> main() async {
  // Use the new API
  final book = await DartBook.load(
    Uint8List.fromList(
      '<h1>Demo</h1><p>Hello <strong>world</strong></p>'.codeUnits,
    ),
    filename: 'demo.html',
    options: (id: 'demo-1', lang: 'en'),
  );

  final fb2 = await Fb2Converter.bookToFb2(book);
  print('FB2 size: ${fb2.length} bytes');

  final blocks = HtmlParser(
    registrar: (src, {required isInline}) => 'resource-$src',
  ).parseFromString('<div>Partial content</div>');
  print('Parsed ${blocks.length} blocks from fragment');
}
