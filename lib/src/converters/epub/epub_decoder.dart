import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:dart_book/dart_book.dart';
import 'package:xml/xml.dart';

class EpubDecoder implements BookDecoder {
  @override
  bool canDecode(Uint8List bytes, {String? extension}) {
    if (extension == 'epub') return true;
    if (bytes.length < 58) return false;

    // Check for ZIP magic bytes
    if (bytes[0] != 0x50 ||
        bytes[1] != 0x4B ||
        bytes[2] != 0x03 ||
        bytes[3] != 0x04) {
      return false;
    }

    // Check for 'mimetype' at offset 30 and 'application/epub+zip' at offset 38
    final mimetypeName = String.fromCharCodes(bytes.sublist(30, 38));
    final mimetypeContent = String.fromCharCodes(bytes.sublist(38, 58));
    return mimetypeName == 'mimetype' &&
        mimetypeContent == 'application/epub+zip';
  }

  @override
  Future<Book> decode(Uint8List bytes, {BookDecodingOptions? options}) async {
    final archive = ZipDecoder().decodeBytes(bytes);

    final containerFile = archive.findFile('META-INF/container.xml');
    if (containerFile == null) {
      throw Exception('Invalid EPUB: META-INF/container.xml not found');
    }

    final containerXml = XmlDocument.parse(utf8.decode(containerFile.content));
    final opfPath = containerXml
        .findAllElements('rootfile')
        .first
        .getAttribute('full-path');
    if (opfPath == null) throw Exception('Invalid EPUB: OPF path not found');

    final opfFile = archive.findFile(opfPath);
    if (opfFile == null) throw Exception('Invalid EPUB: OPF file not found');

    final opfXml = XmlDocument.parse(utf8.decode(opfFile.content));
    final opfDir = opfPath.contains('/')
        ? opfPath.substring(0, opfPath.lastIndexOf('/'))
        : '';

    final metadata = _parseMetadata(opfXml);

    final manifest = <String, _EpubItem>{};
    for (final element in opfXml.findAllElements('item')) {
      final itemId = element.getAttribute('id')!;
      final href = element.getAttribute('href')!;
      final mediaType = element.getAttribute('media-type')!;
      manifest[itemId] = _EpubItem(itemId, href, mediaType);
    }

    final spine = opfXml
        .findAllElements('itemref')
        .map((e) => e.getAttribute('idref')!)
        .toList();

    final blocks = <BookBlock>[];
    final resourceIndex = <String, BookResource>{};

    for (final idref in spine) {
      final item = manifest[idref];
      if (item == null) continue;

      final chapterPath = _joinPath(opfDir, item.href);
      final chapterFile = archive.findFile(chapterPath);
      if (chapterFile == null) continue;

      final chapterDir = chapterPath.contains('/')
          ? chapterPath.substring(0, chapterPath.lastIndexOf('/'))
          : '';

      final htmlParser = HtmlParser(
        registrar: (src, {isInline = false}) {
          if (src.startsWith('data:')) {
            return 'data-${src.hashCode.abs()}';
          }

          final absolutePath = _resolveRelativePath(chapterDir, src);

          final manifestItem = manifest.values.firstWhere(
            (item) =>
                item.href == absolutePath ||
                _joinPath(opfDir, item.href) == absolutePath,
            orElse: () => _EpubItem('', '', ''),
          );

          if (manifestItem.id.isNotEmpty) {
            return 'epub-res-${manifestItem.id}';
          }

          return src;
        },
      );

      final chapterHtml = utf8.decode(chapterFile.content);
      final chapterBlocks = htmlParser.parseFromString(chapterHtml);

      blocks.add(
        BookSection(
          id: idref,
          title: [BookText(item.id)],
          blocks: chapterBlocks,
        ),
      );
    }

    for (final item in manifest.values) {
      if (item.mediaType.startsWith('image/')) {
        final path = _joinPath(opfDir, item.href);
        final file = archive.findFile(path);
        if (file != null) {
          final resId = 'epub-res-${item.id}';
          resourceIndex[resId] = BookResource(
            id: resId,
            mediaType: item.mediaType,
            bytes: Uint8List.fromList(file.content),
          );
        }
      }
    }

    return Book(
      id: options?.id ?? metadata.title.hashCode.toString(),
      metadata: metadata.copyWith(language: options?.lang ?? metadata.language),
      content: BookContent(blocks: blocks),
      resources: resourceIndex.values.toList(),
    );
  }

  BookMetadata _parseMetadata(XmlDocument opfXml) {
    final metadataElement = opfXml.findAllElements('metadata').first;

    final title =
        metadataElement.findAllElements('dc:title').firstOrNull?.innerText ??
        'Untitled';
    final language =
        metadataElement.findAllElements('dc:language').firstOrNull?.innerText ??
        'en';

    final contributors = <BookContributor>[];
    for (final element in metadataElement.findAllElements('dc:creator')) {
      contributors.add(
        BookContributor(
          role: BookContributorRole.author,
          name: PersonName(display: element.innerText),
        ),
      );
    }

    return BookMetadata(
      title: title,
      language: language,
      contributors: contributors,
    );
  }

  String _joinPath(String dir, String file) {
    if (dir.isEmpty) return file;
    final parts = dir.split('/')..addAll(file.split('/'));
    final result = <String>[];
    for (final part in parts) {
      if (part == '.') continue;
      if (part == '..') {
        if (result.isNotEmpty) result.removeLast();
      } else {
        result.add(part);
      }
    }
    return result.join('/');
  }

  String _resolveRelativePath(String contextDir, String relativePath) {
    if (relativePath.startsWith('/') ||
        relativePath.contains('://') ||
        relativePath.startsWith('data:')) {
      return relativePath;
    }
    return _joinPath(contextDir, relativePath);
  }
}

class _EpubItem {
  final String id;
  final String href;
  final String mediaType;

  _EpubItem(this.id, this.href, this.mediaType);
}
