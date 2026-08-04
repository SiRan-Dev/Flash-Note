import 'package:flutter/material.dart';

/// Material icon code name → IconData mapping (shared across the app)
const sourceMaterialIcons = <String, IconData>{
  'lightbulb': Icons.lightbulb,
  'menu_book': Icons.menu_book,
  'forum': Icons.forum,
  'search': Icons.search,
  'flag': Icons.flag,
  'star': Icons.star,
  'book': Icons.book,
  'code': Icons.code,
  'camera': Icons.camera_alt,
  'music_note': Icons.music_note,
  'palette': Icons.palette,
  'science': Icons.science,
  'psychology': Icons.psychology,
  'auto_awesome': Icons.auto_awesome,
  'chat': Icons.chat,
  'bookmark': Icons.bookmark,
  'work': Icons.work,
  'school': Icons.school,
  'favorite': Icons.favorite,
  'bolt': Icons.bolt,
  'eco': Icons.eco,
  'rocket_launch': Icons.rocket_launch,
  'edit_note': Icons.edit_note,
  'gps_fixed': Icons.gps_fixed,
  'home': Icons.home,
  'public': Icons.public,
  'schedule': Icons.schedule,
  'sports_esports': Icons.sports_esports,
  'directions_run': Icons.directions_run,
  'restaurant': Icons.restaurant,
  'coffee': Icons.coffee,
};

/// Build an icon widget from a source icon string.
/// If the string matches a Material icon key, renders an Icon widget.
/// Otherwise, renders the string as text (supports emoji).
Widget buildSourceIcon(String icon, {double size = 24}) {
  final materialIcon = sourceMaterialIcons[icon];
  if (materialIcon != null) {
    return Icon(materialIcon, size: size);
  }
  return Text(icon, style: TextStyle(fontSize: size));
}
