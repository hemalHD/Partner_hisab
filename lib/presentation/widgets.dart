import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/format.dart';
import '../domain/ledger.dart';
import '../domain/models.dart';
import 'cubits.dart';

const _tabular = [FontFeature.tabularFigures()];

void openDialog(BuildContext context, Widget dialog) {
  showDialog<void>(context: context, builder: (_) => dialog);
}

void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

Color mutedColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant;

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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (breadcrumb != null) ...[
                        breadcrumb!,
                        const SizedBox(height: 6),
                      ],
                      Text(title,
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(subtitle!,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: mutedColor(context))),
                      ],
                    ],
                  ),
                  Wrap(spacing: 8, runSpacing: 8, children: actions),
                ],
              ),
              for (final c in children) ...[const SizedBox(height: 16), c],
            ],
          ),
        ),
      ),
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
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null || trailing != null)
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (title != null)
                    Text(title!,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  if (trailing != null) trailing!,
                ],
              ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: mutedColor(context))),
            ],
            if (title != null || trailing != null || subtitle != null)
              const SizedBox(height: 10),
            child,
          ],
        ),
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
      final cols = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 480 ? 2 : 1);
      final w = (c.maxWidth - 12 * (cols - 1)) / cols;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
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
    final theme = Theme.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: mutedColor(context))),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: _tabular,
                color: negative ? theme.colorScheme.error : null,
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
      if (c.maxWidth >= 900) {
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

/// A balance. Negative is red with a minus sign, positive is the accent colour.
class MoneyText extends StatelessWidget {
  final int amount;
  final bool bold;
  const MoneyText(this.amount, {super.key, this.bold = true});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      formatSigned(amount),
      style: TextStyle(
        fontFeatures: _tabular,
        fontWeight: bold ? FontWeight.w700 : null,
        color: amount < 0 ? cs.error : (amount > 0 ? cs.primary : null),
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
        fontFeatures: _tabular,
        fontWeight: red ? FontWeight.w700 : null,
        color: red ? Theme.of(context).colorScheme.error : null,
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: background ?? cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: foreground ?? cs.onSurfaceVariant,
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
    final cs = Theme.of(context).colorScheme;
    if (balance < 0) {
      return Pill('Needs to add',
          background: cs.errorContainer, foreground: cs.onErrorContainer);
    }
    if (balance > 0) {
      return Pill('Advance held',
          background: cs.primaryContainer, foreground: cs.onPrimaryContainer);
    }
    return const Pill('Settled');
  }
}

class LinkText extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const LinkText(this.text, {super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
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
        LinkText(p.name,
            onTap: () => context.read<NavCubit>().go(AppRoute.partner(p.id))),
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

/// A data table that fills the available width and scrolls sideways when the
/// window is too narrow. [footer] is shown as a bold totals row.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(builder: (context, c) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: c.maxWidth),
          child: DataTable(
            columnSpacing: 24,
            horizontalMargin: 12,
            headingRowHeight: 40,
            headingTextStyle: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: mutedColor(context),
            ),
            columns: [
              for (final col in columns)
                DataColumn(label: Text(col.label), numeric: col.numeric),
            ],
            rows: [
              for (final r in rows)
                DataRow(cells: [for (final w in r) DataCell(w)]),
              if (footer != null)
                DataRow(cells: [
                  for (final w in footer!)
                    DataCell(DefaultTextStyle.merge(
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      child: w,
                    )),
                ]),
            ],
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant)),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: cs.outlineVariant))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                Text(subtitle,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          MoneyText(amount),
          if (action != null) ...[const SizedBox(width: 12), action!],
        ],
      ),
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
