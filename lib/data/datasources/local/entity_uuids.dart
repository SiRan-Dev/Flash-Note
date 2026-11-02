import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

/// 确定性 UUID 的固定命名空间。
///
/// 一旦发布就不能再改：两端设备只有使用完全相同的命名空间，才能为同一份
/// 逻辑数据算出相同的 UUID，从而在合并时识别为同一条记录。
const String flashNoteUuidNamespace = '5f1e2b3c-4a5d-4e6f-8a9b-0c1d2e3f4a5b';

/// 新建实体时使用的随机 UUID（v4）。
String newUuidV4() => _uuid.v4();

/// 报告按 type 确定性生成 UUID。
///
/// 同一 type 在两端离线生成时会得到同一个 UUID；历史数据里若存在同 type 的
/// 重复行，[discriminator] 用行 id 区分，避免唯一索引冲突。
String deterministicReportUuid(String type, {Object? discriminator}) {
  final suffix = discriminator == null ? '' : ':$discriminator';
  return _uuid.v5(flashNoteUuidNamespace, 'flashnote:report:$type$suffix');
}

/// 内置来源按 name 确定性生成 UUID，自定义来源仍用随机 v4。
String deterministicBuiltInSourceUuid(String name, {Object? discriminator}) {
  final suffix = discriminator == null ? '' : ':$discriminator';
  return _uuid.v5(flashNoteUuidNamespace, 'flashnote:source:$name$suffix');
}

/// 旧版本墓碑（只有自增 id、没有实体 UUID）的确定性映射。
///
/// 同一份 v11 数据在任意设备上算出的结果一致，迁移后不会因为 id 不同而
/// 把同一条删除记录当成两条。
String legacyTombstoneUuid(String entityType, int entityId) {
  return _uuid.v5(flashNoteUuidNamespace, 'legacy-tomb:$entityType:$entityId');
}
