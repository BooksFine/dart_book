import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';
import '../epub_exceptions.dart';

/// Моделирование записи rootfile в container.xml.
class OcfRootfile {
  final String fullPath;
  final String mediaType;

  const OcfRootfile({required this.fullPath, required this.mediaType});
}

/// Информация о шифровании и обфускации из META-INF/encryption.xml.
class OcfEncryptionInfo {
  final Map<String, String> obfuscatedFonts;
  final List<String> drmEncryptedPaths;

  const OcfEncryptionInfo({
    this.obfuscatedFonts = const {},
    this.drmEncryptedPaths = const [],
  });
}

/// Парсер и модель контейнера OCF (Open Container Format 3.3 / 3.4).
class OcfContainer {
  final List<OcfRootfile> rootfiles;

  const OcfContainer({required this.rootfiles});

  /// Возвращает путь к основному OPF файлу.
  String get primaryOpfPath {
    if (rootfiles.isEmpty) {
      throw const EpubInvalidPackageException(
        'No rootfile found in META-INF/container.xml',
      );
    }
    return rootfiles.first.fullPath;
  }

  /// Декодирует контейнер из ZIP архива.
  static OcfContainer fromArchive(Archive archive) {
    final containerFile = archive.findFile('META-INF/container.xml');
    if (containerFile == null) {
      throw const EpubInvalidPackageException(
        'Invalid EPUB: META-INF/container.xml not found',
      );
    }

    final xmlStr = utf8.decode(containerFile.content);
    final document = XmlDocument.parse(xmlStr);

    final rootfiles = <OcfRootfile>[];
    for (final element in document.findAllElements('rootfile')) {
      final fullPath = element.getAttribute('full-path');
      final mediaType =
          element.getAttribute('media-type') ?? 'application/oebps-package+xml';
      if (fullPath != null && fullPath.isNotEmpty) {
        rootfiles.add(OcfRootfile(fullPath: fullPath, mediaType: mediaType));
      }
    }

    if (rootfiles.isEmpty) {
      throw const EpubInvalidPackageException(
        'Invalid EPUB: META-INF/container.xml contains no valid rootfile',
      );
    }

    return OcfContainer(rootfiles: rootfiles);
  }

  /// Парсит информацию о шифровании и обфускации из META-INF/encryption.xml.
  static OcfEncryptionInfo parseEncryptionInfo(Archive archive) {
    final encFile = archive.findFile('META-INF/encryption.xml');
    if (encFile == null) return const OcfEncryptionInfo();

    try {
      final xmlStr = utf8.decode(encFile.content);
      final document = XmlDocument.parse(xmlStr);
      final obfuscatedFonts = <String, String>{};
      final drmEncryptedPaths = <String>[];

      for (final encData in document.findAllElements('EncryptedData')) {
        final methodElem = encData.findElements('EncryptionMethod').firstOrNull;
        final algorithm = methodElem?.getAttribute('Algorithm') ?? '';
        final uri = encData
            .findAllElements('CipherReference')
            .firstOrNull
            ?.getAttribute('URI');
        if (uri == null || uri.isEmpty) continue;

        if (algorithm == 'http://www.idpf.org/2008/embedding' ||
            algorithm == 'http://ns.adobe.com/pdf/enc#RC') {
          obfuscatedFonts[uri] = algorithm;
        } else {
          drmEncryptedPaths.add(uri);
        }
      }

      return OcfEncryptionInfo(
        obfuscatedFonts: obfuscatedFonts,
        drmEncryptedPaths: drmEncryptedPaths,
      );
    } catch (_) {
      return const OcfEncryptionInfo();
    }
  }

  /// Парсит список путей к зашифрованным DRM-ресурсам.
  static List<String> parseEncryptionPaths(Archive archive) {
    return parseEncryptionInfo(archive).drmEncryptedPaths;
  }

  /// Деобфусцирует шрифт по алгоритмам IDPF или Adobe.
  static Uint8List deobfuscateFont(
    Uint8List bytes,
    String algorithm,
    String publicationUid,
  ) {
    if (bytes.isEmpty) return bytes;
    final cleanUid = publicationUid.replaceAll(RegExp(r'[\s\t\r\n]'), '');
    final result = Uint8List.fromList(bytes);

    if (algorithm == 'http://www.idpf.org/2008/embedding') {
      // IDPF algorithm: SHA-1 of publication UID, XOR first 1040 bytes (52 * 20 bytes)
      final key = sha1.convert(utf8.encode(cleanUid)).bytes;
      final limit = result.length < 1040 ? result.length : 1040;
      for (var i = 0; i < limit; i++) {
        result[i] ^= key[i % key.length];
      }
    } else if (algorithm == 'http://ns.adobe.com/pdf/enc#RC') {
      // Adobe algorithm: UUID hex digits to 16 bytes, XOR first 1024 bytes (64 * 16 bytes)
      final hex = cleanUid
          .replaceAll(RegExp(r'^urn:uuid:', caseSensitive: false), '')
          .replaceAll('-', '')
          .replaceAll(':', '');
      final key = <int>[];
      for (var i = 0; i < hex.length - 1 && key.length < 16; i += 2) {
        final byte = int.tryParse(hex.substring(i, i + 2), radix: 16);
        if (byte != null) key.add(byte);
      }
      if (key.isNotEmpty) {
        final limit = result.length < 1024 ? result.length : 1024;
        for (var i = 0; i < limit; i++) {
          result[i] ^= key[i % key.length];
        }
      }
    }

    return result;
  }
}
