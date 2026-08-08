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

    // 1. OCF & DRM check
    final encryptedPaths = OcfContainer.parseEncryptionPaths(archive);
    if (encryptedPaths.isNotEmpty) {
      throw EpubEncryptedResourceException(encryptedPaths);
    }

    final ocfContainer = OcfContainer.fromArchive(archive);
    final opfPath = ocfContainer.primaryOpfPath;

    final opfFile = archive.findFile(opfPath);
    if (opfFile == null) throw Exception('Invalid EPUB: OPF file not found at $opfPath');

    final opfXml = XmlDocument.parse(utf8.decode(opfFile.content));
    final opfDir = opfPath.contains('/')
        ? opfPath.substring(0, opfPath.lastIndexOf('/'))
        : '';

    final (metadata, opfId) = _parseMetadata(opfXml, options);

    final manifest = <String, _EpubItem>{};
    for (final element in opfXml.findAllElements('item')) {
      final itemId = element.getAttribute('id')!;
      final href = element.getAttribute('href')!;
      final mediaType = element.getAttribute('media-type')!;
      manifest[itemId] = _EpubItem(itemId, href, mediaType);
    }

    // 2. Parse TOC (nav.xhtml or toc.ncx)
    final navTitlesByHref = <String, String>{};
    final navItem = manifest.values.firstWhere(
      (item) => item.mediaType == 'application/xhtml+xml' && item.href.contains('nav'),
      orElse: () => _EpubItem('', '', ''),
    );
    if (navItem.href.isNotEmpty) {
      final navFile = archive.findFile(_joinPath(opfDir, navItem.href));
      if (navFile != null) {
        final navDoc = EpubNavDocument.parseFromString(utf8.decode(navFile.content));
        for (final entry in navDoc.toc) {
          if (entry.title.isNotEmpty && entry.href.isNotEmpty) {
            navTitlesByHref[entry.href.split('#').first] = entry.title;
          }
        }
      }
    }

    if (navTitlesByHref.isEmpty) {
      final ncxItem = manifest.values.firstWhere(
        (item) => item.mediaType == 'application/x-dtbncx+xml' || item.href.endsWith('.ncx'),
        orElse: () => _EpubItem('', '', ''),
      );
      if (ncxItem.href.isNotEmpty) {
        final ncxFile = archive.findFile(_joinPath(opfDir, ncxItem.href));
        if (ncxFile != null) {
          final ncxDoc = EpubNcxDocument.parseFromString(utf8.decode(ncxFile.content));
          for (final entry in ncxDoc.navMap) {
            if (entry.title.isNotEmpty && entry.href.isNotEmpty) {
              navTitlesByHref[entry.href.split('#').first] = entry.title;
            }
          }
        }
      }
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
        strictMode: options?.strictMode ?? false,
        logger: options?.logger,
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

      final title = navTitlesByHref[item.href] ?? item.id;
      blocks.add(
        BookSection(
          id: idref,
          title: [BookText(title)],
          blocks: chapterBlocks,
        ),
      );
    }

    // 3. Extract all image, font, and css resources
    for (final item in manifest.values) {
      final isImage = item.mediaType.startsWith('image/');
      final isFont = item.mediaType.startsWith('font/') ||
          item.mediaType.contains('font') ||
          item.mediaType.contains('opentype');
      final isCss = item.mediaType == 'text/css';

      if (isImage || isFont || isCss) {
        final path = _joinPath(opfDir, item.href);
        final file = archive.findFile(path);
        if (file != null) {
          final resId = 'epub-res-${item.id}';
          resourceIndex[resId] = BookResource(
            id: resId,
            mediaType: item.mediaType,
            bytes: Uint8List.fromList(file.content),
            fileName: item.href.split('/').last,
          );
        }
      }
    }

    return Book(
      id: options?.id ?? opfId ?? metadata.title.hashCode.toString(),
      metadata: metadata.copyWith(language: options?.lang ?? metadata.language),
      content: BookContent(blocks: blocks),
      resources: resourceIndex.values.toList(),
    );
  }

  (BookMetadata, String?) _parseMetadata(XmlDocument opfXml, BookDecodingOptions? options) {
    final metadataElement = opfXml.findAllElements('metadata').first;

    final id =
        metadataElement.findAllElements('dc:identifier').firstOrNull?.innerText;
    
    final titleElement = metadataElement.findAllElements('dc:title').firstOrNull;
    if (titleElement == null && options?.strictMode == true) {
      throw BookMalformedMetadataException('Missing required element <dc:title> in OPF metadata');
    }
    if (titleElement == null) {
      options?.logger?.call('Warning: missing <dc:title> in OPF metadata, fallback to "Untitled"');
    }
    final title = titleElement?.innerText ?? 'Untitled';

    final language =
        metadataElement.findAllElements('dc:language').firstOrNull?.innerText ??
        'en';

    final descriptionText =
        metadataElement.findAllElements('dc:description').firstOrNull?.innerText;
    final annotation = descriptionText != null && descriptionText.isNotEmpty
        ? BookContent(blocks: [BookParagraph(inlines: [BookText(descriptionText)])])
        : null;

    final contributors = <BookContributor>[];
    for (final element in metadataElement.findAllElements('dc:creator')) {
      contributors.add(
        BookContributor(
          role: BookContributorRole.author,
          name: PersonName(display: element.innerText.trim()),
        ),
      );
    }
    for (final element in metadataElement.findAllElements('dc:contributor')) {
      contributors.add(
        BookContributor(
          role: BookContributorRole.other,
          name: PersonName(display: element.innerText.trim()),
        ),
      );
    }

    final subjects = metadataElement
        .findAllElements('dc:subject')
        .map((e) => BookGenre(code: e.innerText.trim(), name: e.innerText.trim()))
        .toList();

    return (
      BookMetadata(
        title: title,
        language: language,
        contributors: contributors,
        genres: subjects,
        annotation: annotation,
      ),
      id,
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
