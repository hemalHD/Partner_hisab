import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/format.dart';
import '../data/backup_service.dart';
import '../domain/ledger.dart';
import '../domain/ledger_service.dart';
import 'cubits.dart';
import 'dialogs.dart';
import 'pages_main.dart';
import 'widgets.dart';

// ---------------------------------------------------------------- planner

class PlannerPage extends StatefulWidget {
  final Ledger ledger;
  const PlannerPage({super.key, required this.ledger});

  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> {
  int? _site;
  int? _projectionSite;
  String _due = todayIso();
  bool _isIncome = false;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _add(int siteId) async {
    try {
      await context.read<LedgerCubit>().addPlanned(
            siteId: siteId,
            due: _due,
            isIncome: _isIncome,
            amount: parseMoney(_amount.text),
            note: _note.text,
          );
      if (!mounted) return;
      setState(() {
        _error = null;
        _projectionSite = siteId;
        _amount.clear();
        _note.clear();
      });
      showSnack(context, 'Added to plan');
    } on LedgerError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.ledger;
    const subtitle =
        'Add expected income and expenses to see how much each partner should add, and by when.';
    if (l.data.sites.isEmpty) {
      return const PageFrame(
        title: 'Planner',
        subtitle: subtitle,
        children: [SectionCard(child: EmptyBox('Add a site first.'))],
      );
    }
    final siteChoices = [for (final s in l.data.sites) Choice(s.id, s.name)];
    final int site =
        l.site(_site ?? -1) == null ? l.data.sites.first.id : _site!;
    final int projSite = l.site(_projectionSite ?? -1) == null
        ? l.data.sites.first.id
        : _projectionSite!;
    final projection = l.projection(projSite);
    final cs = Theme.of(context).colorScheme;

    Widget projectionBody;
    if (projection == null) {
      projectionBody = const EmptyBox('This site has no shares set.');
    } else {
      var now = 0, need = 0;
      final ends = [0, 0, 0];
      final rows = <List<Widget>>[];
      for (final r in projection.rows) {
        now += r.now;
        need += r.shortfall;
        for (var k = 0; k < 3; k++) {
          ends[k] += r.monthEnd[k];
        }
        final by = r.shortfallDate;
        rows.add([
          PartnerLink(l, r.partnerId),
          Text(formatPercent(r.bp)),
          MoneyText(r.now),
          for (final x in r.monthEnd) MoneyText(x),
          Text(
            r.shortfall == 0
                ? '—'
                : '${formatMoney(r.shortfall)} ${by == null ? 'now' : 'by ${formatDate(by)}'}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ]);
      }
      projectionBody = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LedgerTable(
            columns: [
              const Col('Partner'),
              const Col('Share', numeric: true),
              const Col('Now', numeric: true),
              for (final m in projection.monthLabels) Col(m, numeric: true),
              const Col('Should add', numeric: true),
            ],
            rows: rows,
            footer: [
              const Text('Site total'),
              const Text('100%'),
              MoneyText(now),
              for (final x in ends) MoneyText(x),
              Text(need == 0 ? '—' : formatMoney(need)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Should add is the largest shortfall the partner reaches across all planned entries, with the date it is first reached.',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      );
    }

    return PageFrame(
      title: 'Planner',
      subtitle: subtitle,
      children: [
        SectionCard(
          title: 'Add planned entry',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  SizedBox(
                    width: 220,
                    child: ChoiceField<int>(
                      label: 'Site',
                      value: site,
                      options: siteChoices,
                      onChanged: (v) => setState(() => _site = v),
                    ),
                  ),
                  SizedBox(
                    width: 170,
                    child: DateField(
                      label: 'Due date',
                      value: _due,
                      onChanged: (v) => setState(() => _due = v),
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: ChoiceField<bool>(
                      label: 'Type',
                      value: _isIncome,
                      options: const [
                        Choice(false, 'Expense'),
                        Choice(true, 'Income'),
                      ],
                      onChanged: (v) => setState(() => _isIncome = v ?? false),
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: AmountField(
                      controller: _amount,
                      label: 'Amount (₹)',
                      onChanged: () {},
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: LabeledField(
                        label: 'Details',
                        child: TextField(
                          controller: _note,
                          decoration: const InputDecoration(
                              hintText: 'What is it for?'),
                        )),
                  ),
                  FilledButton(
                      onPressed: () => _add(site),
                      child: const Text('Add to plan')),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: TextStyle(
                        color: cs.error, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
        SectionCard(
          title: 'Planned entries',
          child: PlannedTable(l, l.plannedOf()),
        ),
        SectionCard(
          title: 'Projected balances',
          subtitle:
              'Balance at each month end if every planned entry happens and nobody adds money.',
          trailing: SizedBox(
            width: 240,
            child: ChoiceField<int>(
              label: 'Site',
              value: projSite,
              options: siteChoices,
              onChanged: (v) => setState(() => _projectionSite = v),
            ),
          ),
          child: projectionBody,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- reports

class ReportsPage extends StatelessWidget {
  final Ledger ledger;
  const ReportsPage({super.key, required this.ledger});

  String _csv() {
    final l = ledger;
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    String rupees(int paise) => (paise / 100).toStringAsFixed(2);
    final lines = <String>[
      [q('Partner'), for (final s in l.data.sites) q(s.name), q('All sites')]
          .join(','),
    ];
    for (final p in l.data.partners) {
      var total = 0;
      final cells = <String>[];
      for (final s in l.data.sites) {
        if (l.sitePartnerIds(s.id).contains(p.id)) {
          final b = l.balanceOf(s.id, p.id).balance;
          total += b;
          cells.add(rupees(b));
        } else {
          cells.add('');
        }
      }
      lines.add([q(p.name), ...cells, rupees(total)].join(','));
    }
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final l = ledger;
    final colTotals = [for (final _ in l.data.sites) 0];
    var grand = 0;
    final rows = <List<Widget>>[];
    for (final p in l.data.partners) {
      var total = 0;
      final cells = <Widget>[];
      for (var i = 0; i < l.data.sites.length; i++) {
        final s = l.data.sites[i];
        if (l.sitePartnerIds(s.id).contains(p.id)) {
          final b = l.balanceOf(s.id, p.id).balance;
          total += b;
          colTotals[i] += b;
          cells.add(MoneyText(b));
        } else {
          cells.add(const Text('·'));
        }
      }
      grand += total;
      rows.add([PartnerLink(l, p.id), ...cells, MoneyText(total)]);
    }
    final hasData = l.data.partners.isNotEmpty && l.data.sites.isNotEmpty;

    return PageFrame(
      title: 'Reports',
      subtitle: 'All partners balance sheet as on ${formatDate(l.today)}.',
      actions: [
        FilledButton(
          onPressed: !hasData
              ? null
              : () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: _csv()));
                  messenger.showSnackBar(const SnackBar(
                      content:
                          Text('Copied. Paste into Excel or Google Sheets.')));
                },
          child: const Text('Copy as CSV'),
        ),
      ],
      children: [
        SectionCard(
          title: 'Balance by partner and site',
          subtitle:
              'Negative means the partner needs to add money on that site. A dot means the partner is not on that site.',
          child: !hasData
              ? const EmptyBox('Nothing to report yet.')
              : LedgerTable(
                  columns: [
                    const Col('Partner'),
                    for (final s in l.data.sites) Col(s.name, numeric: true),
                    const Col('All sites', numeric: true),
                  ],
                  rows: rows,
                  footer: [
                    const Text('Total'),
                    for (final x in colTotals) MoneyText(x),
                    MoneyText(grand),
                  ],
                ),
        ),
        const SectionCard(
          title: 'Other reports',
          child: Text(
              "A partner's full statement is on their page under Partners. A site's entry list is on the site page under Entries. PDF and Excel export are the next step."),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- settings

class SettingsPage extends StatefulWidget {
  final Ledger ledger;
  const SettingsPage({super.key, required this.ledger});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Future<List<BackupFile>> _backups;

  @override
  void initState() {
    super.initState();
    _backups = context.read<LedgerCubit>().backups.list();
  }

  void _refresh() {
    setState(() {
      _backups = context.read<LedgerCubit>().backups.list();
    });
  }

  Future<bool> _confirm(String title, String body, String cta) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: SizedBox(width: 440, child: Text(body)),
        actions: [
          OutlinedButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Keep my data')),
          FilledButton(
              onPressed: () => Navigator.of(c).pop(true), child: Text(cta)),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _guard(Future<void> Function() action, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not finish: $e')));
    }
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LedgerCubit>();
    final nav = context.read<NavCubit>();
    final cs = Theme.of(context).colorScheme;
    return PageFrame(
      title: 'Data and backup',
      subtitle: 'Backup, restore and starting over.',
      children: [
        SectionCard(
          title: 'Backup and restore',
          subtitle:
              'All data lives on this computer. A backup is one file with every site, partner and entry. One is made automatically the first time the app opens each day.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText('Backup folder: ${cubit.backups.directory.path}',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: () => _guard(() async {
                    await cubit.backupNow();
                  }, 'Backup saved'),
                  child: const Text('Back up now'),
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<BackupFile>>(
                future: _backups,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const LinearProgressIndicator();
                  }
                  final files = snap.data ?? const <BackupFile>[];
                  if (files.isEmpty) {
                    return const EmptyBox('No backups yet.');
                  }
                  return Column(children: [
                    for (final f in files.take(10))
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                            border: Border(
                                top: BorderSide(color: cs.outlineVariant))),
                        child: Row(children: [
                          Expanded(
                            child: Text(
                                '${formatDate(isoDate(f.modified))}, ${f.modified.hour.toString().padLeft(2, '0')}:${f.modified.minute.toString().padLeft(2, '0')}  ·  ${f.name}',
                                overflow: TextOverflow.ellipsis),
                          ),
                          OutlinedButton(
                            onPressed: () async {
                              final ok = await _confirm(
                                  'Restore this backup?',
                                  'This replaces everything currently in the ledger with the contents of ${f.name}. Back up first if you may need the current data.',
                                  'Restore');
                              if (!ok) return;
                              await _guard(() => cubit.restore(f.path),
                                  'Backup restored');
                            },
                            child: const Text('Restore'),
                          ),
                        ]),
                      ),
                  ]);
                },
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Start over',
          subtitle:
              'Sample data has 3 sites and 5 partners for trying the app. Erasing removes every site, partner and entry.',
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton(
              onPressed: () async {
                final ok = await _confirm(
                    'Load sample data?',
                    'This replaces everything currently in the ledger with example sites and partners.',
                    'Load sample data');
                if (!ok) return;
                await _guard(cubit.loadSample, 'Sample data loaded');
                nav.section(Section.dashboard);
              },
              child: const Text('Load sample data'),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: cs.onErrorContainer,
                  side: BorderSide(color: cs.error)),
              onPressed: () async {
                final ok = await _confirm(
                    'Erase everything?',
                    'This deletes every site, partner and entry. It cannot be undone unless you have a backup.',
                    'Erase everything');
                if (!ok) return;
                await _guard(cubit.eraseAll, 'Ledger is empty');
                nav.section(Section.dashboard);
              },
              child: const Text('Erase everything'),
            ),
          ]),
        ),
        const SectionCard(
          title: 'Keyboard shortcuts',
          child: Text(
              'Ctrl+N  New entry\nCtrl+M  Add money\nCtrl+T  Transfer\nEsc  Close a dialog'),
        ),
      ],
    );
  }
}
