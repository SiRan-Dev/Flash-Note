/// Information about a pre-migration database backup.
///
/// This is a plain Dart object so the UI can display it without importing
/// native-only libraries (dart:io), which keeps web builds working.
class MigrationBackupSummary {
  const MigrationBackupSummary({
    required this.path,
    required this.fromVersion,
    required this.toVersion,
  });

  /// Directory containing `flashnote.db` and its `-wal` / `-shm` sidecars.
  final String path;

  final int fromVersion;
  final int toVersion;
}

/// Tracks the most recent pre-migration backup created by the native
/// connection. The failure screen reads this to tell users where their data
/// was copied before the upgrade was attempted.
class MigrationBackupRegistry {
  MigrationBackupRegistry._();

  static MigrationBackupSummary? lastBackup;
}
