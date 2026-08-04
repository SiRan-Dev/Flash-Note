import 'package:flashnote/core/utils/ai_text_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizeAiPlainText removes obvious markdown markers', () {
    const raw = '''
### 分析结果
- **时间模式**：白天为主
1. **主题**：Flash Note
[参考链接](https://example.com)
''';

    final normalized = normalizeAiPlainText(raw);

    expect(normalized, isNot(contains('###')));
    expect(normalized, isNot(contains('**')));
    expect(normalized, isNot(contains('[参考链接](')));
    expect(normalized, contains('分析结果'));
    expect(normalized, contains('• 时间模式：白天为主'));
    expect(normalized, contains('1. 主题：Flash Note'));
    expect(normalized, contains('参考链接'));
  });
}
