import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/format.dart';
import '../domain/ledger.dart';
import '../domain/models.dart';
import 'cubits.dart';
import 'dialogs.dart';
import 'widgets.dart';

// ---------------------------------------------------------------- shared tables

/// Sites with totals. Used on the dashboard and the Sites page.
class SitesTable extends StatelessWidget {
  final Ledger ledger;
  const SitesTable(this.ledger, {super.key});

  @override
  Widget build(BuildContext context) {
    final l = ledger;
    var added = 0, income = 0, expense = 0, balance = 0, needs = 0;
    final rows = <List<Widget>>[];
    for (final s in l.data.sites) {
      final t = l.totalsOf(s.id);
      final n = l.needsOnSite(s.id);
      added += t.added;
      income += t.income;
      expense += t.expense;
      balance += t.balance;
      needs += n;
      rows.add([
        SiteLink(l, s.id),
        Text('${l.currentVersion(s.id)?.lines.length ?? 0}'),
        NumText(t.added),
        NumText(t.income),
        NumText(t.expense),
        NumText(t.balance, negativeStyle: t.balance < 0),
        NumText(n, negativeStyle: true),
      ]);
    }
    return LedgerTable(
      columns: const [
        Col('Site'),
        Col('Partners', numeric: true),
        Col('Added', numeric: true),
        Col('Income', numeric: true),
        Col('Expense', numeric: true),
        Col('Balance', numeric: true),
        Col('Needs to add', numeric: true),
      ],
      rows: rows,
      footer: [
        const Text('All sites'),
        const Text(''),
        NumText(added),
        NumText(income),
        NumText(expense),
        NumText(balance, negativeStyle: balance < 0),
        NumText(needs, negativeStyle: true),
      ],
    );
  }
}

/// Entry list, newest first, with a Reverse action per row.
class EntriesTable extends StatelessWidget {
  final Ledger ledger;
  final List<Entry> entries;
  const EntriesTable(this.ledger, this.entries, {super.key});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const EmptyBox('Nothing here yet.');
    return LedgerTable(
      columns: const [
        Col('Date'),
        Col('Type'),
        Col('Details'),
        Col('Income', numeric: true),
        Col('Expense', numeric: true),
        Col('Partner money', numeric: true),
        Col(''),
      ],
      rows: [
        for (final e in entries)
          [
            Text(formatDate(e.date)),
            Text(kindLabel(e),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            EntryDetailCell(ledger, e),
            NumText(e.income),
            NumText(e.expense),
            (e.kind == EntryKind.incomeExpense ||
                    e.kind == EntryKind.replacement ||
                    e.allocations.isEmpty)
                ? const Text('—')
                : MoneyText(e.allocations.first.amount),
            e.canReverse
                ? OutlinedButton(
                    onPressed: () =>
                        openDialog(context, ReverseDialog(entry: e)),
                    child: const Text('Reverse'))
                : const SizedBox.shrink(),
          ],
      ],
    );
  }
}

class PlannedTable extends StatelessWidget {
  final Ledger ledger;
  final List<PlannedEntry> planned;
  final bool showSite;
  const PlannedTable(this.ledger, this.planned,
      {super.key, this.showSite = true});

  @override
  Widget build(BuildContext context) {
    if (planned.isEmpty) return const EmptyBox('No planned entries.');
    return LedgerTable(
      columns: [
        const Col('Due'),
        if (showSite) const Col('Site'),
        const Col('Type'),
        const Col('Details'),
        const Col('Amount', numeric: true),
        const Col(''),
      ],
      rows: [
        for (final p in planned)
          [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(formatDate(p.due)),
              if (p.due.compareTo(ledger.today) < 0) ...[
                const SizedBox(width: 6),
                Pill('Overdue',
                    background: Theme.of(context).colorScheme.errorContainer,
                    foreground: Theme.of(context).colorScheme.onErrorContainer),
              ],
            ]),
            if (showSite) SiteLink(ledger, p.siteId),
            Text(p.isIncome ? 'Income' : 'Expense',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(p.note.isEmpty ? '—' : p.note),
            MoneyText(p.signedAmount),
            Row(mainAxisSize: MainAxisSize.min, children: [
              OutlinedButton(
                  onPressed: () =>
                      openDialog(context, NewEntryDialog(planned: p)),
                  child: const Text('Enter now')),
              OutlinedButton(
                  onPressed: () =>
                      context.read<LedgerCubit>().deletePlanned(p.id),
                  child: const Text('Remove')),
            ]),
          ],
      ],
    );
  }
}

// ---------------------------------------------------------------- dashboard

class DashboardPage extends StatelessWidget {
  final Ledger ledger;
  const DashboardPage({super.key, required this.ledger});

  @override
  Widget build(BuildContext context) {
    final l = ledger;
    if (l.data.sites.isEmpty) {
      return PageFrame(
        title: 'Dashboard',
        subtitle: 'No sites yet.',
        children: [
          SectionCard(
            child: EmptyBox(
              'Add partners first, then a site with their percentages.',
              actions: [
                OutlinedButton(
                    onPressed: () =>
                        openDialog(context, const NewPartnerDialog()),
                    child: const Text('New partner')),
                FilledButton(
                    onPressed: () => openDialog(context, const NewSiteDialog()),
                    child: const Text('New site')),
                OutlinedButton(
                    onPressed: () => context.read<LedgerCubit>().loadSample(),
                    child: const Text('Load sample data')),
              ],
            ),
          ),
        ],
      );
    }

    var added = 0, income = 0, expense = 0, balance = 0;
    final owing = <({int site, int partner, int amount})>[];
    final ahead = <({int site, int partner, int amount})>[];
    for (final s in l.data.sites) {
      final t = l.totalsOf(s.id);
      added += t.added;
      income += t.income;
      expense += t.expense;
      balance += t.balance;
      for (final pid in l.sitePartnerIds(s.id)) {
        final b = l.balanceOf(s.id, pid).balance;
        if (b < 0) owing.add((site: s.id, partner: pid, amount: b));
        if (b > 0) ahead.add((site: s.id, partner: pid, amount: b));
      }
    }
    owing.sort((a, b) => a.amount.compareTo(b.amount));
    ahead.sort((a, b) => b.amount.compareTo(a.amount));
    final owed = owing.fold<int>(0, (a, x) => a - x.amount);
    final advance = ahead.fold<int>(0, (a, x) => a + x.amount);
    final cs = Theme.of(context).colorScheme;

    return PageFrame(
      title: 'Dashboard',
      subtitle:
          '${l.data.sites.length} sites, ${l.data.partners.length} partners. All amounts in ₹.',
      actions: [
        OutlinedButton(
            onPressed: () => openDialog(context, const NewEntryDialog()),
            child: const Text('New entry')),
        FilledButton(
            onPressed: () => openDialog(context, const AddMoneyDialog()),
            child: const Text('Add money')),
      ],
      children: [
        StatRow(children: [
          StatCard('Total added by partners', formatMoney(added)),
          StatCard('Income received', formatMoney(income)),
          StatCard('Expenses spent', formatMoney(expense)),
          StatCard('Net balance with partners', formatMoney(balance),
              negative: balance < 0),
        ]),
        TwoColumns(
          left: SectionCard(
            title: 'Money to collect',
            subtitle:
                'Partners whose share of expenses is higher than what they have added.',
            trailing: Pill('${formatMoney(owed)} owed',
                background: cs.errorContainer, foreground: cs.onErrorContainer),
            child: owing.isEmpty
                ? const EmptyBox('Nobody is in negative.')
                : Column(children: [
                    for (final x in owing)
                      BalanceLine(
                        title: PartnerLink(l, x.partner),
                        subtitle: l.siteName(x.site),
                        amount: x.amount,
                        action: OutlinedButton(
                            onPressed: () => openDialog(
                                context,
                                AddMoneyDialog(
                                    siteId: x.site, partnerId: x.partner)),
                            child: const Text('Add money')),
                      ),
                  ]),
          ),
          right: SectionCard(
            title: 'Advances held',
            subtitle:
                "Money added beyond the partner's share of expenses so far. New expenses use it up first.",
            trailing: Pill('${formatMoney(advance)} in advance',
                background: cs.primaryContainer,
                foreground: cs.onPrimaryContainer),
            child: ahead.isEmpty
                ? const EmptyBox('No advances.')
                : Column(children: [
                    for (final x in ahead)
                      BalanceLine(
                        title: PartnerLink(l, x.partner),
                        subtitle: l.siteName(x.site),
                        amount: x.amount,
                      ),
                  ]),
          ),
        ),
        SectionCard(title: 'Sites', child: SitesTable(l)),
      ],
    );
  }
}

// ---------------------------------------------------------------- sites

class SitesPage extends StatelessWidget {
  final Ledger ledger;
  const SitesPage({super.key, required this.ledger});

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Sites',
      subtitle:
          '${ledger.data.sites.length} sites. Open a site to see its partners and entries.',
      actions: [
        FilledButton(
            onPressed: () => openDialog(context, const NewSiteDialog()),
            child: const Text('New site')),
      ],
      children: [
        SectionCard(
          child: ledger.data.sites.isEmpty
              ? const EmptyBox('No sites yet.')
              : SitesTable(ledger),
        ),
      ],
    );
  }
}

class SiteDetailPage extends StatefulWidget {
  final Ledger ledger;
  final int siteId;
  const SiteDetailPage({super.key, required this.ledger, required this.siteId});

  @override
  State<SiteDetailPage> createState() => _SiteDetailPageState();
}

class _SiteDetailPageState extends State<SiteDetailPage> {
  static const _tabs = [
    'Partners',
    'Entries',
    'Transfers',
    'Share history',
    'Planner'
  ];
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l = widget.ledger;
    final site = l.site(widget.siteId);
    final nav = context.read<NavCubit>();
    if (site == null) {
      return PageFrame(title: 'Site not found', children: [
        Align(
          alignment: Alignment.centerLeft,
          child: LinkText('Back to sites',
              onTap: () => nav.section(Section.sites)),
        ),
      ]);
    }
    final sid = site.id;
    final version = l.currentVersion(sid);
    final totals = l.totalsOf(sid);
    final pids = l.sitePartnerIds(sid);
    final owing = [
      for (final p in pids)
        if (l.balanceOf(sid, p).balance < 0) p
    ];
    final cs = Theme.of(context).colorScheme;
    const shades = [255, 184, 128, 88, 60, 40];

    return PageFrame(
      title: site.name,
      subtitle: [
        if (version == null)
          'No shares set yet.'
        else
          '${version.lines.length} partners. Shares in force from ${formatDate(version.effectiveFrom)}.',
        if (site.location.isNotEmpty) '${site.location}.',
      ].join(' '),
      breadcrumb: Row(mainAxisSize: MainAxisSize.min, children: [
        LinkText('Dashboard', onTap: () => nav.section(Section.dashboard)),
        const Text('  /  '),
        LinkText('Sites', onTap: () => nav.section(Section.sites)),
        const Text('  /  '),
        Flexible(child: Text(site.name, overflow: TextOverflow.ellipsis)),
      ]),
      actions: [
        OutlinedButton(
            onPressed: () => openDialog(context, TransferDialog(siteId: sid)),
            child: const Text('Transfer')),
        OutlinedButton(
            onPressed: () => openDialog(context, NewEntryDialog(siteId: sid)),
            child: const Text('New entry')),
        FilledButton(
            onPressed: () => openDialog(context, AddMoneyDialog(siteId: sid)),
            child: const Text('Add money')),
      ],
      children: [
        StatRow(children: [
          StatCard('Total added', formatMoney(totals.added)),
          StatCard('Income', formatMoney(totals.income)),
          StatCard('Expense', formatMoney(totals.expense)),
          StatCard('Site balance', formatMoney(totals.balance),
              negative: totals.balance < 0),
        ]),
        TwoColumns(
          left: SectionCard(
            title: 'Needs to add',
            subtitle: owing.isEmpty
                ? null
                : '${owing.length} in negative on this site.',
            child: owing.isEmpty
                ? const EmptyBox('Nobody is in negative on this site.')
                : Column(children: [
                    for (final p in owing)
                      BalanceLine(
                        title: PartnerLink(l, p),
                        subtitle: 'Share ${formatPercent(l.shareBp(sid, p))}',
                        amount: l.balanceOf(sid, p).balance,
                        action: FilledButton(
                            onPressed: () => openDialog(context,
                                AddMoneyDialog(siteId: sid, partnerId: p)),
                            child: const Text('Add money')),
                      ),
                  ]),
          ),
          right: SectionCard(
            title: 'Share split',
            trailing: Wrap(spacing: 8, children: [
              OutlinedButton(
                  onPressed: () =>
                      openDialog(context, EditSharesDialog(siteId: sid)),
                  child: const Text('Edit shares')),
              if (version != null)
                OutlinedButton(
                    onPressed: () =>
                        openDialog(context, ReplacePartnerDialog(siteId: sid)),
                    child: const Text('Replace partner')),
            ]),
            child: version == null
                ? const EmptyBox(
                    'Set the partners and percentages before adding entries.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Row(children: [
                          for (var i = 0; i < version.lines.length; i++)
                            Expanded(
                              flex: version.lines[i].bp,
                              child: Container(
                                height: 14,
                                margin: EdgeInsets.only(left: i == 0 ? 0 : 2),
                                color: cs.primary.withAlpha(
                                    shades[i < shades.length ? i : 5]),
                              ),
                            ),
                        ]),
                      ),
                      const SizedBox(height: 10),
                      const SizedBox(height: 2),
                      Wrap(spacing: 18, runSpacing: 6, children: [
                        for (var i = 0; i < version.lines.length; i++)
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: cs.primary.withAlpha(
                                    shades[i < shades.length ? i : 5]),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text.rich(
                              TextSpan(children: [
                                TextSpan(
                                    text:
                                        '${l.partnerName(version.lines[i].partnerId)} '),
                                TextSpan(
                                    text: formatPercent(version.lines[i].bp),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                              ]),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ]),
                      ]),
                    ],
                  ),
          ),
        ),
        Panel(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UnderlineTabs(
                labels: _tabs,
                selected: _tab,
                onSelect: (i) => setState(() => _tab = i),
              ),
              const SizedBox(height: 12),
              _tabBody(context, l, sid, pids, version),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabBody(BuildContext context, Ledger l, int sid, List<int> pids,
      ShareVersion? version) {
    switch (_tab) {
      case 0:
        if (pids.isEmpty) {
          return EmptyBox('No partners on this site yet.', actions: [
            FilledButton(
                onPressed: () =>
                    openDialog(context, EditSharesDialog(siteId: sid)),
                child: const Text('Set shares')),
          ]);
        }
        var added = 0, income = 0, expense = 0, other = 0, balance = 0;
        final rows = <List<Widget>>[];
        for (final p in pids) {
          final b = l.balanceOf(sid, p);
          added += b.added;
          income += b.income;
          expense += b.expense;
          other += b.other;
          balance += b.balance;
          rows.add([
            PartnerLink(l, p),
            Text(formatPercent(l.shareBp(sid, p))),
            NumText(b.added),
            NumText(b.income),
            NumText(b.expense),
            NumText(b.other),
            MoneyText(b.balance),
            StatusChip(b.balance),
            ActionButton('Add money',
                primary: b.balance < 0,
                onPressed: () => openDialog(
                    context, AddMoneyDialog(siteId: sid, partnerId: p))),
          ]);
        }
        return LedgerTable(
          columns: const [
            Col('Partner'),
            Col('Share', numeric: true),
            Col('Added', numeric: true),
            Col('Income share', numeric: true),
            Col('Expense share', numeric: true),
            Col('Transfers', numeric: true),
            Col('Balance', numeric: true),
            Col('Status'),
            Col(''),
          ],
          rows: rows,
          footer: [
            const Text('Total'),
            Text(version == null ? '' : '100%'),
            NumText(added),
            NumText(income),
            NumText(expense),
            NumText(other),
            MoneyText(balance),
            const Text(''),
            const Text(''),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
                'Entries are never edited. To correct one, reverse it and enter it again.',
                style: TextStyle(fontSize: 13, color: mutedColor(context))),
            const SizedBox(height: 8),
            EntriesTable(l, l.entriesOf(sid)),
          ],
        );
      case 2:
        final transfers = [
          for (final e in l.entriesOf(sid))
            if (e.kind == EntryKind.transferIn ||
                e.kind == EntryKind.transferOut)
              e
        ];
        if (transfers.isEmpty) {
          return EmptyBox(
            "No transfers on this site yet. A transfer moves a partner's money from one site to another.",
            actions: [
              FilledButton(
                  onPressed: () =>
                      openDialog(context, TransferDialog(siteId: sid)),
                  child: const Text('Transfer money')),
            ],
          );
        }
        return EntriesTable(l, transfers);
      case 3:
        final versions = l.versionsOf(sid).reversed.toList();
        if (versions.isEmpty) return const EmptyBox('No share versions yet.');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
                'Each entry is split using the version in force on its date. Saved entries never change.',
                style: TextStyle(fontSize: 13, color: mutedColor(context))),
            for (final v in versions) ...[
              const SizedBox(height: 12),
              _VersionCard(l, v, isCurrent: version?.id == v.id),
            ],
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                    'Planned entries do not change balances until they are entered.',
                    style: TextStyle(fontSize: 13, color: mutedColor(context))),
                OutlinedButton(
                    onPressed: () =>
                        context.read<NavCubit>().section(Section.planner),
                    child: const Text('Open planner')),
              ],
            ),
            const SizedBox(height: 8),
            PlannedTable(l, l.plannedOf(siteId: sid), showSite: false),
          ],
        );
    }
  }
}

class _VersionCard extends StatelessWidget {
  final Ledger ledger;
  final ShareVersion version;
  final bool isCurrent;
  const _VersionCard(this.ledger, this.version, {required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final upcoming = version.effectiveFrom.compareTo(ledger.today) > 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Text('From ${formatDate(version.effectiveFrom)}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            isCurrent
                ? Pill('Current',
                    background: cs.primaryContainer,
                    foreground: cs.onPrimaryContainer)
                : Pill(upcoming ? 'Upcoming' : 'Past'),
          ]),
          if (version.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(version.note,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            ),
          for (final x in version.lines)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                Expanded(child: Text(ledger.partnerName(x.partnerId))),
                Text(formatPercent(x.bp),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- partners

class PartnersPage extends StatelessWidget {
  final Ledger ledger;
  const PartnersPage({super.key, required this.ledger});

  @override
  Widget build(BuildContext context) {
    final l = ledger;
    var tAdded = 0, tNeed = 0, tAdvance = 0;
    final rows = <List<Widget>>[];
    for (final p in l.data.partners) {
      var added = 0, need = 0, advance = 0;
      final sites = l.activeSitesOf(p.id);
      for (final s in sites) {
        final b = l.balanceOf(s.id, p.id);
        added += b.added;
        if (b.balance < 0) need -= b.balance;
        if (b.balance > 0) advance += b.balance;
      }
      tAdded += added;
      tNeed += need;
      tAdvance += advance;
      rows.add([
        PartnerLink(l, p.id),
        Text('${sites.length}'),
        NumText(added),
        NumText(need, negativeStyle: true),
        NumText(advance),
        MoneyText(advance - need),
      ]);
    }
    return PageFrame(
      title: 'Partners',
      subtitle:
          '${l.data.partners.length} partners. Balances are totals over all their sites.',
      actions: [
        FilledButton(
            onPressed: () => openDialog(context, const NewPartnerDialog()),
            child: const Text('New partner')),
      ],
      children: [
        SectionCard(
          child: l.data.partners.isEmpty
              ? const EmptyBox('No partners yet.')
              : LedgerTable(
                  columns: const [
                    Col('Partner'),
                    Col('Sites', numeric: true),
                    Col('Total added', numeric: true),
                    Col('Needs to add', numeric: true),
                    Col('Advance held', numeric: true),
                    Col('Net balance', numeric: true),
                  ],
                  rows: rows,
                  footer: [
                    const Text('All partners'),
                    const Text(''),
                    NumText(tAdded),
                    NumText(tNeed, negativeStyle: true),
                    NumText(tAdvance),
                    MoneyText(tAdvance - tNeed),
                  ],
                ),
        ),
      ],
    );
  }
}

class PartnerDetailPage extends StatefulWidget {
  final Ledger ledger;
  final int partnerId;
  const PartnerDetailPage(
      {super.key, required this.ledger, required this.partnerId});

  @override
  State<PartnerDetailPage> createState() => _PartnerDetailPageState();
}

class _PartnerDetailPageState extends State<PartnerDetailPage> {
  /// Statement filter. 0 means all sites.
  int _siteFilter = 0;

  @override
  Widget build(BuildContext context) {
    final l = widget.ledger;
    final partner = l.partner(widget.partnerId);
    final nav = context.read<NavCubit>();
    if (partner == null) {
      return PageFrame(title: 'Partner not found', children: [
        Align(
          alignment: Alignment.centerLeft,
          child: LinkText('Back to partners',
              onTap: () => nav.section(Section.partners)),
        ),
      ]);
    }
    final pid = partner.id;
    final sites = l.activeSitesOf(pid);
    var added = 0, income = 0, expense = 0, other = 0, balance = 0;
    final rows = <List<Widget>>[];
    for (final s in sites) {
      final b = l.balanceOf(s.id, pid);
      added += b.added;
      income += b.income;
      expense += b.expense;
      other += b.other;
      balance += b.balance;
      rows.add([
        SiteLink(l, s.id),
        Text(formatPercent(l.shareBp(s.id, pid))),
        NumText(b.added),
        NumText(b.income),
        NumText(b.expense),
        NumText(b.other),
        MoneyText(b.balance),
        ActionButton('Add money',
            primary: b.balance < 0,
            onPressed: () => openDialog(
                context, AddMoneyDialog(siteId: s.id, partnerId: pid))),
      ]);
    }
    final filter = sites.any((s) => s.id == _siteFilter) ? _siteFilter : 0;
    final statement = l.statement(pid, siteId: filter == 0 ? null : filter);

    return PageFrame(
      title: partner.name,
      subtitle: [
        'Partner on ${sites.length} site${sites.length == 1 ? '' : 's'}.',
        if (partner.isCompany) 'Company account.',
        if (partner.phone.isNotEmpty) 'Phone ${partner.phone}.',
      ].join(' '),
      breadcrumb: Row(mainAxisSize: MainAxisSize.min, children: [
        LinkText('Dashboard', onTap: () => nav.section(Section.dashboard)),
        const Text('  /  '),
        LinkText('Partners', onTap: () => nav.section(Section.partners)),
        const Text('  /  '),
        Flexible(child: Text(partner.name, overflow: TextOverflow.ellipsis)),
      ]),
      actions: [
        OutlinedButton(
            onPressed: () =>
                openDialog(context, TransferDialog(partnerId: pid)),
            child: const Text('Transfer')),
        FilledButton(
            onPressed: () =>
                openDialog(context, AddMoneyDialog(partnerId: pid)),
            child: const Text('Add money')),
      ],
      children: [
        StatRow(children: [
          StatCard('Total added', formatMoney(added)),
          StatCard('Income share', formatMoney(income)),
          StatCard('Expense share', formatMoney(expense)),
          StatCard(
              balance < 0
                  ? 'Needs to add'
                  : (balance > 0 ? 'Advance held' : 'Net balance'),
              formatSigned(balance),
              negative: balance < 0),
        ]),
        SectionCard(
          title: 'Balance by site',
          child: sites.isEmpty
              ? const EmptyBox(
                  "Not on any site yet. Add this partner from a site's Edit shares.")
              : LedgerTable(
                  columns: const [
                    Col('Site'),
                    Col('Share', numeric: true),
                    Col('Added', numeric: true),
                    Col('Income share', numeric: true),
                    Col('Expense share', numeric: true),
                    Col('Transfers', numeric: true),
                    Col('Balance', numeric: true),
                    Col(''),
                  ],
                  rows: rows,
                  footer: [
                    const Text('All sites'),
                    const Text(''),
                    NumText(added),
                    NumText(income),
                    NumText(expense),
                    NumText(other),
                    MoneyText(balance),
                    const Text(''),
                  ],
                ),
        ),
        SectionCard(
          title: 'Statement',
          trailing: SizedBox(
            width: 240,
            child: ChoiceField<int>(
              label: 'Site',
              value: filter,
              options: [
                const Choice(0, 'All sites'),
                for (final s in sites) Choice(s.id, s.name),
              ],
              onChanged: (v) => setState(() => _siteFilter = v ?? 0),
            ),
          ),
          child: statement.isEmpty
              ? const EmptyBox('No entries yet.')
              : LedgerTable(
                  columns: const [
                    Col('Date'),
                    Col('Site'),
                    Col('Type'),
                    Col('Details'),
                    Col('Amount', numeric: true),
                    Col('Balance after', numeric: true),
                  ],
                  rows: [
                    for (final r in statement)
                      [
                        Text(formatDate(r.entry.date)),
                        Text(l.siteName(r.entry.siteId)),
                        Text(
                            r.entry.kind == EntryKind.incomeExpense
                                ? '${kindLabel(r.entry)} share'
                                : kindLabel(r.entry),
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        EntryDetailCell(l, r.entry),
                        MoneyText(r.amount),
                        MoneyText(r.runningBalance),
                      ],
                  ],
                ),
        ),
      ],
    );
  }
}
