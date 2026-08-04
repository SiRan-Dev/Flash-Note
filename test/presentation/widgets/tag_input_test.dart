import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/widgets/tag_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('输入标签并回车添加', (tester) async {
    List<String> tags = <String>[];
    await tester.pumpWidget(_buildTestApp(
      StatefulBuilder(
        builder: (context, setState) => TagInput(
          tags: tags,
          onChanged: (newTags) => setState(() => tags = newTags),
        ),
      ),
    ));

    await tester.enterText(find.byType(TextField), '新标签');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('新标签'), findsOneWidget);
  });

  testWidgets('已有标签显示为 Chip', (tester) async {
    await tester.pumpWidget(_buildTestApp(
      TagInput(
        tags: const ['tagA', 'tagB'],
        onChanged: (_) {},
      ),
    ));

    expect(find.text('tagA'), findsOneWidget);
    expect(find.text('tagB'), findsOneWidget);
  });

  testWidgets('点击删除按钮移除标签', (tester) async {
    List<String> tags = <String>['toDelete'];
    await tester.pumpWidget(_buildTestApp(
      StatefulBuilder(
        builder: (context, setState) => TagInput(
          tags: tags,
          onChanged: (newTags) => setState(() => tags = newTags),
        ),
      ),
    ));

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(tags, isEmpty);
  });
}
