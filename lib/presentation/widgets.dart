import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/format.dart';
import '../domain/ledger.dart';
import '../domain/models.dart';
import 'cubits.dart';
import 'theme.dart';

/// Below this width the sidebar turns into a bottom bar.
const double kWideLayout = 760;

void openDialog(BuildContext context, Widget dialog) {
  showDialog<void>(context: context, builder: (_) => dialog);
}

void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text, textAlign: TextAlign.center)));
}

Color mutedColor(BuildContext context) => LedgerColors.of(context).mut;

/// Scrollable page with a title row and evenly spaced sections.
class PageFrame extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? breadcrumb;
  final List<Widget> actions;
  final List<Widget> children;

  const PageFrame({
    super.key,
    required this.title,
    this.subtitle,
    this.breadcrumb,
    this.actions = const [],
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = LedgerColors.of(context);
    final wide = MediaQuery.sizeOf(context).width >= kWideLayout;
    return SingleChildScrollView(
      padding: wide
          ? const EdgeInsets.fromLTRB(0, 20, 16, 32)
          : const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 14,
            runSpacing: 14,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (breadcrumb != null) ...[
                    DefaultTextStyle.merge(
                      style: TextStyle(fontSize: 13, color: c.mut),
                      child: breadcrumb!,
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                          fontSize: wide ? 26 : 22, letterSpacing: -0.26)),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!, style: TextStyle(color: c.mut)),
                  ],
                ],
              ),
              Wrap(spacing: 10, runSpacing: 10, children: actions),
            ],
          ),
          for (final child in children) ...[const SizedBox(height: 20), child],
        ],
      ),
    );
  }
}

/// White card with a thin border. Used for every section of a page.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  const Panel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 18),
      this.radius = 12});

  @override
  Widget build(BuildContext context) {
    final c = LedgerColors.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.panel,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

class SectionCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  const SectionCard({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasHead = title != null || trailing != null;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasHead)
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                if (title != null)
                  Text(title!, style: theme.textTheme.titleMedium),
                if (trailing != null) CompactButtons(child: trailing!),
              ],
            ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                style: TextStyle(fontSize: 13, color: mutedColor(context))),
          ],
          if (hasHead || subtitle != null) const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// Lays stat cards out in 4, 2 or 1 columns depending on the width.
class StatRow extends StatelessWidget {
  final List<Widget> children;
  const StatRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 16.0;
      final cols = c.maxWidth >= 4 * 180 + 3 * gap
          ? 4
          : (c.maxWidth >= 2 * 150 + gap ? 2 : 1);
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final x in children) SizedBox(width: w, child: x)],
      );
    });
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool negative;
  const StatCard(this.label, this.value, {super.key, this.negative = false});

  @override
  Widget build(BuildContext context) {
    final c = LedgerColors.of(context);
    return Panel(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: c.mut)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontFamily: headFont,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontFeatures: tabularFigures,
                color: negative ? c.neg : c.fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Side by side when wide, stacked when narrow.
class TwoColumns extends StatelessWidget {
  final Widget left;
  final Widget right;
  const TwoColumns({super.key, required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 2 * 340 + 16) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 16),
            Expanded(child: right),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [left, const SizedBox(height: 16), right],
      );
    });
  }
}

/// Makes the buttons inside smaller, like the prototype's table and list
/// buttons.
class CompactButtons extends StatelessWidget {
  final Widget child;
  const CompactButtons({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = LedgerColors.of(context);
    final touch = theme.platform == TargetPlatform.android ||
        theme.platform == TargetPlatform.iOS;
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, touch ? 40 : 32)),
      padding:
          const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
      textStyle: const WidgetStatePropertyAll(TextStyle(
          fontFamily: bodyFont, fontSize: 13, fontWeight: FontWeight.w600)),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Theme(
      data: theme.copyWith(
        filledButtonTheme: FilledButtonThemeData(
            style: style.merge(theme.filledButtonTheme.style)),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: style
                .copyWith(foregroundColor: WidgetStatePropertyAll(c.accentInk))
                .merge(theme.outlinedButtonTheme.style)),
        textButtonTheme: TextButtonThemeData(
            style: style.merge(theme.textButtonTheme.style)),
      ),
      child: child,
    );
  }
}

/// Filled when it is the thing to do next, outlined otherwise.
class ActionButton extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback? onPressed;
  const ActionButton(this.label,
      {super.key, this.primary = false, required this.onPressed});

  @override
  Widget build(BuildContext context) => primary
      ? FilledButton(onPressed: onPressed, child: Text(label))
      : OutlinedButton(onPressed: onPressed, child: Text(label));
}

/// A balance. Negative is red with a minus sign, positive is the accent
/// colour, both bold. Zero is plain.
class MoneyText extends StatelessWidget {
  final int amount;
  const MoneyText(this.amount, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = LedgerColors.of(context);
    return Text(
      formatSigned(amount),
      style: TextStyle(
        fontFeatures: tabularFigures,
        fontWeight: amount != 0 ? FontWeight.w700 : null,
        color: amount < 0 ? c.neg : (amount > 0 ? c.accentInk : null),
      ),
    );
  }
}

/// Plain number cell for tables. A dash stands for zero.
class NumText extends StatelessWidget {
  final int amount;
  final bool negativeStyle;
  const NumText(this.amount, {super.key, this.negativeStyle = false});

  @override
  Widget build(BuildContext context) {
    final red = negativeStyle && amount != 0;
    return Text(
      formatCell(amount),
      style: TextStyle(
        fontFeatures: tabularFigures,
        fontWeight: red ? FontWeight.w700 : null,
        color: red || amount < 0 ? LedgerColors.of(context).neg : null,
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color? background;
  final Color? foreground;
  const Pill(this.text, {super.key, this.background, this.foreground});

  @override
  Widget build(BuildContext context) {
    final c = LedgerColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: background ?? c.soft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: foreground ?? c.fg,
        ),
      ),
    );
  }
}

/// Needs to add / Advance held / Settled. Says the state in words, not only
/// colour.
class StatusChip extends StatelessWidget {
  final int balance;
  const StatusChip(this.balance, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = LedgerColors.of(context);
    if (balance < 0) {
      return Pill('Needs to add', background: c.negSoft, foreground: c.negInk);
    }
    if (balance > 0) {
      return Pill('Advance held',
          background: c.accentSoft, foreground: c.accentInk);
    }
    return const Pill('Settled');
  }
}

class LinkText extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  const LinkText(this.text, {super.key, required this.onTap});

  @override
  State<LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<LinkText> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = LedgerColors.of(context);
    return Semantics(
      link: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Text(
            widget.text,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: c.accentInk,
              decoration:
                  _hover ? TextDecoration.underline : TextDecoration.none,
              decorationColor: c.accentInk,
            ),
          ),
        ),
      ),
    );
  }
}

class PartnerLink extends StatelessWidget {
  final Ledger ledger;
  final int partnerId;
  const PartnerLink(this.ledger, this.partnerId, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = ledger.partner(partnerId);
    if (p == null) return const Text('(removed)');
    final showTag = p.isCompany && p.name.trim().toLowerCase() != 'company';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: LinkText(p.name,
              onTap: () => context.read<NavCubit>().go(AppRoute.partner(p.id))),
        ),
        if (showTag) ...[const SizedBox(width: 6), const Pill('Company')],
      ],
    );
  }
}

class SiteLink extends StatelessWidget {
  final Ledger ledger;
  final int siteId;
  const SiteLink(this.ledger, this.siteId, {super.key});

  @override
  Widget build(BuildContext context) {
    return LinkText(ledger.siteName(siteId),
        onTap: () => context.read<NavCubit>().go(AppRoute.site(siteId)));
  }
}

class Col {
  final String label;
  final bool numeric;
  const Col(this.label, {this.numeric = false});
}

/// A table that fills the available width and scrolls sideways when the
/// window is too narrow. Header on a grey band, a line under each row, and
/// [footer] as a bold totals row.
class LedgerTable extends StatelessWidget {
  final List<Col> columns;
  final List<List<Widget>> rows;
  final List<Widget>? footer;

  const LedgerTable({
    super.key,
    required this.columns,
    required this.rows,
    this.footer,
  });

  Widget _cell(Widget child, Col col, EdgeInsets padding) => Padding(
        padding: padding,
        child: Align(
          alignment: col.numeric ? Alignment.centerRight : Alignment.centerLeft,
          widthFactor: 1,
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = LedgerColors.of(context);
    const head = EdgeInsets.symmetric(horizontal: 12, vertical: 9);
    const body = EdgeInsets.symmetric(horizontal: 12, vertical: 11);
    final headStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      color: c.mut,
    );
    return LayoutBuilder(builder: (context, box) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: box.maxWidth),
            child: CompactButtons(
              child: DefaultTextStyle.merge(
                style: const TextStyle(fontFeatures: tabularFigures),
                child: Table(
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  // No flex: spare width is shared evenly by every column,
                  // so the table fits exactly (flex columns can overshoot).
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        color: c.soft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      children: [
                        for (final col in columns)
                          _cell(
                              Text(col.label.toUpperCase(),
                                  style: headStyle, softWrap: false),
                              col,
                              head),
                      ],
                    ),
                    for (final r in rows)
                      TableRow(
                        decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: c.line))),
                        children: [
                          for (var i = 0; i < columns.length; i++)
                            _cell(i < r.length ? r[i] : const SizedBox(),
                                columns[i], body),
                        ],
                      ),
                    if (footer != null)
                      TableRow(children: [
                        for (var i = 0; i < columns.length; i++)
                          _cell(
                              DefaultTextStyle.merge(
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                                child: i < footer!.length
                                    ? footer![i]
                                    : const SizedBox(),
                              ),
                              columns[i],
                              body),
                      ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class EmptyBox extends StatelessWidget {
  final String text;
  final List<Widget> actions;
  const EmptyBox(this.text, {super.key, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final c = LedgerColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: CustomPaint(
        painter: _DashedBorder(color: c.line, radius: 10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
          child: Column(
            children: [
              Text(text,
                  textAlign: TextAlign.center, style: TextStyle(color: c.mut)),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: actions),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  final Color color;
  final double radius;
  const _DashedBorder({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
          RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    const dash = 4.0, gap = 3.0;
    for (final PathMetric m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += dash + gap) {
        canvas.drawPath(m.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) =>
      old.color != color || old.radius != radius;
}

/// One line in a list: a partner with a site under it, an amount, an action.
class BalanceLine extends StatelessWidget {
  final Widget title;
  final String subtitle;
  final int amount;
  final Widget? action;
  const BalanceLine({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final c = LedgerColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                Text(subtitle, style: TextStyle(fontSize: 12, color: c.mut)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          MoneyText(amount),
          if (action != null) ...[
            const SizedBox(width: 12),
            CompactButtons(child: action!),
          ],
        ],
      ),
    );
  }
}

/// Underlined tabs, as on the site page.
class UnderlineTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  const UnderlineTabs(
      {super.key,
      required this.labels,
      required this.selected,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = LedgerColors.of(context);
    return Container(
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Wrap(
        spacing: 2,
        children: [
          for (var i = 0; i < labels.length; i++)
            Semantics(
              selected: i == selected,
              button: true,
              child: InkWell(
                onTap: () => onSelect(i),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        width: 2,
                        color: i == selected ? c.accent : Colors.transparent,
                      ),
                    ),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontWeight:
                          i == selected ? FontWeight.w600 : FontWeight.w500,
                      color: i == selected ? c.accentInk : c.mut,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A form field with its label above it and an optional hint below.
class LabeledField extends StatelessWidget {
  final String label;
  final String? hint;
  final Widget child;
  const LabeledField(
      {super.key, required this.label, required this.child, this.hint});

  @override
  Widget build(BuildContext context) {
    final c = LedgerColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        child,
        if (hint != null) ...[
          const SizedBox(height: 5),
          Text(hint!, style: TextStyle(fontSize: 12, color: c.mut)),
        ],
      ],
    );
  }
}

String kindLabel(Entry e) {
  switch (e.kind) {
    case EntryKind.incomeExpense:
      final hasIncome = e.income != 0;
      final hasExpense = e.expense != 0;
      if (hasIncome && hasExpense) return 'Income + expense';
      return hasIncome ? 'Income' : 'Expense';
    case EntryKind.addMoney:
      return 'Add money';
    case EntryKind.transferOut:
      return 'Transfer out';
    case EntryKind.transferIn:
      return 'Transfer in';
    case EntryKind.replacement:
      return 'Replacement';
  }
}

String entryDetail(Ledger l, Entry e) {
  final parts = <String>[];
  final pid = e.partnerId;
  final other = e.otherSiteId;
  if (e.kind == EntryKind.addMoney && pid != null) {
    parts.add(l.partnerName(pid));
  } else if (e.kind == EntryKind.transferOut && pid != null && other != null) {
    parts.add('${l.partnerName(pid)} to ${l.siteName(other)}');
  } else if (e.kind == EntryKind.transferIn && pid != null && other != null) {
    parts.add('${l.partnerName(pid)} from ${l.siteName(other)}');
  }
  if (e.note.isNotEmpty) parts.add(e.note);
  return parts.isEmpty ? '—' : parts.join(' · ');
}

/// Details text with Reversal / Reversed tags.
class EntryDetailCell extends StatelessWidget {
  final Ledger ledger;
  final Entry entry;
  const EntryDetailCell(this.ledger, this.entry, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(entryDetail(ledger, entry),
                overflow: TextOverflow.ellipsis),
          ),
        ),
        if (entry.isReversal) ...[
          const SizedBox(width: 6),
          const Pill('Reversal'),
        ],
        if (entry.isReversed) ...[
          const SizedBox(width: 6),
          const Pill('Reversed'),
        ],
      ],
    );
  }
}
