import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../models/book.dart';
import '../../models/converter.dart';
import '../../parsers/fb2_parser.dart';

class Fb2Decoder implements BookDecoder {
  @override
  bool canDecode(Uint8List bytes, {String? extension}) {
    if (extension == 'fb2' || extension == 'fb2.zip') return true;
    if (bytes.length < 4) return false;

    final isZip =
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;

    if (isZip) {
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

    final start = String.fromCharCodes(bytes.take(50)).toLowerCase();
    return start.contains('<?xml') || start.contains('<fictionbook');
  }

  @override
  Book decode(Uint8List bytes, {BookDecodingOptions? options}) {
    final String content;
    if (bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04) {
      final archive = ZipDecoder().decodeBytes(bytes);
      final fb2File = archive.files.firstWhere(
        (f) =>
            f.name.toLowerCase().endsWith('.fb2') ||
            f.name.toLowerCase().endsWith('.xml'),
        orElse: () => throw Exception('No FB2 file found in ZIP archive'),
      );
      content = utf8.decode(fb2File.content);
    } else {
      content = utf8.decode(bytes);
    }

    final document = XmlDocument.parse(content);
    final root = document.rootElement;

    // 1. Извлекаем метаданные
    final description = root.findElements('description').first;
    final titleInfo = description.findElements('title-info').first;
    final docInfo = description.findElements('document-info').firstOrNull;
    final docId = docInfo?.findElements('id').firstOrNull?.innerText;

    final metadata = BookMetadata(
      title: titleInfo.findElements('book-title').first.innerText,
      language: titleInfo.findElements('lang').firstOrNull?.innerText ?? 'en',
      contributors: titleInfo.findElements('author').map((e) {
        final rawDisplay = e.innerText.replaceAll(RegExp(r'\s+'), ' ').trim();
        return BookContributor(
          role: BookContributorRole.author,
          name: PersonName(
            first: e.findElements('first-name').firstOrNull?.innerText,
            middle: e.findElements('middle-name').firstOrNull?.innerText,
            last: e.findElements('last-name').firstOrNull?.innerText,
            nickname: e.findElements('nickname').firstOrNull?.innerText,
            display: rawDisplay.isNotEmpty ? rawDisplay : null,
          ),
        );
      }).toList(),
    );

    // 2. Извлекаем ресурсы (binary элементы)
    final resources = <BookResource>[];
    for (final binary in root.findElements('binary')) {
      final resId = binary.getAttribute('id');
      final contentType = binary.getAttribute('content-type');
      if (resId != null && contentType != null) {
        resources.add(
          BookResource(
            id: resId,
            mediaType: contentType,
            bytes: base64Decode(binary.innerText.trim()),
          ),
        );
      }
    }

    // 3. Используем Fb2Parser для контента
    final parser = Fb2Parser(
      registrar: (src, {required isInline}) {
        // У FB2 ссылки на внутренние ресурсы начинаются с '#'
        return src.startsWith('#') ? src.substring(1) : src;
      },
    );

    final blocks = <BookBlock>[];
    for (final body in root.findElements('body')) {
      if (body.getAttribute('name') == 'notes') continue;
      // Мы передаем фрагмент XML (body) парсеру
      blocks.addAll(parser.parse(body.children));
    }

    return Book(
      id: options?.id ?? docId ?? metadata.title.hashCode.toString(),
      metadata: metadata.copyWith(language: options?.lang ?? metadata.language),
      content: BookContent(blocks: blocks),
      resources: resources,
    );
  }
}
