import 'package:flashnote/domain/entities/inspiration.dart';
import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flashnote/presentation/widgets/inspiration_card.dart';
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
  final now = DateTime(2026, 4, 30, 12);
  final testInspiration = Inspiration(
    id: 1,
    content: 'Test inspiration content for card display.',
    source: 'reading',
    tags: ['Flutter', 'dev'],
    createdAt: now,
    updatedAt: now,
  );

  testWidgets('灵感卡片显示内容摘要', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        InspirationCard(inspiration: testInspiration, onTap: () {}),
      ),
    );
    expect(
      find.text('Test inspiration content for card display.'),
      findsOneWidget,
    );
  });

  testWidgets('灵感卡片显示来源', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        InspirationCard(inspiration: testInspiration, onTap: () {}),
      ),
    );
    expect(find.text('Reading'), findsOneWidget);
  });

  testWidgets('灵感卡片显示标签', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        InspirationCard(inspiration: testInspiration, onTap: () {}),
      ),
    );
    expect(find.text('Flutter'), findsOneWidget);
    expect(find.text('dev'), findsOneWidget);
  });

  testWidgets('置顶灵感显示置顶图标', (tester) async {
    final pinned = testInspiration.copyWith(isPinned: true);
    await tester.pumpWidget(
      _buildTestApp(InspirationCard(inspiration: pinned, onTap: () {})),
    );
    expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);
  });

  testWidgets('无来源时不显示来源 Chip', (tester) async {
    final noSource = testInspiration.copyWith(source: null);
    await tester.pumpWidget(
      _buildTestApp(InspirationCard(inspiration: noSource, onTap: () {})),
    );
    expect(find.text('Reading'), findsNothing);
  });
}
