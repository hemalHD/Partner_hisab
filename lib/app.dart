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
import 'presentation/widgets.dart';

class LedgerApp extends StatelessWidget {
  final LedgerService service;
  final BackupService backups;
  const LedgerApp({super.key, required this.service, required this.backups});

  ThemeData _theme(Brightness brightness) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A56B0),
          brightness: brightness,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      );

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
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: const Shell(),
      ),
    );
  }
}

class _Destination {
  final Section section;
  final String label;
  final IconData icon;
  const _Destination(this.section, this.label, this.icon);
}

const _destinations = [
  _Destination(Section.dashboard, 'Dashboard', Icons.dashboard_outlined),
  _Destination(Section.sites, 'Sites', Icons.apartment_outlined),
  _Destination(Section.partners, 'Partners', Icons.group_outlined),
  _Destination(Section.planner, 'Planner', Icons.event_note_outlined),
  _Destination(Section.reports, 'Reports', Icons.description_outlined),
  _Destination(Section.settings, 'Settings', Icons.settings_outlined),
];

/// Navigation rail on wide windows, bottom bar on narrow ones.
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
          if (hasSites) openDialog(context, NewEntryDialog(siteId: route.siteId));
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
          if (c.maxWidth < 760) {
            return Scaffold(
              body: SafeArea(child: page),
              bottomNavigationBar: NavigationBar(
                selectedIndex: index < 0 ? 0 : index,
                onDestinationSelected: select,
                labelBehavior:
                    NavigationDestinationLabelBehavior.onlyShowSelected,
                destinations: [
                  for (final d in _destinations)
                    NavigationDestination(icon: Icon(d.icon), label: d.label),
                ],
              ),
            );
          }
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  NavigationRail(
                    extended: c.maxWidth >= 1100,
                    selectedIndex: index < 0 ? 0 : index,
                    onDestinationSelected: select,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        child: const Text('₹',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    destinations: [
                      for (final d in _destinations)
                        NavigationRailDestination(
                            icon: Icon(d.icon), label: Text(d.label)),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: page),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
