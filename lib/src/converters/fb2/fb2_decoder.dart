import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../../models/book.dart';
import '../../models/converter.dart';
import '../../models/exceptions.dart';
import '../../parsers/fb2_parser.dart';

class Fb2Decoder implements BookDecoder {
  @override
  bool canDecode(Uint8List bytes, {String? extension}) {
    if (extension == 'fb2' || extension == 'xml') return true;
    if (bytes.length < 4) return false;

    // Исключаем ZIP файлы в чистом Fb2Decoder
    final isZip =
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;
    if (isZip) return false;

    final start = String.fromCharCodes(bytes.take(50)).toLowerCase();
    return start.contains('<?xml') || start.contains('<fictionbook');
  }

  @override
  Book decode(Uint8List bytes, {BookDecodingOptions? options}) {
    final content = _decodeXmlBytes(bytes);

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

    final customInfoSeqUrl = description
        ?.findElements('custom-info')
        .where((e) => e.getAttribute('info-type') == 'sequence-url')
        .firstOrNull
        ?.innerText
        .trim();
    final seriesUrl = customInfoSeqUrl != null && customInfoSeqUrl.isNotEmpty
        ? Uri.tryParse(customInfoSeqUrl)
        : null;

    final seriesList = <BookSeries>[];
    for (final seqElem in titleInfo?.findElements('sequence') ?? const <XmlElement>[]) {
      final name = seqElem.getAttribute('name');
      if (name != null && name.isNotEmpty) {
        seriesList.add(
          BookSeries(
            name: name,
            number: int.tryParse(seqElem.getAttribute('number') ?? ''),
            url: seriesUrl,
          ),
        );
      }
    }
    if (seriesList.isEmpty && seriesUrl != null) {
      seriesList.add(BookSeries(name: '', url: seriesUrl));
    }

    final keywordsText = titleInfo?.findElements('keywords').firstOrNull?.innerText;
    final keywords = keywordsText != null
        ? keywordsText.split(RegExp(r'[,;]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : const <String>[];

    final contributors = <BookContributor>[];
    if (titleInfo != null) {
      for (final e in titleInfo.findElements('author')) {
        final firstName = e.findElements('first-name').firstOrNull?.innerText.trim();
        final middleName = e.findElements('middle-name').firstOrNull?.innerText.trim();
        final lastName = e.findElements('last-name').firstOrNull?.innerText.trim();
        final nickname = e.findElements('nickname').firstOrNull?.innerText.trim();
        final homePageStr = e.findElements('home-page').firstOrNull?.innerText.trim();
        final emailStr = e.findElements('email').firstOrNull?.innerText.trim();

        final nameParts = [
          if (firstName != null && firstName.isNotEmpty) firstName,
          if (middleName != null && middleName.isNotEmpty) middleName,
          if (lastName != null && lastName.isNotEmpty) lastName,
        ];
        final display = nameParts.isNotEmpty
            ? nameParts.join(' ')
            : (nickname != null && nickname.isNotEmpty ? nickname : null);

        contributors.add(
          BookContributor(
            role: BookContributorRole.author,
            name: PersonName(
              first: firstName?.isNotEmpty == true ? firstName : null,
              middle: middleName?.isNotEmpty == true ? middleName : null,
              last: lastName?.isNotEmpty == true ? lastName : null,
              nickname: nickname?.isNotEmpty == true ? nickname : null,
              display: display,
            ),
            homePage: homePageStr != null && homePageStr.isNotEmpty ? Uri.tryParse(homePageStr) : null,
            email: emailStr != null && emailStr.isNotEmpty ? emailStr : null,
          ),
        );
      }
      for (final e in titleInfo.findElements('translator')) {
        final firstName = e.findElements('first-name').firstOrNull?.innerText.trim();
        final middleName = e.findElements('middle-name').firstOrNull?.innerText.trim();
        final lastName = e.findElements('last-name').firstOrNull?.innerText.trim();
        final nickname = e.findElements('nickname').firstOrNull?.innerText.trim();
        final homePageStr = e.findElements('home-page').firstOrNull?.innerText.trim();
        final emailStr = e.findElements('email').firstOrNull?.innerText.trim();

        final nameParts = [
          if (firstName != null && firstName.isNotEmpty) firstName,
          if (middleName != null && middleName.isNotEmpty) middleName,
          if (lastName != null && lastName.isNotEmpty) lastName,
        ];
        final display = nameParts.isNotEmpty
            ? nameParts.join(' ')
            : (nickname != null && nickname.isNotEmpty ? nickname : null);

        contributors.add(
          BookContributor(
            role: BookContributorRole.translator,
            name: PersonName(
              first: firstName?.isNotEmpty == true ? firstName : null,
              middle: middleName?.isNotEmpty == true ? middleName : null,
              last: lastName?.isNotEmpty == true ? lastName : null,
              nickname: nickname?.isNotEmpty == true ? nickname : null,
              display: display,
            ),
            homePage: homePageStr != null && homePageStr.isNotEmpty ? Uri.tryParse(homePageStr) : null,
            email: emailStr != null && emailStr.isNotEmpty ? emailStr : null,
          ),
        );
      }
    }

    final pubInfoElem = description?.findElements('publish-info').firstOrNull;
    BookPublishInfo? publishInfo;
    if (pubInfoElem != null) {
      final publisher = pubInfoElem.findElements('publisher').firstOrNull?.innerText.trim();
      final city = pubInfoElem.findElements('city').firstOrNull?.innerText.trim();
      final yearStr = pubInfoElem.findElements('year').firstOrNull?.innerText.trim();
      final isbn = pubInfoElem.findElements('isbn').firstOrNull?.innerText.trim();
      publishInfo = BookPublishInfo(
        publisher: publisher?.isNotEmpty == true ? publisher : null,
        city: city?.isNotEmpty == true ? city : null,
        year: yearStr != null ? int.tryParse(yearStr) : null,
        isbn: isbn?.isNotEmpty == true ? isbn : null,
      );
    }

    final srcLang = titleInfo?.findElements('src-lang').firstOrNull?.innerText.trim();
    final srcTitleInfoElem = description?.findElements('src-title-info').firstOrNull;
    BookSourceTitleInfo? srcTitleInfo;
    if (srcTitleInfoElem != null) {
      final srcTitle = srcTitleInfoElem.findElements('book-title').firstOrNull?.innerText.trim();
      final srcLanguage = srcTitleInfoElem.findElements('lang').firstOrNull?.innerText.trim();
      final srcAuthors = <BookContributor>[];
      for (final e in srcTitleInfoElem.findElements('author')) {
        final firstName = e.findElements('first-name').firstOrNull?.innerText.trim();
        final middleName = e.findElements('middle-name').firstOrNull?.innerText.trim();
        final lastName = e.findElements('last-name').firstOrNull?.innerText.trim();
        final nickname = e.findElements('nickname').firstOrNull?.innerText.trim();
        final nameParts = [
          if (firstName != null && firstName.isNotEmpty) firstName,
          if (middleName != null && middleName.isNotEmpty) middleName,
          if (lastName != null && lastName.isNotEmpty) lastName,
        ];
        final display = nameParts.isNotEmpty
            ? nameParts.join(' ')
            : (nickname != null && nickname.isNotEmpty ? nickname : null);
        srcAuthors.add(
          BookContributor(
            role: BookContributorRole.author,
            name: PersonName(
              first: firstName?.isNotEmpty == true ? firstName : null,
              middle: middleName?.isNotEmpty == true ? middleName : null,
              last: lastName?.isNotEmpty == true ? lastName : null,
              nickname: nickname?.isNotEmpty == true ? nickname : null,
              display: display,
            ),
          ),
        );
      }
      srcTitleInfo = BookSourceTitleInfo(
        title: srcTitle?.isNotEmpty == true ? srcTitle : null,
        language: srcLanguage?.isNotEmpty == true ? srcLanguage : null,
        authors: srcAuthors,
      );
    }

    final dateElem = titleInfo?.findElements('date').firstOrNull ??
        docInfo?.findElements('date').firstOrNull;
    final dateValue = dateElem?.getAttribute('value');
    final dateText = dateElem?.innerText.trim();
    DateTime? parsedDate;
    if (dateValue != null && dateValue.isNotEmpty) {
      parsedDate = DateTime.tryParse(dateValue);
    }
    if (parsedDate == null && dateText != null && dateText.isNotEmpty) {
      parsedDate = DateTime.tryParse(dateText);
    }

    final metadata = BookMetadata(
      id: docId ?? title.hashCode.toString(),
      title: title,
      language: titleInfo?.findElements('lang').firstOrNull?.innerText ?? 'en',
      contributors: contributors,
      genres: genres,
      annotation: annotation,
      cover: cover,
      series: seriesList,
      keywords: keywords,
      publishInfo: publishInfo,
      srcLang: srcLang?.isNotEmpty == true ? srcLang : null,
      srcTitleInfo: srcTitleInfo,
      publishedAt: parsedDate,
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
    final footnotes = <BookFootnote>[];
    for (final body in root.findElements('body')) {
      final isNotes = body.getAttribute('name') == 'notes';
      if (isNotes) {
        for (final section in body.findElements('section')) {
          final sectionId = section.getAttribute('id') ?? '';
          final sectionBlocks = parser.parse(
            section.children.where(
              (e) => e is! XmlElement || e.localName != 'title',
            ),
          );
          footnotes.add(BookFootnote(id: sectionId, blocks: sectionBlocks));
        }
        if (footnotes.isEmpty && body.children.isNotEmpty) {
          final bodyBlocks = parser.parse(
            body.children.where(
              (e) => e is! XmlElement || e.localName != 'title',
            ),
          );
          footnotes.add(BookFootnote(id: 'notes', blocks: bodyBlocks));
        }
      } else {
        final bodyBlocks = parser.parse(
          body.children.where(
            (e) => e is! XmlElement || e.localName != 'title',
          ),
        );
        blocks.addAll(bodyBlocks);
      }
    }

    final finalId = options?.id ?? docId ?? metadata.id;
    return Book(
      metadata: metadata.copyWith(
        id: finalId,
        language: options?.lang ?? metadata.language,
      ),
      content: BookContent(blocks: blocks, footnotes: footnotes),
      resources: resources,
    );
  }
}

String _decodeXmlBytes(Uint8List rawBytes) {
  final headerSample = String.fromCharCodes(rawBytes.take(150)).toLowerCase();
  if (headerSample.contains('encoding="windows-1251"') ||
      headerSample.contains('encoding="cp1251"')) {
    return _decodeWindows1251(rawBytes);
  }

  try {
    return utf8.decode(rawBytes);
  } catch (_) {
    return _decodeWindows1251(rawBytes);
  }
}

const _win1251Lookup = <int, int>{
  0x80: 0x0402, 0x81: 0x0403, 0x82: 0x201A, 0x83: 0x0453, 0x84: 0x201E,
  0x85: 0x2026, 0x86: 0x2020, 0x87: 0x2021, 0x88: 0x20AC, 0x89: 0x2030,
  0x8A: 0x0409, 0x8B: 0x2039, 0x8C: 0x040A, 0x8D: 0x040C, 0x8E: 0x040B,
  0x8F: 0x040F, 0x90: 0x0452, 0x91: 0x2018, 0x92: 0x2019, 0x93: 0x201C,
  0x94: 0x201D, 0x95: 0x2022, 0x96: 0x2013, 0x97: 0x2014, 0x99: 0x2122,
  0x9A: 0x0459, 0x9B: 0x203A, 0x9C: 0x045A, 0x9D: 0x045C, 0x9E: 0x045B,
  0x9F: 0x045F, 0xA0: 0x00A0, 0xA1: 0x040E, 0xA2: 0x045E, 0xA3: 0x0408,
  0xA4: 0x00A4, 0xA5: 0x0490, 0xA6: 0x00A6, 0xA7: 0x00A7, 0xA8: 0x0401,
  0xA9: 0x00A9, 0xAA: 0x0404, 0xAB: 0x00AB, 0xAC: 0x00AC, 0xAD: 0x00AD,
  0xAE: 0x00AE, 0xAF: 0x0407, 0xB0: 0x00B0, 0xB1: 0x00B1, 0xB2: 0x0406,
  0xB3: 0x0456, 0xB4: 0x0491, 0xB5: 0x00B5, 0xB6: 0x00B6, 0xB7: 0x00B7,
  0xB8: 0x0451, 0xB9: 0x2116, 0xBA: 0x0454, 0xBB: 0x00BB, 0xBC: 0x0458,
  0xBD: 0x0405, 0xBE: 0x0455, 0xBF: 0x0457,
};

String _decodeWindows1251(Uint8List bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    if (byte < 0x80) {
      buffer.writeCharCode(byte);
    } else if (byte >= 0xC0 && byte <= 0xFF) {
      buffer.writeCharCode(0x0410 + (byte - 0xC0));
    } else {
      final code = _win1251Lookup[byte] ?? byte;
      buffer.writeCharCode(code);
    }
  }
  return buffer.toString();
}
