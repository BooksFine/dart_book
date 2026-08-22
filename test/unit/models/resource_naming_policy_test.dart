import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';

void main() {
  group('BookResourceNamingPolicy Tests', () {
    test('PreserveNamingPolicy handles URLs, data URIs and fallback extensions', () {
      const policy = BookResourceNamingPolicy.preserve;

      // Regular URL
      expect(
        policy.generateName('https://example.com/images/cat.png', isInline: false, index: 0),
        equals('cat.png'),
      );

      // URL with query parameters
      expect(
        policy.generateName('https://example.com/cover.jpg?token=123', isInline: false, index: 1),
        equals('cover.jpg'),
      );

      // Data URI
      expect(
        policy.generateName('data:image/jpeg;base64,/9j/4AAQSkZJRg...', isInline: false, index: 5),
        equals('img_005.jpg'),
      );


      // Data URI without subtype
      expect(
        policy.generateName('data:image/png;base64,iVBORw0KGgo...', isInline: true, index: 42),
        equals('img_042.png'),
      );

      // Source without extension
      expect(
        policy.generateName('blob:http://example.com/abcdef', isInline: false, index: 7),
        equals('img_007.png'),
      );
    });

    test('SequentialNamingPolicy generates padded index filenames', () {
      const policy = BookResourceNamingPolicy.sequential;

      expect(
        policy.generateName('https://site.com/foo.webp', isInline: false, index: 3),
        equals('img_003.webp'),
      );

      expect(
        policy.generateName('https://site.com/bar.jpg', isInline: true, index: 128),
        equals('img_128.jpg'),
      );
    });

    test('HashNamingPolicy generates hash based filenames', () {
      const policy = BookResourceNamingPolicy.hash;

      final name1 = policy.generateName('https://site.com/foo.png', isInline: false, index: 0);
      final name2 = policy.generateName('https://site.com/foo.png', isInline: false, index: 1);
      final name3 = policy.generateName('https://site.com/bar.png', isInline: false, index: 2);

      expect(name1, equals(name2), reason: 'Identical source should produce identical hash name');
      expect(name1, isNot(equals(name3)));
      expect(name1.endsWith('.png'), isTrue);
    });

    test('CustomNamingPolicy invokes user generator callback', () {
      final policy = BookResourceNamingPolicy.custom(
        (src, {required isInline, required index}) =>
            'custom_${isInline ? "inline" : "block"}_$index.bin',
      );

      expect(
        policy.generateName('anything', isInline: true, index: 1),
        equals('custom_inline_1.bin'),
      );
      expect(
        policy.generateName('anything', isInline: false, index: 2),
        equals('custom_block_2.bin'),
      );
    });
  });
}
