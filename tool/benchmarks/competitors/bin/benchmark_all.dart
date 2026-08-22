import 'dart:io';

import 'package:epub_plus/epub_plus.dart' as epub_plus;
import 'package:epub_pro/epub_pro.dart' as epub_pro;
import 'package:html/parser.dart' as html_parser;

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart run bin/benchmark_all.dart <path-to-epub>');
    exit(1);
  }

  final filePath = args[0];
  final bytes = await File(filePath).readAsBytes();

  // 1. epub_plus: readBook only
  try {
    await epub_plus.EpubReader.readBook(bytes);
    final sw = Stopwatch()..start();
    final book = await epub_plus.EpubReader.readBook(bytes);
    sw.stop();
    final chapters = book.chapters.length;
    print('EPUB_PLUS_RESULT:${sw.elapsedMilliseconds}:$chapters');

    // 1b. epub_plus: readBook + HTML parsing (to DOM)
    final swDom = Stopwatch()..start();
    final bookDom = await epub_plus.EpubReader.readBook(bytes);
    for (final ch in bookDom.chapters) {
      final html = ch.htmlContent;
      if (html != null && html.isNotEmpty) {
        html_parser.parse(html);
      }
    }
    swDom.stop();
    print('EPUB_PLUS_FULL_DOM_RESULT:${swDom.elapsedMilliseconds}:$chapters');
  } catch (e) {
    print('EPUB_PLUS_ERROR:$e');
  }

  // 2. epub_pro: readBook only
  try {
    await epub_pro.EpubReader.readBook(bytes);
    final sw = Stopwatch()..start();
    final book = await epub_pro.EpubReader.readBook(bytes);
    sw.stop();
    final chapters = book.chapters.length;
    print('EPUB_PRO_RESULT:${sw.elapsedMilliseconds}:$chapters');

    // 2b. epub_pro: readBook + HTML parsing (to DOM)
    final swDom = Stopwatch()..start();
    final bookDom = await epub_pro.EpubReader.readBook(bytes);
    for (final ch in bookDom.chapters) {
      final html = ch.htmlContent;
      if (html != null && html.isNotEmpty) {
        html_parser.parse(html);
      }
    }
    swDom.stop();
    print('EPUB_PRO_FULL_DOM_RESULT:${swDom.elapsedMilliseconds}:$chapters');
  } catch (e) {
    print('EPUB_PRO_ERROR:$e');
  }
}
