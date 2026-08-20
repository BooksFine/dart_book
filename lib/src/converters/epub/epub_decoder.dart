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
    final encryptionInfo = OcfContainer.parseEncryptionInfo(archive);
    if (encryptionInfo.drmEncryptedPaths.isNotEmpty) {
      throw EpubEncryptedResourceException(encryptionInfo.drmEncryptedPaths);
    }

    final ocfContainer = OcfContainer.fromArchive(archive);
    final opfPath = ocfContainer.primaryOpfPath;

    final opfFile = archive.findFile(opfPath);
    if (opfFile == null) throw Exception('Invalid EPUB: OPF file not found at $opfPath');

    final opfXml = XmlDocument.parse(utf8.decode(opfFile.content));
    final opfDir = opfPath.contains('/')
        ? opfPath.substring(0, opfPath.lastIndexOf('/'))
        : '';

    final manifest = <String, _EpubItem>{};
    for (final element in opfXml.findAllElements('item')) {
      final itemId = element.getAttribute('id')!;
      final href = element.getAttribute('href')!;
      final mediaType = element.getAttribute('media-type')!;
      final properties = element.getAttribute('properties');
      manifest[itemId] = _EpubItem(itemId, href, mediaType, properties: properties);
    }

    // Extract cover image (EPUB 3 properties="cover-image" or EPUB 2 <meta name="cover" content="...">)
    var coverItemId = manifest.values
        .firstWhere(
          (item) => item.properties?.split(RegExp(r'\s+')).contains('cover-image') == true,
          orElse: () => _EpubItem('', '', ''),
        )
        .id;

    if (coverItemId.isEmpty) {
      final metaCoverElem = opfXml
          .findAllElements('meta')
          .where((e) => e.getAttribute('name')?.toLowerCase() == 'cover')
          .firstOrNull;
      final metaCover = metaCoverElem?.getAttribute('content');
      if (metaCover != null && metaCover.isNotEmpty && manifest.containsKey(metaCover)) {
        coverItemId = metaCover;
      }
    }

    final coverRef = coverItemId.isNotEmpty
        ? BookCover(
            ref: BookResourceRef(
              coverItemId.startsWith('epub-res-')
                  ? coverItemId
                  : 'epub-res-$coverItemId',
            ),
          )
        : null;

    final (metadata, opfId) = _parseMetadata(opfXml, options, cover: coverRef);

    // 2. Parse TOC (nav.xhtml or toc.ncx)
    final navTitlesByHref = <String, String>{};
    final navItem = manifest.values.firstWhere(
      (item) =>
          item.mediaType == 'application/xhtml+xml' &&
          (item.properties?.split(RegExp(r'\s+')).contains('nav') == true ||
              item.href.toLowerCase().contains('nav')),
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

    final manifestByPath = <String, _EpubItem>{};
    for (final item in manifest.values) {
      manifestByPath[item.href] = item;
      manifestByPath[_joinPath(opfDir, item.href)] = item;
    }

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
          final manifestItem = manifestByPath[absolutePath];

          if (manifestItem != null && manifestItem.id.isNotEmpty) {
            return manifestItem.id.startsWith('epub-res-')
                ? manifestItem.id
                : 'epub-res-${manifestItem.id}';
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

    // 3. Extract all image, audio, video, font, and css resources
    for (final item in manifest.values) {
      final isImage = item.mediaType.startsWith('image/');
      final isAudio = item.mediaType.startsWith('audio/');
      final isVideo = item.mediaType.startsWith('video/');
      final isFont = item.mediaType.startsWith('font/') ||
          item.mediaType.contains('font') ||
          item.mediaType.contains('opentype');
      final isCss = item.mediaType == 'text/css';

      if (isImage || isAudio || isVideo || isFont || isCss) {
        final path = _joinPath(opfDir, item.href);
        final file = archive.findFile(path);
        if (file != null) {
          var rawBytes = Uint8List.fromList(file.content);
          if (isFont) {
            final obfAlgo = encryptionInfo.obfuscatedFonts[path] ??
                encryptionInfo.obfuscatedFonts[item.href];
            if (obfAlgo != null) {
              rawBytes = OcfContainer.deobfuscateFont(
                rawBytes,
                obfAlgo,
                opfId ?? metadata.id,
              );
            }
          }

          final resId = item.id.startsWith('epub-res-')
              ? item.id
              : 'epub-res-${item.id}';
          resourceIndex[resId] = BookResource(
            id: resId,
            mediaType: item.mediaType,
            bytes: rawBytes,
            fileName: item.href.split('/').last,
          );
        }
      }
    }

    final finalId = options?.id ?? opfId ?? metadata.id;
    return Book(
      metadata: metadata.copyWith(
        id: finalId,
        language: options?.lang ?? metadata.language,
      ),
      content: BookContent(blocks: blocks),
      resources: resourceIndex.values.toList(),
    );
  }

  (BookMetadata, String?) _parseMetadata(
    XmlDocument opfXml,
    BookDecodingOptions? options, {
    BookCover? cover,
  }) {
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

    // Publisher & ISBN
    final publisher = metadataElement.findAllElements('dc:publisher').firstOrNull?.innerText.trim();
    String? isbn;
    for (final ident in metadataElement.findAllElements('dc:identifier')) {
      final scheme = ident.getAttribute('opf:scheme')?.toUpperCase();
      final text = ident.innerText.trim();
      if (scheme == 'ISBN' || text.toLowerCase().startsWith('urn:isbn:')) {
        isbn = text.replaceFirst(RegExp(r'^urn:isbn:', caseSensitive: false), '').trim();
        break;
      }
    }
    final dateElem = metadataElement.findAllElements('dc:date').firstOrNull;
    final dateText = dateElem?.innerText.trim();
    DateTime? publishedAt;
    if (dateText != null && dateText.isNotEmpty) {
      publishedAt = DateTime.tryParse(dateText);
    }
    final publishInfo = (publisher != null || isbn != null || publishedAt != null)
        ? BookPublishInfo(
            publisher: publisher?.isNotEmpty == true ? publisher : null,
            isbn: isbn?.isNotEmpty == true ? isbn : null,
            year: publishedAt?.year,
          )
        : null;

    // Series (EPUB 3 belongs-to-collection or Calibre metadata)
    final seriesList = <BookSeries>[];
    for (final meta in metadataElement.findAllElements('meta')) {
      final prop = meta.getAttribute('property');
      if (prop == 'belongs-to-collection') {
        final collectionName = meta.innerText.trim();
        final collectionId = meta.getAttribute('id');
        int? position;
        if (collectionId != null) {
          final posElem = metadataElement
              .findAllElements('meta')
              .where((e) => e.getAttribute('refines') == '#$collectionId' && e.getAttribute('property') == 'group-position')
              .firstOrNull;
          if (posElem != null) {
            position = int.tryParse(posElem.innerText.trim());
          }
        }
        if (collectionName.isNotEmpty) {
          seriesList.add(BookSeries(name: collectionName, number: position));
        }
      }
    }
    if (seriesList.isEmpty) {
      final calibreSeries = metadataElement
          .findAllElements('meta')
          .where((e) => e.getAttribute('name') == 'calibre:series')
          .firstOrNull
          ?.getAttribute('content');
      if (calibreSeries != null && calibreSeries.isNotEmpty) {
        final posStr = metadataElement
            .findAllElements('meta')
            .where((e) => e.getAttribute('name') == 'calibre:series_index')
            .firstOrNull
            ?.getAttribute('content');
        seriesList.add(
          BookSeries(name: calibreSeries, number: posStr != null ? int.tryParse(posStr) : null),
        );
      }
    }

    // Source info
    final sourceText = metadataElement.findAllElements('dc:source').firstOrNull?.innerText.trim();
    final sourceLangMeta = metadataElement
        .findAllElements('meta')
        .where((e) => e.getAttribute('property') == 'source-language')
        .firstOrNull
        ?.innerText
        .trim();

    // Layout
    var layout = BookLayout.reflowable;
    final layoutMeta = metadataElement
        .findAllElements('meta')
        .where((e) => e.getAttribute('property') == 'rendition:layout')
        .firstOrNull
        ?.innerText
        .trim();
    if (layoutMeta == 'pre-paginated') {
      layout = BookLayout.fixedLayout;
    } else if (layoutMeta == 'roll') {
      layout = BookLayout.roll;
    }

    final metadataId = id ?? title.hashCode.toString();

    return (
      BookMetadata(
        id: metadataId,
        title: title,
        language: language,
        contributors: contributors,
        genres: subjects,
        annotation: annotation,
        cover: cover,
        series: seriesList,
        publishInfo: publishInfo,
        srcLang: sourceLangMeta?.isNotEmpty == true ? sourceLangMeta : null,
        srcTitleInfo: sourceText?.isNotEmpty == true ? BookSourceTitleInfo(title: sourceText) : null,
        layout: layout,
        publishedAt: publishedAt,
      ),
      id,
    );
  }

  String _joinPath(String dir, String file) {
    final normalizedDir = dir.replaceAll(r'\', '/');
    final normalizedFile = file.replaceAll(r'\', '/');
    if (normalizedDir.isEmpty) {
      return normalizedFile.startsWith('/') ? normalizedFile.substring(1) : normalizedFile;
    }
    final parts = normalizedDir.split('/')..addAll(normalizedFile.split('/'));
    final result = <String>[];
    for (final part in parts) {
      if (part == '.' || part.isEmpty) continue;
      if (part == '..') {
        if (result.isNotEmpty) result.removeLast();
      } else {
        result.add(part);
      }
    }
    return result.join('/');
  }

  String _resolveRelativePath(String contextDir, String relativePath) {
    final normalized = relativePath.replaceAll(r'\', '/');
    if (normalized.startsWith('/') ||
        normalized.contains('://') ||
        normalized.startsWith('data:')) {
      return normalized;
    }
    return _joinPath(contextDir, normalized);
  }
}

class _EpubItem {
  final String id;
  final String href;
  final String mediaType;
  final String? properties;

  _EpubItem(this.id, this.href, this.mediaType, {this.properties});
}
