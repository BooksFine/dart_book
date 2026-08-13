import 'resource_naming_policy.dart';

class BookEncodingOptions {
  /// Переопределение глобального идентификатора документа (например: "UCM-AT-849201").
  final String? documentId;

  /// Название и версия программы-генератора (например: "ReUltimateCopyManager 1.0.0").
  final String? programUsed;

  /// Имя файла внутри архива для FB2.ZIP (например: "НазваниеКниги.fb2").
  final String? entryFilename;

  /// Политика именования медиа-ресурсов (по умолчанию: sequential — img_001.jpg, img_002.png...).
  final BookResourceNamingPolicy namingPolicy;

  /// Имя файла для обложки (по умолчанию: "cover").
  final String coverFilename;

  /// Форматировать ли XML с отступами.
  final bool pretty;

  const BookEncodingOptions({
    this.documentId,
    this.programUsed,
    this.entryFilename,
    this.namingPolicy = BookResourceNamingPolicy.sequential,
    this.coverFilename = 'cover',
    this.pretty = true,
  });
}
