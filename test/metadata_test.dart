import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';

void main() {
  group('BookMetadata Tests', () {
    test('BookMetadata initializes required and default fields correctly', () {
      const metadata = BookMetadata(
        id: 'meta-123',
        title: 'Sample Title',
        language: 'ru',
      );

      expect(metadata.id, equals('meta-123'));
      expect(metadata.title, equals('Sample Title'));
      expect(metadata.language, equals('ru'));
      expect(metadata.isFinished, isTrue);
      expect(metadata.textLength, isNull);
    });

    test('BookMetadata allows custom isFinished and textLength values', () {
      const metadata = BookMetadata(
        id: 'meta-456',
        title: 'Unfinished Book',
        language: 'en',
        isFinished: false,
        textLength: 150000,
      );

      expect(metadata.id, equals('meta-456'));
      expect(metadata.isFinished, isFalse);
      expect(metadata.textLength, equals(150000));
    });
  });
}
