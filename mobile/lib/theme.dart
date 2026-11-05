import 'package:flutter/material.dart';

import 'l10n.dart';

/// Tiny Habits Cat colours: warm cream paper, sage green and soft ink.
class Palette {
  Palette._();
  static const cream = Color(0xFFFAF6EF);
  static const paper = Color(0xFFFFFFFF);
  static const sand = Color(0xFFF3EEE6);
  static const sage = Color(0xFF4F7A4A);
  static const sageSoft = Color(0xFFE4EEDD);
  static const ink = Color(0xFF2F2E2A);
  static const muted = Color(0xFF8A877F);
  static const line = Color(0xFFEDE7DC);

  // Soft tile colours for the round icons on Me and the task card.
  static const mint = Color(0xFFE3F0E1);
  static const rose = Color(0xFFFBE3E3);
  static const peach = Color(0xFFFCEBD9);
  static const sky = Color(0xFFE2ECF7);
  static const lilac = Color(0xFFECE6F6);
}

ThemeData tinyTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final cs = ColorScheme.fromSeed(
    seedColor: Palette.sage,
    brightness: b,
    primary: dark ? const Color(0xFF9CC293) : Palette.sage,
    surface: dark ? const Color(0xFF1E1F1C) : Palette.cream,
  );
  ButtonStyle flash(Color c) =>
      ButtonStyle(overlayColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.pressed) ? c : null));
  final press = cs.primary.withValues(alpha: 0.18);
  return ThemeData(
    colorScheme: cs,
    useMaterial3: true,
    scaffoldBackgroundColor: cs.surface,
    splashColor: press,
    highlightColor: cs.primary.withValues(alpha: 0.08),
    appBarTheme: AppBarTheme(backgroundColor: cs.surface, surfaceTintColor: Colors.transparent, centerTitle: false),
    cardTheme: CardThemeData(
      color: dark ? const Color(0xFF2A2B27) : Palette.paper,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? const Color(0xFF242521) : Palette.paper,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? const Color(0xFF242521) : Palette.paper,
      indicatorColor: cs.primary.withValues(alpha: 0.14),
      surfaceTintColor: Colors.transparent,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: dark ? const Color(0xFF2F3A2C) : Palette.sageSoft,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      labelStyle: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: flash(Colors.white.withValues(alpha: 0.28)).merge(
        FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(style: flash(press)),
    textButtonTheme: TextButtonThemeData(style: flash(press)),
    iconButtonTheme: IconButtonThemeData(style: flash(press)),
  );
}

/// The soft green pill used for Save, New and Record in sheet headers.
class PillButton extends StatelessWidget {
  const PillButton({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: cs.primary.withValues(alpha: 0.12),
        foregroundColor: cs.primary,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }
}

/// Sheet header from the wireframes: round close button, title, optional pill.
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.title, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          IconButton.filledTonal(
            tooltip: tr('Close', '关闭'),
            style: IconButton.styleFrom(backgroundColor: cs.onSurface.withValues(alpha: 0.05)),
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          ),
          if (action != null) PillButton(key: Key('sheet-$action'), label: action!, onPressed: onAction),
        ],
      ),
    );
  }
}

/// Opens a rounded bottom sheet that can grow tall, as every wireframe sheet does.
Future<T?> showTinySheet<T>(BuildContext context, WidgetBuilder builder, {bool tall = false}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: tall
            ? SizedBox(height: MediaQuery.sizeOf(ctx).height * 0.86, child: builder(ctx))
            : builder(ctx),
      ),
    );

/// A white rounded card with the wireframes' padding.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}
