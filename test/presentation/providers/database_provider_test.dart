import 'package:drift/native.dart';
import 'package:flashnote/data/datasources/local/app_database.dart';
import 'package:flashnote/presentation/providers/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('databaseProvider 失效后会重新初始化数据库', () async {
    var unavailable = true;
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) {
          if (unavailable) throw StateError('database unavailable');
          return AppDatabase.forTesting(NativeDatabase.memory());
        }),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(databaseInitializationProvider.future),
      throwsA(predicate((error) => '$error'.contains('database unavailable'))),
    );

    unavailable = false;
    container.invalidate(databaseProvider);

    final db = await container.read(databaseInitializationProvider.future);
    await db.customSelect('SELECT 1').get();
    await db.close();
  });
}
