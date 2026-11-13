import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'data/backup_service.dart';
import 'domain/ledger.dart';
import 'domain/ledger_service.dart';
import 'presentation/cubits.dart';
import 'presentation/dialogs.dart';
import 'presentation/pages_main.dart';
import 'presentation/pages_more.dart';
import 'presentation/theme.dart';
import 'presentation/widgets.dart';

class LedgerApp extends StatelessWidget {
  final LedgerService service;
  final BackupService backups;
  const LedgerApp({super.key, required this.service, required this.backups});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => LedgerCubit(service, backups)..init()),
        BlocProvider(create: (_) => NavCubit()),
      ],
      child: MaterialApp(
        title: 'Partner Ledger',
        debugShowCheckedModeBanner: false,
        theme: buildLedgerTheme(Brightness.light),
        darkTheme: buildLedgerTheme(Brightness.dark),
        home: const Shell(),
      ),
    );
  }
}

class _Destination {
  final Section section;
  final String label;
  final String shortLabel;
  final IconData icon;
  const _Destination(this.section, this.label, this.icon, [String? short])
      : shortLabel = short ?? label;
}

const _destinations = [
  _Destination(
      Section.dashboard, 'Dashboard', Icons.dashboard_outlined, 'Home'),
  _Destination(Section.sites, 'Sites', Icons.apartment_outlined),
  _Destination(Section.partners, 'Partners', Icons.group_outlined),
  _Destination(Section.planner, 'Planner', Icons.event_note_outlined),
  _Destination(Section.reports, 'Reports', Icons.description_outlined),
  _Destination(
      Section.settings, 'Data and backup', Icons.backup_outlined, 'Backup'),
];

/// Sidebar card on wide windows, bottom bar on narrow ones.
class Shell extends StatelessWidget {
  const Shell({super.key});

  Widget _page(Ledger l, AppRoute r) {
    final siteId = r.siteId;
    final partnerId = r.partnerId;
    if (siteId != null) {
      return SiteDetailPage(
          key: ValueKey('site-$siteId'), ledger: l, siteId: siteId);
    }
    if (partnerId != null) {
      return PartnerDetailPage(
          key: ValueKey('partner-$partnerId'), ledger: l, partnerId: partnerId);
    }
    switch (r.section) {
      case Section.dashboard:
        return DashboardPage(ledger: l);
      case Section.sites:
        return SitesPage(ledger: l);
      case Section.partners:
        return PartnersPage(ledger: l);
      case Section.planner:
        return PlannerPage(ledger: l);
      case Section.reports:
        return ReportsPage(ledger: l);
      case Section.settings:
        return SettingsPage(ledger: l);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LedgerCubit>().state;
    final route = context.watch<NavCubit>().state;
    final nav = context.read<NavCubit>();
    final ledger = state.ledger;

    if (state.error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(state.error!, textAlign: TextAlign.center),
          ),
        ),
      );
    }
    if (ledger == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final index = _destinations.indexWhere((d) => d.section == route.section);
    final page = _page(ledger, route);
    void select(int i) => nav.section(_destinations[i].section);
    final hasSites = ledger.data.sites.isNotEmpty;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
          if (hasSites) {
            openDialog(context, NewEntryDialog(siteId: route.siteId));
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyM, control: true): () {
          if (hasSites) {
            openDialog(
                context,
                AddMoneyDialog(
                    siteId: route.siteId, partnerId: route.partnerId));
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyT, control: true): () {
          if (hasSites) {
            openDialog(
                context,
                TransferDialog(
                    siteId: route.siteId, partnerId: route.partnerId));
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(builder: (context, c) {
          if (c.maxWidth < kWideLayout) {
            return Scaffold(
              body: SafeArea(child: page),
              bottomNavigationBar: NavigationBar(
                selectedIndex: index < 0 ? 0 : index,
                onDestinationSelected: select,
                labelBehavior:
                    NavigationDestinationLabelBehavior.onlyShowSelected,
                destinations: [
                  for (final d in _destinations)
                    NavigationDestination(
                        icon: Icon(d.icon), label: d.shortLabel),
                ],
              ),
            );
          }
          return Scaffold(
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1500),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 24, 20),
                        child: _Sidebar(
                            selected: index < 0 ? 0 : index, onSelect: select),
                      ),
                      Expanded(child: page),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const _Sidebar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = LedgerColors.of(context);
    return SizedBox(
      width: 212,
      child: Panel(
        radius: 14,
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text('₹',
                      style: TextStyle(
                          color: c.accentFg,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Partner Ledger',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      Text('Site investments',
                          style: TextStyle(fontSize: 12, color: c.mut)),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 18),
            for (var i = 0; i < _destinations.length; i++) ...[
              if (i > 0) const SizedBox(height: 4),
              _NavItem(
                label: _destinations[i].label,
                selected: i == selected,
                onTap: () => onSelect(i),
              ),
            ],
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.soft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Data is saved on this computer. A backup is made the first time the app opens each day.',
                style: TextStyle(fontSize: 12, color: c.mut),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = LedgerColors.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? c.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: c.soft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? c.accentInk : c.fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
