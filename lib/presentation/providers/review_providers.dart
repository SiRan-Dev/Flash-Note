import 'package:flashnote/data/services/notification_service.dart';
import 'package:flashnote/domain/entities/inspiration.dart';
import 'package:flashnote/presentation/providers/inspiration_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 通知服务
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// 未回顾灵感数量
final unreviewedCountProvider = FutureProvider<int>((ref) {
  final repo = ref.watch(inspirationRepositoryProvider);
  return repo.getUnreviewedCount();
});

/// 随机未回顾灵感（今日回顾用）
final randomUnreviewedProvider = FutureProvider<List<Inspiration>>((ref) {
  final repo = ref.watch(inspirationRepositoryProvider);
  return repo.getRandomUnreviewed();
});

/// 需要跟进的灵感
final followUpInspirationsProvider = FutureProvider<List<Inspiration>>((ref) {
  final repo = ref.watch(inspirationRepositoryProvider);
  return repo.getInspirationsNeedingFollowUp();
});

/// 本周灵感（用于生成周报）
final weeklyInspirationsProvider = FutureProvider<List<Inspiration>>((ref) {
  final repo = ref.watch(inspirationRepositoryProvider);
  final weekAgo = DateTime.now().subtract(const Duration(days: 7));
  return repo.getInspirationsSince(weekAgo);
});

/// 本月灵感（用于生成月报）
final monthlyInspirationsProvider = FutureProvider<List<Inspiration>>((ref) {
  final repo = ref.watch(inspirationRepositoryProvider);
  final now = DateTime.now();
  final monthAgo = _safeMonthAgo(now);
  return repo.getInspirationsSince(monthAgo);
});

DateTime _safeMonthAgo(DateTime now) {
  final prevMonth = now.month - 1;
  final year = prevMonth < 1 ? now.year - 1 : now.year;
  final month = prevMonth < 1 ? 12 : prevMonth;
  final lastDay = DateTime(year, month + 1, 0).day;
  final day = now.day > lastDay ? lastDay : now.day;
  return DateTime(year, month, day);
}
