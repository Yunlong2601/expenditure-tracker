import 'package:flutter/material.dart';

/// Quick-pick categories, in the order most people in Singapore spend.
const quickCategories = <(String, IconData)>[
  ('Food & drink', Icons.ramen_dining),
  ('Transport', Icons.directions_bus),
  ('Groceries', Icons.local_grocery_store),
  ('Shopping', Icons.shopping_bag),
  ('Bills', Icons.receipt_long),
  ('Fun', Icons.celebration),
  ('Health', Icons.medical_services),
  ('Other', Icons.more_horiz),
];

IconData iconFor(String? category) {
  final c = (category ?? '').toLowerCase();
  for (final (name, icon) in quickCategories) {
    if (c == name.toLowerCase()) return icon;
  }
  if (c.contains('food') || c.contains('drink') || c.contains('meal')) return Icons.ramen_dining;
  if (c.contains('transport') || c.contains('grab') || c.contains('taxi')) return Icons.directions_bus;
  if (c.contains('grocer')) return Icons.local_grocery_store;
  if (c.contains('bill') || c.contains('utilit')) return Icons.receipt_long;
  return Icons.payments_outlined;
}
