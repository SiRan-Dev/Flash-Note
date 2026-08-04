import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class UpdateRelease {
  const UpdateRelease({
    required this.version,
    required this.tagName,
    required this.name,
    required this.body,
    required this.htmlUrl,
    required this.asset,
  });

  final String version;
  final String tagName;
  final String name;
  final String body;
  final String htmlUrl;
  final UpdateAsset? asset;
}

class UpdateAsset {
  const UpdateAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
  });

  final String name;
  final String downloadUrl;
  final int size;
}

class UpdateService {
  UpdateService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
              headers: const {
                'Accept': 'application/vnd.github+json',
                'User-Agent': 'FlashNote-Android-Updater',
              },
            ),
          );

  static const _channel = MethodChannel('com.echoran.flashnote/updater');
  static const _latestReleaseUrl =
      'https://api.github.com/repos/EchoRan6319/FlashNote/releases/latest';

  final Dio _dio;

  Future<UpdateRelease?> checkForUpdate() async {
    final info = await PackageInfo.fromPlatform();
    final response = await _dio.get<Map<String, dynamic>>(_latestReleaseUrl);
    final data = response.data;
    if (data == null || data['draft'] == true || data['prerelease'] == true) {
      return null;
    }

    final tagName = (data['tag_name'] as String? ?? '').trim();
    final releaseVersion = _normalizeVersion(tagName);
    if (releaseVersion.isEmpty ||
        _compareVersions(releaseVersion, info.version) <= 0) {
      return null;
    }

    final asset = await _selectBestApkAsset(data['assets']);
    return UpdateRelease(
      version: releaseVersion,
      tagName: tagName,
      name: data['name'] as String? ?? tagName,
      body: data['body'] as String? ?? '',
      htmlUrl: data['html_url'] as String? ?? '',
      asset: asset,
    );
  }

  Future<List<String>> supportedAbis() async {
    if (!Platform.isAndroid) return const [];
    final result = await _channel.invokeListMethod<String>('getSupportedAbis');
    return result ?? const [];
  }

  Future<bool> canRequestPackageInstalls() async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('canRequestPackageInstalls') ??
        false;
  }

  Future<void> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('openInstallPermissionSettings');
  }

  Future<String> downloadApk(
    UpdateAsset asset, {
    required void Function(int received, int total) onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final fileName = asset.name.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');
    final path = p.join(dir.path, fileName);
    await _dio.download(
      asset.downloadUrl,
      path,
      onReceiveProgress: onProgress,
      options: Options(headers: const {'Accept': 'application/octet-stream'}),
    );
    return path;
  }

  Future<bool> installApk(String path) async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('installApk', {'path': path}) ??
        false;
  }

  Future<UpdateAsset?> _selectBestApkAsset(Object? rawAssets) async {
    if (!Platform.isAndroid) return null;
    if (rawAssets is! List) return null;
    final assets =
        rawAssets
            .whereType<Map<String, dynamic>>()
            .map(_assetFromJson)
            .whereType<UpdateAsset>()
            .where(_isUserInstallableApk)
            .toList();
    if (assets.isEmpty) return null;

    final abis = await supportedAbis();
    final compatibleAssets =
        assets.where((asset) => _isCompatibleApkAsset(asset, abis)).toList();
    if (compatibleAssets.isEmpty) return null;

    compatibleAssets.sort(
      (a, b) => _assetScore(b, abis).compareTo(_assetScore(a, abis)),
    );
    return compatibleAssets.first;
  }

  UpdateAsset? _assetFromJson(Map<String, dynamic> json) {
    final name = json['name'] as String?;
    final url = json['browser_download_url'] as String?;
    if (name == null || url == null) return null;
    return UpdateAsset(
      name: name,
      downloadUrl: url,
      size: json['size'] as int? ?? 0,
    );
  }

  bool _isUserInstallableApk(UpdateAsset asset) {
    final name = asset.name.toLowerCase();
    return name.endsWith('.apk') &&
        !name.contains('debug') &&
        !name.contains('profile');
  }

  bool _isCompatibleApkAsset(UpdateAsset asset, List<String> supportedAbis) {
    final name = asset.name.toLowerCase();
    final matchedAbi = _assetAbiIndex(name, supportedAbis);
    if (matchedAbi != null) return true;
    return !_containsKnownAbiToken(name);
  }

  int _assetScore(UpdateAsset asset, List<String> supportedAbis) {
    final name = asset.name.toLowerCase();
    final matchedAbi = _assetAbiIndex(name, supportedAbis);
    if (matchedAbi != null) return 100 - matchedAbi;
    if (name.contains('universal')) return 30;
    if (name.contains('release')) return 20;
    return 0;
  }

  int? _assetAbiIndex(String name, List<String> supportedAbis) {
    final tokens = <String, List<String>>{
      'arm64-v8a': const ['arm64-v8a', 'arm64', 'aarch64'],
      'armeabi-v7a': const ['armeabi-v7a', 'armv7'],
      'x86_64': const ['x86_64', 'x64'],
      'x86': const ['x86'],
    };

    for (var i = 0; i < supportedAbis.length; i++) {
      final aliases = tokens[supportedAbis[i]] ?? const <String>[];
      if (aliases.any(name.contains)) return i;
    }

    return null;
  }

  bool _containsKnownAbiToken(String name) {
    const tokens = <List<String>>[
      ['arm64-v8a', 'arm64', 'aarch64'],
      ['armeabi-v7a', 'armv7'],
      ['x86_64', 'x64'],
      ['x86'],
    ];
    return tokens.expand((aliases) => aliases).any(name.contains);
  }

  String _normalizeVersion(String tagName) {
    final cleaned = tagName.trim().replaceFirst(RegExp('^[vV]'), '');
    final match = RegExp(r'\d+(?:\.\d+){0,2}(?:\+\d+)?').firstMatch(cleaned);
    return match?.group(0) ?? '';
  }

  int _compareVersions(String left, String right) {
    final leftParts = _versionParts(left);
    final rightParts = _versionParts(right);
    for (var i = 0; i < leftParts.length; i++) {
      final diff = leftParts[i].compareTo(rightParts[i]);
      if (diff != 0) return diff;
    }
    return 0;
  }

  List<int> _versionParts(String version) {
    final split = version.split('+');
    final base =
        split.first.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    while (base.length < 3) {
      base.add(0);
    }
    base.add(split.length > 1 ? int.tryParse(split[1]) ?? 0 : 0);
    return base.take(4).toList();
  }
}
