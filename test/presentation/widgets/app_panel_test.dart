import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/widgets/app_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('AppPanel 渲染内容并带有装饰容器', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(const AppPanel(child: Text('panel body'))),
    );

    expect(find.text('panel body'), findsOneWidget);
    expect(find.byType(DecoratedBox), findsWidgets);
  });

  testWidgets('AppMetricChip 显示图标和标签', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        const AppMetricChip(icon: Icons.hub_outlined, label: '12 nodes'),
      ),
    );

    expect(find.byIcon(Icons.hub_outlined), findsOneWidget);
    expect(find.text('12 nodes'), findsOneWidget);
  });
}
