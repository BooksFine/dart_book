import 'dart:async';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../../models/book.dart';
import '../../models/converter.dart';
import 'fb2_encoder.dart';

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
    bool pretty = true,
    BookResourceResolver? resourceResolver,
  }) async {
    final xmlBytes = await _xmlEncoder.encode(
      book,
      pretty: pretty,
      resourceResolver: resourceResolver,
    );

    final archive = Archive();
    final filename = book.id.isNotEmpty ? '${book.id}.fb2' : 'book.fb2';
    archive.addFile(ArchiveFile(filename, xmlBytes.length, xmlBytes));
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }
}
