/// Базовое исключение для ошибок работы с форматом EPUB.
class EpubException implements Exception {
  final String message;
  const EpubException(this.message);

  @override
  String toString() => 'EpubException: $message';
}

/// Исключение, выбрасываемое при обнаружении зашифрованных (DRM) ресурсов.
class EpubEncryptedResourceException extends EpubException {
  final List<String> encryptedPaths;

  EpubEncryptedResourceException(this.encryptedPaths)
      : super('EPUB содержит зашифрованные (DRM) ресурсы: ${encryptedPaths.join(', ')}');
}

/// Исключение, выбрасываемое при нарушении структуры OCF или OPF пакета.
class EpubInvalidPackageException extends EpubException {
  const EpubInvalidPackageException(super.message);
}
