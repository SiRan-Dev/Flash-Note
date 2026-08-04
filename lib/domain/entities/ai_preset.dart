class AiPreset {
  const AiPreset({
    required this.id,
    required this.name,
    required this.model,
    required this.baseUrl,
    this.isClaude = false,
  });

  final String id;
  final String name;
  final String model;
  final String baseUrl;
  final bool isClaude;

  static const openAiCompatibleId = 'openai_compatible';
  static const anthropicCompatibleId = 'anthropic_compatible';

  static const interfaceIds = [openAiCompatibleId, anthropicCompatibleId];

  static bool isInterfaceId(String id) {
    return interfaceIds.contains(id);
  }

  static String normalizeInterfaceId(String? id, {bool? legacyIsClaude}) {
    if (id == anthropicCompatibleId || id == 'claude') {
      return anthropicCompatibleId;
    }
    if (id == openAiCompatibleId) return openAiCompatibleId;
    if (id == 'custom' && legacyIsClaude == true) {
      return anthropicCompatibleId;
    }
    return openAiCompatibleId;
  }
}
