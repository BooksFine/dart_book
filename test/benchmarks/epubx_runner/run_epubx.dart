import 'dart:io';
import 'package:epubx/epubx.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart run run_epubx.dart <path-to-epub>');
    exit(1);
  }

  final filePath = args[0];
  final bytes = await File(filePath).readAsBytes();

  // Warmup
  await EpubReader.readBook(bytes);

  // Measure
  final stopwatch = Stopwatch()..start();
  final book = await EpubReader.readBook(bytes);
  stopwatch.stop();

  final chapterCount = book.Chapters?.length ?? 0;
  print('EPUBX_RESULT:${stopwatch.elapsedMilliseconds}:$chapterCount');
}
