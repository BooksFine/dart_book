/// Сигнатура функции для полностью кастомного генератора имен ресурсов.
typedef ResourceNameGenerator =
    String Function(String src, {required bool isInline, required int index});

/// Набор готовых и кастомных политик именования медиа-ресурсов (картинок, шрифтов, аудио).
abstract class BookResourceNamingPolicy {
  /// Сохраняет оригинальное имя файла из пути или URL ссылки (по умолчанию).
  /// Пример: `https://site.com/imgs/chapter1_pic.png` ➔ `chapter1_pic.png`
  static const BookResourceNamingPolicy preserve = _PreserveNamingPolicy();

  /// Генерирует простые порядковые имена файлов.
  /// Пример: `img_001.png`, `img_002.jpg`
  static const BookResourceNamingPolicy sequential = _SequentialNamingPolicy();

  /// Генерирует имена файлов на основе хэша источника.
  /// Пример: `img_a3f89b1c.png`
  static const BookResourceNamingPolicy hash = _HashNamingPolicy();

  /// Создает полностью кастомную политику именования на основе вашей функции.
  factory BookResourceNamingPolicy.custom(ResourceNameGenerator generator) =
      _CustomNamingPolicy;

  const BookResourceNamingPolicy();

  /// Генерирует имя или идентификатор ресурса.
  String generateName(String src, {required bool isInline, required int index});
}

class _PreserveNamingPolicy extends BookResourceNamingPolicy {
  const _PreserveNamingPolicy();

  @override
  String generateName(
    String src, {
    required bool isInline,
    required int index,
  }) {
    if (src.startsWith('data:')) {
      final ext = _getExtensionFromDataUri(src);
      return 'img_${index.toString().padLeft(3, '0')}.$ext';
    }
    final rawName = src.split('/').last.split('?').first;
    if (rawName.isNotEmpty && rawName.contains('.')) {
      return rawName;
    }
    final ext = _guessExtension(src);
    return 'img_${index.toString().padLeft(3, '0')}.$ext';
  }
}

class _SequentialNamingPolicy extends BookResourceNamingPolicy {
  const _SequentialNamingPolicy();

  @override
  String generateName(
    String src, {
    required bool isInline,
    required int index,
  }) {
    final ext = _guessExtension(src);
    final numStr = index.toString().padLeft(3, '0');
    return 'img_$numStr.$ext';
  }
}

class _HashNamingPolicy extends BookResourceNamingPolicy {
  const _HashNamingPolicy();

  @override
  String generateName(
    String src, {
    required bool isInline,
    required int index,
  }) {
    final ext = _guessExtension(src);
    final hashStr = src.hashCode.abs().toRadixString(16);
    return 'img_$hashStr.$ext';
  }
}

class _CustomNamingPolicy extends BookResourceNamingPolicy {
  final ResourceNameGenerator generator;

  const _CustomNamingPolicy(this.generator);

  @override
  String generateName(
    String src, {
    required bool isInline,
    required int index,
  }) {
    return generator(src, isInline: isInline, index: index);
  }
}

String _guessExtension(String src) {
  if (src.startsWith('data:')) {
    return _getExtensionFromDataUri(src);
  }
  final clean = src.split('?').first.split('#').first;
  if (clean.contains('.')) {
    final ext = clean.split('.').last.toLowerCase();
    if (ext.length <= 5 && RegExp(r'^[a-z0-9]+$').hasMatch(ext)) {
      return ext;
    }
  }
  return 'png';
}

String _getExtensionFromDataUri(String dataUri) {
  if (dataUri.contains('image/jpeg')) return 'jpg';
  if (dataUri.contains('image/png')) return 'png';
  if (dataUri.contains('image/gif')) return 'gif';
  if (dataUri.contains('image/svg')) return 'svg';
  if (dataUri.contains('image/webp')) return 'webp';
  if (dataUri.contains('image/avif')) return 'avif';
  if (dataUri.contains('image/jxl')) return 'jxl';
  return 'png';
}
