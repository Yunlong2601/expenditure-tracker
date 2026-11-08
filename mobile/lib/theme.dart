import 'package:flutter/material.dart';

import 'l10n.dart';

/// Purrpose colours: warm cream paper, sage green and soft ink.
class Palette {
  Palette._();
  static const cream = Color(0xFFFAF6EF);
  static const paper = Color(0xFFFFFFFF);
  static const sand = Color(0xFFF3EEE6);
  // Dark enough for green text on the soft green chips (4.5:1).
  static const sage = Color(0xFF456E41);
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

/// The app's two looks: Cosy (cream and pastel, a busy room) and Calm
/// (deeper colours, a plainer room and a smaller cat) for older students
/// who find Cosy too young.
class TinyLook extends ThemeExtension<TinyLook> {
  const TinyLook({this.calm = false});
  final bool calm;

  @override
  TinyLook copyWith({bool? calm}) => TinyLook(calm: calm ?? this.calm);

  @override
  TinyLook lerp(TinyLook? other, double t) => t < 0.5 ? this : (other ?? this);
}

/// Calm's colours, light and dark. Each pair keeps text at 4.5:1.
class CalmPalette {
  CalmPalette._();
  static const teal = Color(0xFF2E6B5E);
  static const tealNight = Color(0xFF8FCBBB);
  static const surface = Color(0xFFF5F6F4);
  static const surfaceNight = Color(0xFF17191B);
  static const card = Color(0xFFFFFFFF);
  static const cardNight = Color(0xFF222527);
  static const soft = Color(0xFFDDEBE6);
  static const softNight = Color(0xFF1F3631);
  static const sand = Color(0xFFECEDEA);
  static const sandNight = Color(0xFF2A2E31);
  static const muted = Color(0xFF5F6368);
  static const mutedNight = Color(0xFFA0A4A8);
}

/// Colours that change between light and dark mode, and Cosy and Calm.
extension TinyColors on BuildContext {
  bool get _dark => Theme.of(this).brightness == Brightness.dark;

  /// The Calm look is on.
  bool get calm => Theme.of(this).extension<TinyLook>()?.calm ?? false;

  /// Grey for quieter text. Light mode's is dark enough to read on sand
  /// (4.5:1), dark mode's light enough to read on the dark cards.
  Color get muted => calm
      ? (_dark ? CalmPalette.mutedNight : CalmPalette.muted)
      : (_dark ? const Color(0xFFA29E96) : const Color(0xFF6B6861));

  /// The soft box behind grouped rows; a dark one at night, so light text
  /// stays readable on it.
  Color get sand => calm
      ? (_dark ? CalmPalette.sandNight : CalmPalette.sand)
      : (_dark ? const Color(0xFF30312C) : Palette.sand);

  /// The app's green for words and icons: the lighter one at night, since
  /// [Palette.sage] is too dark to read on the dark cards.
  Color get green => Theme.of(this).colorScheme.primary;

  /// The soft green behind a picked day or a finished step; a deep green
  /// at night, so the green words on it stay readable.
  Color get greenSoft => calm
      ? (_dark ? CalmPalette.softNight : CalmPalette.soft)
      : (_dark ? const Color(0xFF2F3A2C) : Palette.sageSoft);
}

/// True when the phone's text is at 150% or more, where a row that puts a
/// title and a label side by side should stack them instead.
bool bigText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(20) >= 30;

ThemeData tinyTheme(Brightness b, {bool calm = false}) {
  final dark = b == Brightness.dark;
  final cs = ColorScheme.fromSeed(
    seedColor: calm ? CalmPalette.teal : Palette.sage,
    brightness: b,
    primary: calm
        ? (dark ? CalmPalette.tealNight : CalmPalette.teal)
        : (dark ? const Color(0xFF9CC293) : Palette.sage),
    surface: calm
        ? (dark ? CalmPalette.surfaceNight : CalmPalette.surface)
        : (dark ? const Color(0xFF1E1F1C) : Palette.cream),
  );
  ButtonStyle flash(Color c) =>
      ButtonStyle(overlayColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.pressed) ? c : null));
  final press = cs.primary.withValues(alpha: 0.18);
  final muted = calm
      ? (dark ? CalmPalette.mutedNight : CalmPalette.muted)
      : (dark ? const Color(0xFFA29E96) : const Color(0xFF6B6861));
  final soft = calm
      ? (dark ? CalmPalette.softNight : CalmPalette.soft)
      : (dark ? const Color(0xFF2F3A2C) : Palette.sageSoft);
  final card = calm
      ? (dark ? CalmPalette.cardNight : CalmPalette.card)
      : (dark ? const Color(0xFF2A2B27) : Palette.paper);
  final base = ThemeData(
    colorScheme: cs,
    useMaterial3: true,
    extensions: [TinyLook(calm: calm)],
    scaffoldBackgroundColor: cs.surface,
    splashColor: press,
    highlightColor: cs.primary.withValues(alpha: 0.08),
    appBarTheme: AppBarTheme(backgroundColor: cs.surface, surfaceTintColor: Colors.transparent, centerTitle: false),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: calm
          ? (dark ? const Color(0xFF1E2123) : CalmPalette.card)
          : (dark ? const Color(0xFF242521) : Palette.paper),
      showDragHandle: true,
      dragHandleColor: dark ? const Color(0xFF4A4A44) : const Color(0xFFE6E1D8),
      dragHandleSize: const Size(36, 4),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    // The tab bar from the wireframes: thin grey icons, a soft green pill and
    // a green label on the open tab.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: soft,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 70,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 13,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? cs.primary : muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(size: 24, color: s.contains(WidgetState.selected) ? cs.primary : muted),
      ),
    ),
    // iOS-style switches: a white knob on a soft grey or green track.
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? cs.primary
            : (dark ? const Color(0xFF3A3B36) : const Color(0xFFE9E5DE)),
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      // An empty icon keeps the knob full size when off, as on iPhone.
      thumbIcon: const WidgetStatePropertyAll(Icon(null)),
    ),
    // Back buttons are the thin chevron from the wireframes.
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (_) => const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: soft,
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
  return base.copyWith(
    textTheme: _type(base.textTheme),
    primaryTextTheme: _type(base.primaryTextTheme),
  );
}

/// Type as on iPhone: no extra space between letters (Material's defaults
/// spread them out), big headings a touch tighter, and the small sizes one
/// step up so grey hints stay easy to read.
///
/// Chinese is set the way Chinese apps set it: characters never pulled
/// closer together, and body text with a little more room between lines.
TextTheme _type(TextTheme t) {
  TextStyle? s(TextStyle? x, {double? size, double spacing = 0}) => x?.copyWith(
    letterSpacing: zh ? 0 : spacing,
    fontSize: size ?? x.fontSize,
  );
  TextStyle? body(TextStyle? x, {double? size}) =>
      zh ? s(x, size: size)?.copyWith(height: 1.5) : s(x, size: size);
  return t.copyWith(
    displayLarge: s(t.displayLarge, spacing: -0.5),
    displayMedium: s(t.displayMedium, spacing: -0.5),
    displaySmall: s(t.displaySmall, spacing: -0.4),
    headlineLarge: s(t.headlineLarge, spacing: -0.4),
    headlineMedium: s(t.headlineMedium, spacing: -0.3),
    headlineSmall: s(t.headlineSmall, spacing: -0.2),
    titleLarge: s(t.titleLarge, spacing: -0.2),
    titleMedium: s(t.titleMedium),
    titleSmall: s(t.titleSmall),
    bodyLarge: body(t.bodyLarge),
    bodyMedium: body(t.bodyMedium, size: 15),
    bodySmall: body(t.bodySmall, size: 13),
    labelLarge: s(t.labelLarge),
    labelMedium: s(t.labelMedium, size: 13),
    labelSmall: s(t.labelSmall, size: 12),
  );
}

/// The soft green pill used for Save, New and Record in sheet headers.
class PillButton extends StatelessWidget {
  const PillButton({super.key, required this.label, required this.onPressed, this.dense = false});
  final String label;
  final VoidCallback? onPressed;

  /// A smaller pill, like Today on the Dashboard's week card.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: cs.primary.withValues(alpha: 0.12),
        foregroundColor: cs.primary,
        // Still the soft green pill when there's nothing to save yet.
        disabledBackgroundColor: cs.primary.withValues(alpha: 0.08),
        disabledForegroundColor: cs.primary.withValues(alpha: 0.5),
        padding: dense
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
            : const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        minimumSize: dense ? const Size(0, 30) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(dense ? 12 : 16)),
        textStyle: TextStyle(fontSize: dense ? 14 : 16, fontWeight: FontWeight.w700),
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
    final close = IconButton.filledTonal(
      tooltip: tr('Close', '关闭'),
      style: IconButton.styleFrom(backgroundColor: cs.onSurface.withValues(alpha: 0.05)),
      icon: const Icon(Icons.close),
      onPressed: () => Navigator.of(context).maybePop(),
    );
    final heading = Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w700));
    final pill = action == null ? null : PillButton(key: Key('sheet-$action'), label: action!, onPressed: onAction);
    // With very big text the title gets its own line under the buttons, as
    // iOS does with large titles, so neither is squeezed.
    if (bigText(context)) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                close,
                const SizedBox(width: 10),
                if (pill != null)
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: FittedBox(fit: BoxFit.scaleDown, child: pill),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            heading,
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          close,
          const SizedBox(width: 10),
          Expanded(child: heading),
          ?pill,
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

/// Chips on one line, left-aligned, that scroll sideways when they don't
/// all fit, so no chip is left alone on a line of its own. The edge with
/// more chips past it fades out, so a cut chip reads as "scroll for more".
class ChipRow extends StatefulWidget {
  const ChipRow({super.key, required this.children, this.spacing = 8});
  final List<Widget> children;
  final double spacing;

  @override
  State<ChipRow> createState() => _ChipRowState();
}

class _ChipRowState extends State<ChipRow> {
  var _before = false, _after = false;

  // Its size known (first layout) or its place changed (scrolled).
  bool _seen(Notification n) {
    final m = switch (n) {
      ScrollMetricsNotification(:final metrics) => metrics,
      ScrollNotification(:final metrics) => metrics,
      _ => null,
    };
    if (m == null) return false;
    final before = m.extentBefore > 1, after = m.extentAfter > 1;
    if (before != _before || after != _after) {
      setState(() {
        _before = before;
        _after = after;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: NotificationListener<Notification>(
        onNotification: _seen,
        // Always masked (fully shown when nothing is past an edge), so the
        // row keeps its place when a fade comes or goes.
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (r) {
            final f = r.width > 0 ? (28 / r.width).clamp(0.0, 0.5) : 0.0;
            return LinearGradient(
              colors: [
                _before ? Colors.transparent : Colors.black,
                Colors.black,
                Colors.black,
                _after ? Colors.transparent : Colors.black,
              ],
              stops: [0, f, 1 - f, 1],
            ).createShader(r);
          },
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(spacing: widget.spacing, children: widget.children),
          ),
        ),
      ),
    );
  }
}
