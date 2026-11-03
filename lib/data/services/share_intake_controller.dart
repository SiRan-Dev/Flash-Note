import 'package:flashnote/data/services/share_intake_service.dart';

/// 防止同一次分享被重复投递（例如 Activity 重建、冷启动 pending 重放）
/// 而产生多条记录。
class ShareIntakeController {
  ShareIntakeController(this._service);

  static const int _maxRememberedShares = 32;

  final ShareIntakeService _service;
  final Set<String> _recentShareIds = <String>{};

  Future<ShareIntakeResult> handle(
    IncomingShare share, {
    required String fallbackContent,
  }) {
    final shareId = share.shareId;
    if (shareId != null && shareId.isNotEmpty) {
      if (!_recentShareIds.add(shareId)) {
        return Future.value(const ShareIntakeResult.duplicate());
      }
      if (_recentShareIds.length > _maxRememberedShares) {
        _recentShareIds.remove(_recentShareIds.first);
      }
    }
    return _service.ingest(share, fallbackContent: fallbackContent);
  }
}
