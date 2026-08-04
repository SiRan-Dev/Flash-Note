import 'package:flashnote/domain/entities/custom_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CustomSource', () {
    test('创建来源', () {
      final source = CustomSource(
        id: 1,
        name: '播客启发',
        icon: 'headphones',
        createdAt: DateTime(2026, 4, 30),
      );

      expect(source.name, '播客启发');
      expect(source.icon, 'headphones');
      expect(source.isBuiltIn, false);
    });

    test('内置来源标记', () {
      final source = CustomSource(
        id: 0,
        name: '突发奇想',
        icon: 'lightbulb',
        isBuiltIn: true,
        createdAt: DateTime(2026, 4, 30),
      );

      expect(source.isBuiltIn, true);
    });
  });
}
