import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Signals from the OS / HyperOS fair-memory mechanism.
///
/// When the system reports memory pressure (TRIM/KILL broadcast), the app
/// clears its image cache and notifies this provider so screens can flush
/// unsaved drafts to persistent storage before the process is reclaimed.
class MemoryPressureState {
  const MemoryPressureState({this.lastTrimAt, this.lastWasKill = false});

  final DateTime? lastTrimAt;
  final bool lastWasKill;

  MemoryPressureState copyWith({DateTime? lastTrimAt, bool? lastWasKill}) =>
      MemoryPressureState(
        lastTrimAt: lastTrimAt ?? this.lastTrimAt,
        lastWasKill: lastWasKill ?? this.lastWasKill,
      );
}

final memoryPressureProvider =
    NotifierProvider<MemoryPressureNotifier, MemoryPressureState>(
  MemoryPressureNotifier.new,
);

class MemoryPressureNotifier extends Notifier<MemoryPressureState> {
  @override
  MemoryPressureState build() => const MemoryPressureState();

  void notifyTrim({bool isKill = false}) {
    state = state.copyWith(lastTrimAt: DateTime.now(), lastWasKill: isKill);
  }
}
