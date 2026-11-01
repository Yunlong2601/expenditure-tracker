import 'package:flutter/material.dart';

/// Quick-pick categories for a student in Singapore, most used first.
const quickCategories = <(String, IconData)>[
  ('Food & drink', Icons.ramen_dining),
  ('Bubble tea', Icons.emoji_food_beverage),
  ('Snacks', Icons.cookie_outlined),
  ('Transport', Icons.directions_bus),
  ('Stationery', Icons.edit_note),
  ('Shopping', Icons.shopping_bag),
  ('Fun', Icons.celebration),
  ('Gifts', Icons.card_giftcard),
  ('Other', Icons.more_horiz),
];

IconData iconFor(String? category) {
  final c = (category ?? '').toLowerCase();
  for (final (name, icon) in quickCategories) {
    if (c == name.toLowerCase()) return icon;
  }
  if (c.contains('tea')) return Icons.emoji_food_beverage;
  if (c.contains('food') || c.contains('drink') || c.contains('meal')) return Icons.ramen_dining;
  if (c.contains('snack')) return Icons.cookie_outlined;
  if (c.contains('transport') || c.contains('grab') || c.contains('taxi')) return Icons.directions_bus;
  if (c.contains('grocer')) return Icons.local_grocery_store;
  if (c.contains('bill') || c.contains('utilit')) return Icons.receipt_long;
  if (c.contains('health')) return Icons.medical_services;
  if (c.contains('gift')) return Icons.card_giftcard;
  if (c.contains('book') || c.contains('station')) return Icons.edit_note;
  return Icons.payments_outlined;
}
