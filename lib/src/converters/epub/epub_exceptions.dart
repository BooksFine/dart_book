import '../../models/exceptions.dart';

/// Базовое исключение для ошибок работы с форматом EPUB.
class EpubException extends BookException {
  const EpubException(super.message);
}

/// Исключение, выбрасываемое при обнаружении зашифрованных (DRM) ресурсов.
class EpubEncryptedResourceException extends EpubException {
  final List<String> encryptedPaths;

  EpubEncryptedResourceException(this.encryptedPaths)
    : super(
        'EPUB содержит зашифрованные (DRM) ресурсы: ${encryptedPaths.join(', ')}',
      );
}

/// Исключение, выбрасываемое при нарушении структуры OCF или OPF пакета.
class EpubInvalidPackageException extends EpubException {
  const EpubInvalidPackageException(super.message);
}
