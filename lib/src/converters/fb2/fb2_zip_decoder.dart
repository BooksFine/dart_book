import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../../models/book.dart';
import '../../models/converter.dart';
import '../../models/exceptions.dart';
import 'fb2_decoder.dart';

/// Декодировщик книг в формате FB2.ZIP (FB2 XML, упакованный в ZIP-архив).
class Fb2ZipDecoder implements BookDecoder {
  final Fb2Decoder _xmlDecoder;

  Fb2ZipDecoder({Fb2Decoder? xmlDecoder})
      : _xmlDecoder = xmlDecoder ?? Fb2Decoder();

  @override
  bool canDecode(Uint8List bytes, {String? extension}) {
    if (extension == 'fb2.zip') return true;
    if (bytes.length < 4) return false;

    final isZip =
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;

    if (!isZip) return false;

    // Исключаем EPUB файлы
    if (bytes.length >= 58) {
      final mimetypeName = String.fromCharCodes(bytes.sublist(30, 38));
      final mimetypeContent = String.fromCharCodes(bytes.sublist(38, 58));
      if (mimetypeName == 'mimetype' &&
          mimetypeContent == 'application/epub+zip') {
        return false;
      }
    }

    return extension == null || extension.endsWith('.zip');
  }

  @override
  Book decode(Uint8List bytes, {BookDecodingOptions? options}) {
    if (bytes.length < 4 ||
        bytes[0] != 0x50 ||
        bytes[1] != 0x4B ||
        bytes[2] != 0x03 ||
        bytes[3] != 0x04) {
      throw BookFormatException('Provided bytes are not a valid ZIP archive');
    }

    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final fileList = archive.files.where((f) => f.isFile).toList();
      if (fileList.isEmpty) {
        throw BookFormatException('FB2 ZIP archive is empty');
      }

      final fb2File = fileList.firstWhere(
        (f) =>
            f.name.toLowerCase().endsWith('.fb2') ||
            f.name.toLowerCase().endsWith('.xml'),
        orElse: () => fileList.first,
      );

      final rawBytes = Uint8List.fromList(fb2File.content as List<int>);
      return _xmlDecoder.decode(rawBytes, options: options);
    } catch (e) {
      if (e is BookException) rethrow;
      throw BookFormatException('Failed to decode FB2 ZIP archive: $e');
    }
  }
}
