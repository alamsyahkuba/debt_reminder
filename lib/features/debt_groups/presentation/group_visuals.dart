import 'package:flutter/material.dart';

const List<String> groupColorChoices = <String>[
  '#00695C',
  '#1565C0',
  '#6A1B9A',
  '#C62828',
  '#EF6C00',
  '#5D4037',
];

const Map<String, String> groupIconLabels = <String, String>{
  'folder': 'Folder',
  'home': 'Rumah',
  'work': 'Kerja',
  'shopping_bag': 'Belanja',
  'directions_car': 'Kendaraan',
  'school': 'Sekolah',
  'health_and_safety': 'Kesehatan',
  'receipt': 'Tagihan',
  'savings': 'Tabungan',
  'handshake': 'Pinjaman',
  'family': 'Keluarga',
  'business_center': 'Usaha',
};

IconData groupIconForKey(String? key) {
  return switch (key) {
    'home' => Icons.home_outlined,
    'work' => Icons.work_outline,
    'shopping_bag' => Icons.shopping_bag_outlined,
    'directions_car' => Icons.directions_car_outlined,
    'school' => Icons.school_outlined,
    'health_and_safety' => Icons.health_and_safety_outlined,
    'receipt' => Icons.receipt_long_outlined,
    'savings' => Icons.savings_outlined,
    'handshake' => Icons.handshake_outlined,
    'family' => Icons.family_restroom_outlined,
    'business_center' => Icons.business_center_outlined,
    _ => Icons.folder_outlined,
  };
}

Color groupColorFromHex(String? value, Color fallback) {
  if (value == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
    return fallback;
  }

  return Color(int.parse(value.substring(1), radix: 16) | 0xFF000000);
}
