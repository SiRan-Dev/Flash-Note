import 'dart:convert';

import 'package:uuid/uuid.dart';

/// 快照格式版本。WebDAV 同步与文件导出共用同一个版本号，也是支持的最高版本。
const int kSnapshotVersion = 7;

/// 在触碰本地数据库或附件文件之前，完整校验快照结构。
///
/// 校验失败时抛出 [FormatException]，调用方应直接中止导入 / 合并，
/// 保证本地数据保持不变。
void validateSnapshot(Map<String, dynamic> data) {
  final versionValue = data['version'];
  final version = versionValue == null ? 1 : _asInt(versionValue, 'version');
  if (version < 1 || version > kSnapshotVersion) {
    throw FormatException('不支持的数据版本: $version');
  }

  if (version >= 7) {
    _validateV7(data);
    return;
  }

  _validateLegacy(data, version);
}

/// v7：uuid 身份 + uuid 关系。
void _validateV7(Map<String, dynamic> data) {
  final deviceId = data['deviceId'];
  if (deviceId != null && deviceId is! String) {
    throw const FormatException('deviceId 字段格式错误');
  }

  final inspirationUuids = _validateUuidList(
    data,
    'inspirations',
    validate: (item) {
      _requireString(item, 'content', 'inspirations');
      _requireInt(item, 'createdAt', 'inspirations');
      _requireInt(item, 'updatedAt', 'inspirations');
      _requireBool(item, 'isPinned', 'inspirations');
      _optionalString(item, 'source', 'inspirations');
      _optionalString(item, 'aiAnalysis', 'inspirations');
      _optionalString(item, 'mindMapData', 'inspirations');
      _optionalInt(item, 'reviewedAt', 'inspirations');
      _optionalBool(item, 'needsFollowUp', 'inspirations');
      _validateTags(item, 'inspirations');
    },
  );

  final projectUuids = _validateUuidList(
    data,
    'projects',
    validate: (item) {
      _requireString(item, 'title', 'projects');
      _requireInt(item, 'createdAt', 'projects');
      _requireInt(item, 'updatedAt', 'projects');
      _optionalString(item, 'inspirationUuid', 'projects');
      _optionalString(item, 'description', 'projects');
      _optionalInt(item, 'progress', 'projects');
      _optionalString(item, 'status', 'projects');
      _optionalBool(item, 'isPinned', 'projects');
      final target = item['inspirationUuid'];
      if (target is String && !inspirationUuids.contains(target)) {
        throw FormatException('projects.inspirationUuid 指向不存在的 uuid: $target');
      }
    },
  );

  _validateUuidList(
    data,
    'tasks',
    validate: (item) {
      _requireString(item, 'projectUuid', 'tasks');
      _requireString(item, 'title', 'tasks');
      _requireInt(item, 'createdAt', 'tasks');
      _requireInt(item, 'updatedAt', 'tasks');
      _optionalBool(item, 'isCompleted', 'tasks');
      _optionalBool(item, 'isPinned', 'tasks');
      final target = item['projectUuid'] as String;
      if (!projectUuids.contains(target)) {
        throw FormatException('tasks.projectUuid 指向不存在的 uuid: $target');
      }
    },
  );

  _validateUuidList(
    data,
    'customSources',
    validate: (item) {
      _requireString(item, 'name', 'customSources');
      _requireString(item, 'icon', 'customSources');
      _requireInt(item, 'createdAt', 'customSources');
      _optionalInt(item, 'sortOrder', 'customSources');
      _optionalBool(item, 'isBuiltIn', 'customSources');
    },
  );

  _validateUuidList(
    data,
    'attachments',
    validate: (item) {
      final ownerType = item['ownerType'];
      if (ownerType != 'inspiration' && ownerType != 'project') {
        throw const FormatException('attachments.ownerType 字段格式错误');
      }
      _requireString(item, 'ownerUuid', 'attachments');
      _requireString(item, 'fileName', 'attachments');
      _requireString(item, 'mimeType', 'attachments');
      _requireInt(item, 'createdAt', 'attachments');
      _optionalInt(item, 'size', 'attachments');
      _optionalString(item, 'filePath', 'attachments');
      final contentBase64 = item['contentBase64'];
      if (contentBase64 != null) {
        if (contentBase64 is! String) {
          throw const FormatException('attachments.contentBase64 字段格式错误');
        }
        if (contentBase64.isNotEmpty) {
          try {
            base64Decode(contentBase64);
          } on FormatException {
            throw const FormatException(
              'attachments.contentBase64 不是合法的 Base64 数据',
            );
          }
        }
      }
      final target = item['ownerUuid'] as String;
      final ownerExists = ownerType == 'project'
          ? projectUuids.contains(target)
          : inspirationUuids.contains(target);
      if (!ownerExists) {
        throw FormatException('attachments.ownerUuid 指向不存在的 uuid: $target');
      }
    },
  );

  _validateUuidList(
    data,
    'chatMessages',
    validate: (item) {
      _requireString(item, 'inspirationUuid', 'chatMessages');
      _requireString(item, 'role', 'chatMessages');
      _requireString(item, 'content', 'chatMessages');
      _requireInt(item, 'createdAt', 'chatMessages');
      final target = item['inspirationUuid'] as String;
      if (!inspirationUuids.contains(target)) {
        throw FormatException(
          'chatMessages.inspirationUuid 指向不存在的 uuid: $target',
        );
      }
    },
  );

  _validateUuidList(
    data,
    'inspirationLinks',
    validate: (item) {
      _requireString(item, 'sourceUuid', 'inspirationLinks');
      _requireString(item, 'targetUuid', 'inspirationLinks');
      _requireString(item, 'linkType', 'inspirationLinks');
      _optionalString(item, 'relationLabel', 'inspirationLinks');
      final confidence = item['confidence'];
      if (confidence != null && confidence is! num) {
        throw const FormatException('inspirationLinks.confidence 字段格式错误');
      }
      _optionalBool(item, 'isAutoGenerated', 'inspirationLinks');
      _requireInt(item, 'createdAt', 'inspirationLinks');
      final source = item['sourceUuid'] as String;
      final target = item['targetUuid'] as String;
      if (!inspirationUuids.contains(source) ||
          !inspirationUuids.contains(target)) {
        throw FormatException(
          'inspirationLinks 关系指向不存在的 uuid: $source -> $target',
        );
      }
    },
  );

  _validateUuidList(
    data,
    'clusters',
    validate: (item) {
      _requireString(item, 'name', 'clusters');
      _optionalString(item, 'description', 'clusters');
      _requireInt(item, 'createdAt', 'clusters');
      _requireInt(item, 'updatedAt', 'clusters');
    },
  );

  _validateUuidList(
    data,
    'reports',
    validate: (item) {
      _requireString(item, 'type', 'reports');
      _requireString(item, 'content', 'reports');
      _optionalString(item, 'model', 'reports');
      _requireInt(item, 'createdAt', 'reports');
      _requireInt(item, 'updatedAt', 'reports');
    },
  );

  _forEachItem(data, 'deletedRecords', (item) {
    final entityType = item['entityType'];
    if (entityType is! String || !_entityTypes.contains(entityType)) {
      throw const FormatException('deletedRecords.entityType 字段格式错误');
    }
    final entityUuid = item['entityUuid'];
    if (entityUuid is! String || !_isUuid(entityUuid)) {
      throw const FormatException('deletedRecords.entityUuid 字段格式错误');
    }
    _requireInt(item, 'deletedAt', 'deletedRecords');
    _optionalBool(item, 'legacy', 'deletedRecords');
    _optionalInt(item, 'entityId', 'deletedRecords');
  });

  _validateAiSettings(data['aiSettings']);
  _validateWebDavSettings(data['webdavSettings']);
  _validateGraphLayouts(data['graphLayouts']);
}

const List<String> _entityTypes = [
  'inspirations',
  'projects',
  'tasks',
  'attachments',
  'reports',
  'inspirationLinks',
  'clusters',
  'customSources',
  'chatMessages',
];

Set<String> _validateUuidList(
  Map<String, dynamic> data,
  String key, {
  required void Function(Map<String, dynamic> item) validate,
}) {
  final seen = <String>{};
  _forEachItem(data, key, (item) {
    final uuid = item['uuid'];
    if (uuid is! String || uuid.isEmpty) {
      throw FormatException('$key.uuid 字段缺失或格式错误');
    }
    if (!_isUuid(uuid)) {
      throw FormatException('$key.uuid 不是合法 UUID: $uuid');
    }
    if (!seen.add(uuid)) {
      throw FormatException('$key 存在重复 uuid: $uuid');
    }
    final legacyId = item['legacyId'];
    if (legacyId != null && legacyId is! int) {
      throw FormatException('$key.legacyId 字段格式错误');
    }
    validate(item);
  });
  return seen;
}

void _validateTags(Map<String, dynamic> item, String context) {
  final tags = item['tags'];
  if (tags != null && tags is! List && tags is! String) {
    throw FormatException('$context.tags 字段格式错误');
  }
}

bool _isUuid(String value) {
  return Uuid.isValidUUID(fromString: value);
}

/// v1-v6：沿用旧结构校验，允许旧快照先校验再升级。
void _validateLegacy(Map<String, dynamic> data, int version) {
  _forEachItem(data, 'inspirations', required: true, (item) {
    _requireInt(item, 'id', 'inspirations');
    _requireString(item, 'content', 'inspirations');
    _requireInt(item, 'createdAt', 'inspirations');
    _requireInt(item, 'updatedAt', 'inspirations');
    _requireBool(item, 'isPinned', 'inspirations');
    _optionalString(item, 'source', 'inspirations');
    _optionalString(item, 'aiAnalysis', 'inspirations');
    _optionalString(item, 'mindMapData', 'inspirations');
    _optionalInt(item, 'reviewedAt', 'inspirations');
    _optionalBool(item, 'needsFollowUp', 'inspirations');
    _validateTags(item, 'inspirations');
  });

  _forEachItem(data, 'projects', required: true, (item) {
    _requireInt(item, 'id', 'projects');
    _requireString(item, 'title', 'projects');
    _requireInt(item, 'createdAt', 'projects');
    _requireInt(item, 'updatedAt', 'projects');
    _optionalInt(item, 'inspirationId', 'projects');
    _optionalString(item, 'description', 'projects');
    _optionalInt(item, 'progress', 'projects');
    _optionalString(item, 'status', 'projects');
    _optionalBool(item, 'isPinned', 'projects');
  });

  _forEachItem(data, 'tasks', required: true, (item) {
    _requireInt(item, 'id', 'tasks');
    _requireInt(item, 'projectId', 'tasks');
    _requireString(item, 'title', 'tasks');
    _requireInt(item, 'createdAt', 'tasks');
    _requireInt(item, 'updatedAt', 'tasks');
    _optionalBool(item, 'isCompleted', 'tasks');
    _optionalBool(item, 'isPinned', 'tasks');
  });

  _forEachItem(data, 'customSources', required: true, (item) {
    _requireInt(item, 'id', 'customSources');
    _requireString(item, 'name', 'customSources');
    _requireString(item, 'icon', 'customSources');
    _requireInt(item, 'createdAt', 'customSources');
    _optionalInt(item, 'sortOrder', 'customSources');
    _optionalBool(item, 'isBuiltIn', 'customSources');
  });

  if (version >= 2) {
    _forEachItem(data, 'attachments', (item) {
      _requireInt(item, 'id', 'attachments');
      _requireString(item, 'ownerType', 'attachments');
      _requireInt(item, 'ownerId', 'attachments');
      _requireString(item, 'fileName', 'attachments');
      _requireString(item, 'mimeType', 'attachments');
      _requireInt(item, 'createdAt', 'attachments');
      _optionalInt(item, 'size', 'attachments');
      _optionalString(item, 'filePath', 'attachments');
      final contentBase64 = item['contentBase64'];
      if (contentBase64 != null) {
        if (contentBase64 is! String) {
          throw const FormatException('attachments.contentBase64 字段格式错误');
        }
        if (contentBase64.isNotEmpty) {
          try {
            base64Decode(contentBase64);
          } on FormatException {
            throw const FormatException(
              'attachments.contentBase64 不是合法的 Base64 数据',
            );
          }
        }
      }
    });
  }

  if (version >= 3) {
    _forEachItem(data, 'chatMessages', (item) {
      _requireInt(item, 'id', 'chatMessages');
      _requireInt(item, 'inspirationId', 'chatMessages');
      _requireString(item, 'role', 'chatMessages');
      _requireString(item, 'content', 'chatMessages');
      _requireInt(item, 'createdAt', 'chatMessages');
    });

    _forEachItem(data, 'inspirationLinks', (item) {
      _requireInt(item, 'id', 'inspirationLinks');
      _requireInt(item, 'sourceId', 'inspirationLinks');
      _requireInt(item, 'targetId', 'inspirationLinks');
      _requireString(item, 'linkType', 'inspirationLinks');
      _optionalString(item, 'relationLabel', 'inspirationLinks');
      final confidence = item['confidence'];
      if (confidence != null && confidence is! num) {
        throw const FormatException('inspirationLinks.confidence 字段格式错误');
      }
      _optionalBool(item, 'isAutoGenerated', 'inspirationLinks');
      _requireInt(item, 'createdAt', 'inspirationLinks');
    });

    _forEachItem(data, 'clusters', (item) {
      _requireInt(item, 'id', 'clusters');
      _requireString(item, 'name', 'clusters');
      _optionalString(item, 'description', 'clusters');
      _requireInt(item, 'createdAt', 'clusters');
      _requireInt(item, 'updatedAt', 'clusters');
    });
  }

  if (version >= 4) {
    _forEachItem(data, 'deletedRecords', (item) {
      _optionalInt(item, 'id', 'deletedRecords');
      _requireString(item, 'entityType', 'deletedRecords');
      _requireInt(item, 'entityId', 'deletedRecords');
      _requireInt(item, 'deletedAt', 'deletedRecords');
    });
  }

  if (version >= 5) {
    _forEachItem(data, 'reports', (item) {
      _requireInt(item, 'id', 'reports');
      _requireString(item, 'type', 'reports');
      _requireString(item, 'content', 'reports');
      _optionalString(item, 'model', 'reports');
      _requireInt(item, 'createdAt', 'reports');
      _requireInt(item, 'updatedAt', 'reports');
    });
  }

  _validateAiSettings(data['aiSettings']);
  _validateWebDavSettings(data['webdavSettings']);
  _validateGraphLayouts(data['graphLayouts']);
}

void _forEachItem(
  Map<String, dynamic> data,
  String key,
  void Function(Map<String, dynamic> item) validate, {
  bool required = false,
}) {
  final value = data[key];
  if (value == null) {
    if (required) throw FormatException('缺少 $key 字段');
    return;
  }
  if (value is! List) throw FormatException('$key 字段格式错误');
  for (final raw in value) {
    final item = _asMap(raw, key);
    validate(item);
  }
}

Map<String, dynamic> _asMap(Object? value, String context) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('$context 条目格式错误');
  }
  return value;
}

int _asInt(Object? value, String field) {
  if (value is! int) throw FormatException('$field 字段格式错误');
  return value;
}

int _requireInt(Map<String, dynamic> item, String field, String context) {
  final value = item[field];
  if (value is! int) throw FormatException('$context.$field 字段格式错误');
  return value;
}

void _requireString(Map<String, dynamic> item, String field, String context) {
  if (item[field] is! String) throw FormatException('$context.$field 字段格式错误');
}

void _requireBool(Map<String, dynamic> item, String field, String context) {
  if (item[field] is! bool) throw FormatException('$context.$field 字段格式错误');
}

void _optionalString(Map<String, dynamic> item, String field, String context) {
  final value = item[field];
  if (value != null && value is! String) {
    throw FormatException('$context.$field 字段格式错误');
  }
}

void _optionalInt(Map<String, dynamic> item, String field, String context) {
  final value = item[field];
  if (value != null && value is! int) {
    throw FormatException('$context.$field 字段格式错误');
  }
}

void _optionalBool(Map<String, dynamic> item, String field, String context) {
  final value = item[field];
  if (value != null && value is! bool) {
    throw FormatException('$context.$field 字段格式错误');
  }
}

void _validateAiSettings(Object? value) {
  if (value == null) return;
  if (value is! Map<String, dynamic>) {
    throw const FormatException('aiSettings 字段格式错误');
  }
  _optionalString(value, 'selectedInterfaceId', 'aiSettings');
  _optionalString(value, 'selectedPresetId', 'aiSettings');
  _optionalString(value, 'customBaseUrl', 'aiSettings');
  _optionalString(value, 'customModel', 'aiSettings');
  _optionalBool(value, 'customIsClaude', 'aiSettings');

  final interfaces = value['interfaces'];
  if (interfaces != null) {
    if (interfaces is! Map) {
      throw const FormatException('aiSettings.interfaces 字段格式错误');
    }
    for (final entry in interfaces.entries) {
      final config = entry.value;
      if (config is! Map<String, dynamic>) {
        throw FormatException('aiSettings.interfaces.${entry.key} 格式错误');
      }
      _optionalString(config, 'baseUrl', 'aiSettings.interfaces.${entry.key}');
      _optionalString(config, 'model', 'aiSettings.interfaces.${entry.key}');
      _optionalString(config, 'apiKey', 'aiSettings.interfaces.${entry.key}');
    }
  }

  final apiKeys = value['apiKeys'];
  if (apiKeys != null) {
    if (apiKeys is! Map) {
      throw const FormatException('aiSettings.apiKeys 字段格式错误');
    }
    for (final entry in apiKeys.entries) {
      if (entry.value is! String) {
        throw FormatException('aiSettings.apiKeys.${entry.key} 字段格式错误');
      }
    }
  }
}

void _validateWebDavSettings(Object? value) {
  if (value == null) return;
  if (value is! Map<String, dynamic>) {
    throw const FormatException('webdavSettings 字段格式错误');
  }
  _optionalString(value, 'serverUrl', 'webdavSettings');
  _optionalString(value, 'remotePath', 'webdavSettings');
  _optionalBool(value, 'autoSync', 'webdavSettings');
  _optionalString(value, 'syncMode', 'webdavSettings');
  _optionalInt(value, 'syncIntervalMinutes', 'webdavSettings');
  _optionalBool(value, 'syncAttachments', 'webdavSettings');
  _optionalInt(value, 'lastSyncTime', 'webdavSettings');
  _optionalString(value, 'username', 'webdavSettings');
  _optionalString(value, 'password', 'webdavSettings');
}

void _validateGraphLayouts(Object? value) {
  if (value == null) return;
  if (value is! Map) {
    throw const FormatException('graphLayouts 字段格式错误');
  }
  for (final entry in value.entries) {
    if (entry.value != null && entry.value is! String) {
      throw FormatException('graphLayouts.${entry.key} 字段格式错误');
    }
  }
}
