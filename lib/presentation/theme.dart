import 'package:flutter/material.dart';

/// Colour tokens from the HTML prototype. One blue accent; red is kept for
/// negative balances.
@immutable
class LedgerColors extends ThemeExtension<LedgerColors> {
  final Color bg;
  final Color panel;
  final Color line;
  final Color fg;
  final Color mut;
  final Color accent;
  final Color accentFg;
  final Color accentSoft;
  final Color accentInk;
  final Color neg;
  final Color negSoft;
  final Color negInk;
  final Color soft;
  final Color field;
  final Color overlay;

  const LedgerColors({
    required this.bg,
    required this.panel,
    required this.line,
    required this.fg,
    required this.mut,
    required this.accent,
    required this.accentFg,
    required this.accentSoft,
    required this.accentInk,
    required this.neg,
    required this.negSoft,
    required this.negInk,
    required this.soft,
    required this.field,
    required this.overlay,
  });

  static const light = LedgerColors(
    bg: Color(0xFFF4F6F9),
    panel: Color(0xFFFFFFFF),
    line: Color(0xFFE1E6ED),
    fg: Color(0xFF14181F),
    mut: Color(0xFF55606E),
    accent: Color(0xFF1A56B0),
    accentFg: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFE8F0FC),
    accentInk: Color(0xFF123E86),
    neg: Color(0xFFB42318),
    negSoft: Color(0xFFFEF0EE),
    negInk: Color(0xFF9A1B10),
    soft: Color(0xFFEEF1F5),
    field: Color(0xFFFFFFFF),
    overlay: Color(0x8C0F141C),
  );

  static const dark = LedgerColors(
    bg: Color(0xFF11151B),
    panel: Color(0xFF1A2029),
    line: Color(0xFF2B3440),
    fg: Color(0xFFE8ECF1),
    mut: Color(0xFF9BA7B5),
    accent: Color(0xFF7FB0F5),
    accentFg: Color(0xFF0D1622),
    accentSoft: Color(0xFF1C2D46),
    accentInk: Color(0xFFA9CBFA),
    neg: Color(0xFFFF8F80),
    negSoft: Color(0xFF3A1F1C),
    negInk: Color(0xFFFFB1A6),
    soft: Color(0xFF242C36),
    field: Color(0xFF141920),
    overlay: Color(0x99000000),
  );

  static LedgerColors of(BuildContext context) =>
      Theme.of(context).extension<LedgerColors>()!;

  @override
  LedgerColors copyWith() => this;

  @override
  LedgerColors lerp(LedgerColors? other, double t) {
    if (other == null) return this;
    Color m(Color a, Color b) => Color.lerp(a, b, t)!;
    return LedgerColors(
      bg: m(bg, other.bg),
      panel: m(panel, other.panel),
      line: m(line, other.line),
      fg: m(fg, other.fg),
      mut: m(mut, other.mut),
      accent: m(accent, other.accent),
      accentFg: m(accentFg, other.accentFg),
      accentSoft: m(accentSoft, other.accentSoft),
      accentInk: m(accentInk, other.accentInk),
      neg: m(neg, other.neg),
      negSoft: m(negSoft, other.negSoft),
      negInk: m(negInk, other.negInk),
      soft: m(soft, other.soft),
      field: m(field, other.field),
      overlay: m(overlay, other.overlay),
    );
  }
}

/// Body text font.
const bodyFont = 'Inter';

/// Headings and big numbers.
const headFont = 'SpaceGrotesk';

const tabularFigures = [FontFeature.tabularFigures()];

ThemeData buildLedgerTheme(Brightness brightness) {
  final c =
      brightness == Brightness.dark ? LedgerColors.dark : LedgerColors.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.accent,
    onPrimary: c.accentFg,
    primaryContainer: c.accentSoft,
    onPrimaryContainer: c.accentInk,
    secondary: c.accent,
    onSecondary: c.accentFg,
    secondaryContainer: c.accentSoft,
    onSecondaryContainer: c.accentInk,
    error: c.neg,
    onError: c.panel,
    errorContainer: c.negSoft,
    onErrorContainer: c.negInk,
    surface: c.panel,
    onSurface: c.fg,
    onSurfaceVariant: c.mut,
    surfaceContainerLowest: c.panel,
    surfaceContainerLow: c.panel,
    surfaceContainer: c.panel,
    surfaceContainerHigh: c.panel,
    surfaceContainerHighest: c.soft,
    outline: c.line,
    outlineVariant: c.line,
    inverseSurface: c.fg,
    onInverseSurface: c.bg,
    surfaceTint: Colors.transparent,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: bodyFont,
  );
  final t = base.textTheme;
  TextStyle head(TextStyle? s, double size) =>
      (s ?? const TextStyle()).copyWith(
          fontFamily: headFont,
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: c.fg);

  const btnShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)));
  const btnText = TextStyle(
      fontFamily: bodyFont, fontSize: 14, fontWeight: FontWeight.w600);
  const btnPadding = EdgeInsets.symmetric(horizontal: 14);
  const btnSize = Size(0, 40);

  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.panel,
    dividerColor: c.line,
    extensions: [c],
    textTheme: t
        .copyWith(
          headlineSmall: head(t.headlineSmall, 26),
          titleLarge: head(t.titleLarge, 20),
          titleMedium: head(t.titleMedium, 16),
          bodyLarge: t.bodyLarge?.copyWith(fontSize: 15),
          bodyMedium: t.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
          bodySmall: t.bodySmall?.copyWith(fontSize: 13, color: c.mut),
        )
        .apply(bodyColor: c.fg, displayColor: c.fg),
    dividerTheme: DividerThemeData(color: c.line, space: 1, thickness: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: c.accentFg,
        minimumSize: btnSize,
        padding: btnPadding,
        shape: btnShape,
        textStyle: btnText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: c.panel,
        foregroundColor: c.fg,
        side: BorderSide(color: c.line),
        minimumSize: btnSize,
        padding: btnPadding,
        shape: btnShape,
        textStyle: btnText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.accentInk,
        minimumSize: btnSize,
        padding: btnPadding,
        shape: btnShape,
        textStyle: btnText,
      ),
    ),
    // Text fields use 15 px text, as in the prototype.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.field,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 14),
      hintStyle: TextStyle(color: c.mut, fontSize: 15),
      border: border(c.line),
      enabledBorder: border(c.line),
      disabledBorder: border(c.line),
      focusedBorder: border(c.accent, 2),
      errorBorder: border(c.neg),
      focusedErrorBorder: border(c.neg, 2),
      suffixStyle: TextStyle(color: c.mut),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: BorderSide(color: c.mut, width: 1.5),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.panel,
      surfaceTintColor: Colors.transparent,
      barrierColor: c.overlay,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.line),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.fg,
      contentTextStyle: TextStyle(
          fontFamily: bodyFont,
          color: c.bg,
          fontSize: 13,
          fontWeight: FontWeight.w600),
      shape: const StadiumBorder(),
      width: 360,
      elevation: 2,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.panel,
      indicatorColor: c.accentSoft,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStatePropertyAll(TextStyle(
          fontFamily: bodyFont,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: c.fg)),
    ),
    progressIndicatorTheme:
        ProgressIndicatorThemeData(color: c.accent, linearTrackColor: c.soft),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: c.panel,
      surfaceTintColor: Colors.transparent,
      headerHeadlineStyle: head(t.headlineSmall, 24),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.panel,
      surfaceTintColor: Colors.transparent,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(c.line),
    ),
  );
}
