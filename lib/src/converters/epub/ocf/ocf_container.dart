import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../epub_exceptions.dart';

/// Моделирование записи rootfile в container.xml.
class OcfRootfile {
  final String fullPath;
  final String mediaType;

  const OcfRootfile({required this.fullPath, required this.mediaType});
}

/// Парсер и модель контейнера OCF (Open Container Format 3.3 / 3.4).
class OcfContainer {
  final List<OcfRootfile> rootfiles;

  const OcfContainer({required this.rootfiles});

  /// Возвращает путь к основному OPF файлу.
  String get primaryOpfPath {
    if (rootfiles.isEmpty) {
      throw const EpubInvalidPackageException('No rootfile found in META-INF/container.xml');
    }
    return rootfiles.first.fullPath;
  }

  /// Декодирует контейнер из ZIP архива.
  static OcfContainer fromArchive(Archive archive) {
    final containerFile = archive.findFile('META-INF/container.xml');
    if (containerFile == null) {
      throw const EpubInvalidPackageException('Invalid EPUB: META-INF/container.xml not found');
    }

    final xmlStr = utf8.decode(containerFile.content);
    final document = XmlDocument.parse(xmlStr);

    final rootfiles = <OcfRootfile>[];
    for (final element in document.findAllElements('rootfile')) {
      final fullPath = element.getAttribute('full-path');
      final mediaType = element.getAttribute('media-type') ?? 'application/oebps-package+xml';
      if (fullPath != null && fullPath.isNotEmpty) {
        rootfiles.add(OcfRootfile(fullPath: fullPath, mediaType: mediaType));
      }
    }

    if (rootfiles.isEmpty) {
      throw const EpubInvalidPackageException('Invalid EPUB: META-INF/container.xml contains no valid rootfile');
    }

    return OcfContainer(rootfiles: rootfiles);
  }

  /// Парсит файлы шифрования META-INF/encryption.xml.
  static List<String> parseEncryptionPaths(Archive archive) {
    final encFile = archive.findFile('META-INF/encryption.xml');
    if (encFile == null) return const [];

    try {
      final xmlStr = utf8.decode(encFile.content);
      final document = XmlDocument.parse(xmlStr);
      final encryptedPaths = <String>[];

      for (final ref in document.findAllElements('CipherReference')) {
        final uri = ref.getAttribute('URI');
        if (uri != null && uri.isNotEmpty) {
          encryptedPaths.add(uri);
        }
      }
      return encryptedPaths;
    } catch (_) {
      return const [];
    }
  }
}
