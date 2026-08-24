import 'package:shared_preferences/shared_preferences.dart';

/// 存储用户个人背景（职业、主要做什么等），用于全局 AI 对话的上下文。
/// 非敏感信息，仅使用 SharedPreferences。
class UserProfileStorage {
  static const _backgroundKey = 'user_background';

  Future<String> background() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_backgroundKey) ?? '';
  }

  Future<void> setBackground(String background) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backgroundKey, background);
  }
}
