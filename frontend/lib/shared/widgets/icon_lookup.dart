import 'package:flutter/material.dart';

const Map<String, IconData> _iconMap = {
  'dashboard': Icons.space_dashboard_outlined,
  'business': Icons.business_outlined,
  'store': Icons.store_outlined,
  'people': Icons.people_outline,
  'shield': Icons.shield_outlined,
  'key': Icons.vpn_key_outlined,
  'history': Icons.history,
  'settings': Icons.settings_outlined,
  'palette': Icons.palette_outlined,
  'reports': Icons.bar_chart_outlined,
  'menu': Icons.menu,
  'logout': Icons.logout,
};

IconData iconFromName(String? name) {
  if (name == null) return Icons.circle_outlined;
  return _iconMap[name] ?? Icons.circle_outlined;
}
