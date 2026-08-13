import 'dart:async';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:dart_book/dart_book.dart';

/// Кодировщик книг в формат FB2.ZIP (упаковка сгенерированного FB2 XML в ZIP-архив).
class Fb2ZipEncoder implements BookEncoder {
  final Fb2Encoder _xmlEncoder;

  Fb2ZipEncoder({Fb2Encoder? xmlEncoder})
      : _xmlEncoder = xmlEncoder ?? Fb2Encoder();

  @override
  bool canEncode(String extension) {
    final ext = extension.toLowerCase();
    return ext == 'fb2.zip' || ext == 'zip';
  }

  @override
  FutureOr<Uint8List> encode(
    Book book, {
    BookEncodingOptions? options,
    bool pretty = true,
    BookResourceResolver? resourceResolver,
  }) async {
    final effectivePretty = options?.pretty ?? pretty;
    final xmlBytes = await _xmlEncoder.encode(
      book,
      options: options,
      pretty: effectivePretty,
      resourceResolver: resourceResolver,
    );

    final archive = Archive();
    final String filename;
    final entryName = options?.entryFilename?.trim();
    if (entryName != null && entryName.isNotEmpty) {
      filename = entryName.toLowerCase().endsWith('.fb2') ? entryName : '$entryName.fb2';
    } else {
      final rawName = book.metadata.title.trim().isNotEmpty
          ? book.metadata.title
          : book.metadata.id;
      final cleanName = rawName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
      filename = cleanName.isNotEmpty ? '$cleanName.fb2' : 'book.fb2';
    }
    archive.addFile(ArchiveFile(filename, xmlBytes.length, xmlBytes));
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }
}
