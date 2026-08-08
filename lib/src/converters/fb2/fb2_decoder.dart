import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../models/book.dart';
import '../../models/converter.dart';
import '../../models/exceptions.dart';
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
    final description = root.findElements('description').firstOrNull;
    if (description == null && options?.strictMode == true) {
      throw BookMalformedMetadataException('Missing required element <description> in FB2 metadata');
    }

    final titleInfo = description?.findElements('title-info').firstOrNull;
    final titleElement = titleInfo?.findElements('book-title').firstOrNull;

    if (titleElement == null && options?.strictMode == true) {
      throw BookMalformedMetadataException('Missing required element <book-title> in FB2 metadata');
    }
    if (titleElement == null) {
      options?.logger?.call('Warning: missing <book-title> in FB2 metadata, fallback to "Untitled"');
    }
    final title = titleElement?.innerText ?? 'Untitled';
    final docInfo = description?.findElements('document-info').firstOrNull;
    final docId = docInfo?.findElements('id').firstOrNull?.innerText;

    // 3. Используем Fb2Parser для контента
    final parser = Fb2Parser(
      strictMode: options?.strictMode ?? false,
      logger: options?.logger,
      registrar: (src, {required isInline}) {
        // У FB2 ссылки на внутренние ресурсы начинаются с '#'
        return src.startsWith('#') ? src.substring(1) : src;
      },
    );

    final genres = titleInfo
            ?.findElements('genre')
            .map((e) => BookGenre(code: e.innerText.trim(), name: e.innerText.trim()))
            .toList() ??
        const [];

    final annotationElem = titleInfo?.findElements('annotation').firstOrNull;
    final annotation = annotationElem != null
        ? BookContent(blocks: parser.parse(annotationElem.children))
        : null;

    final coverHref = titleInfo
            ?.findElements('coverpage')
            .firstOrNull
            ?.findElements('image')
            .firstOrNull
            ?.getAttribute('l:href') ??
        '';
    final coverId = coverHref.startsWith('#') ? coverHref.substring(1) : coverHref;
    final cover = coverId.isNotEmpty ? BookCover(ref: BookResourceRef(coverId)) : null;

    final seqElem = titleInfo?.findElements('sequence').firstOrNull;
    final seriesName = seqElem?.getAttribute('name');
    final series = seriesName != null && seriesName.isNotEmpty
        ? BookSeries(
            name: seriesName,
            number: int.tryParse(seqElem?.getAttribute('number') ?? ''),
          )
        : null;

    final keywordsText = titleInfo?.findElements('keywords').firstOrNull?.innerText;
    final keywords = keywordsText != null
        ? keywordsText.split(RegExp(r'[,;]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : const <String>[];

    final metadata = BookMetadata(
      title: title,
      language: titleInfo?.findElements('lang').firstOrNull?.innerText ?? 'en',
      contributors: titleInfo != null
          ? titleInfo.findElements('author').map((e) {
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
            }).toList()
          : const [],
      genres: genres,
      annotation: annotation,
      cover: cover,
      series: series,
      keywords: keywords,
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

    final blocks = <BookBlock>[];
    for (final body in root.findElements('body')) {
      final isNotes = body.getAttribute('name') == 'notes';
      final bodyBlocks = parser.parse(body.children);
      if (isNotes) {
        blocks.add(
          BookSection(
            id: 'notes',
            title: const [BookText('Примечания')],
            blocks: bodyBlocks,
          ),
        );
      } else {
        blocks.addAll(bodyBlocks);
      }
    }

    return Book(
      id: options?.id ?? docId ?? metadata.title.hashCode.toString(),
      metadata: metadata.copyWith(language: options?.lang ?? metadata.language),
      content: BookContent(blocks: blocks),
      resources: resources,
    );
  }
}
