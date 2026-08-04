String normalizeAiPlainText(String raw) {
  final text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
  if (text.isEmpty) return text;

  final normalizedLines = text.split('\n').map(_normalizeLine).toList();
  return normalizedLines
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

String _normalizeLine(String line) {
  var result = line.trimRight();
  result = result.replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s*'), '');
  result = result.replaceFirst(RegExp(r'^\s*>\s*'), '');
  result = result.replaceFirst(RegExp(r'^\s*[-*+]\s+'), '• ');
  result = result.replaceFirstMapped(
    RegExp(r'^\s*(\d+)\.\s+'),
    (match) => '${match.group(1)}. ',
  );
  result = result.replaceAllMapped(
    RegExp(r'\[(.*?)\]\((.*?)\)'),
    (match) => match.group(1) ?? '',
  );
  result = result.replaceAll(RegExp(r'(\*\*|__|~~|`)'), '');
  return result;
}
