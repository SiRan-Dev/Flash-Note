import 'package:flutter/widgets.dart';

/// 非 Android 平台没有系统分享入口，直接透传子树。
class ShareIntakeListener extends StatelessWidget {
  const ShareIntakeListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
