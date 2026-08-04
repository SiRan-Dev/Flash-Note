import 'package:flashnote/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';

/// 将来源 key 映射为本地化显示名称
class SourceMapper {
  SourceMapper._();

  static String displayName(BuildContext context, String sourceKey) {
    final l10n = AppLocalizations.of(context);
    switch (sourceKey) {
      case 'flash':
        return l10n.sourceFlash;
      case 'reading':
        return l10n.sourceReading;
      case 'dialogue':
        return l10n.sourceDialogue;
      case 'observation':
        return l10n.sourceObservation;
      case 'problem':
        return l10n.sourceProblem;
      default:
        return sourceKey;
    }
  }
}
