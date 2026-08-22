import 'resource_naming_policy.dart';

class BookEncodingOptions {
  /// Переопределение глобального идентификатора документа (например: "UCM-AT-849201").
  final String? documentId;

  /// Название и версия программы-генератора (например: "ReUltimateCopyManager 1.0.0").
  final String? programUsed;

  /// Имя файла внутри архива для FB2.ZIP (например: "НазваниеКниги.fb2").
  final String? entryFilename;

  /// Политика именования медиа-ресурсов (по умолчанию: preserve — сохранение оригинальных имён).
  final BookResourceNamingPolicy namingPolicy;

  /// Имя файла для обложки (по умолчанию: "cover").
  final String coverFilename;

  /// Форматировать ли XML с отступами.
  final bool pretty;

  /// Сжимать ли ZIP-архив при упаковке FB2.ZIP (по умолчанию: true).
  /// Установка в false отключает Deflate-сжатие, ускоряя сохранение в десятки раз.
  final bool compressZip;

  const BookEncodingOptions({
    this.documentId,
    this.programUsed,
    this.entryFilename,
    this.namingPolicy = BookResourceNamingPolicy.preserve,
    this.coverFilename = 'cover',
    this.pretty = true,
    this.compressZip = true,
  });
}
