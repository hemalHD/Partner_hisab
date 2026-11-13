import '../core/format.dart';
import 'models.dart';

/// Splits a non-negative paise [amount] by basis points. Each share is rounded
/// down, then the leftover paise go one at a time to the largest shares
/// (ties: lowest partner id), so the parts always add up to [amount].
List<int> splitAmount(int amount, List<ShareLine> lines) {
  final parts = [for (final l in lines) (amount * l.bp) ~/ 10000];
  if (lines.isEmpty) return parts;
  var left = amount - parts.fold<int>(0, (a, b) => a + b);
  final order = List<int>.generate(lines.length, (i) => i)
    ..sort((a, b) {
      final c = lines[b].bp.compareTo(lines[a].bp);
      return c != 0 ? c : lines[a].partnerId.compareTo(lines[b].partnerId);
    });
  var k = 0;
  while (left > 0) {
    parts[order[k]] += 1;
    left -= 1;
    k = (k + 1) % order.length;
  }
  return parts;
}

/// Builds the allocations of an income/expense entry. Income and expense are
/// split separately so each partner's income share and expense share are exact.
List<Allocation> allocateIncomeExpense(
    int income, int expense, List<ShareLine> lines) {
  final pi = splitAmount(income, lines);
  final pe = splitAmount(expense, lines);
  return [
    for (var i = 0; i < lines.length; i++)
      Allocation(
        partnerId: lines[i].partnerId,
        income: pi[i],
        expense: pe[i],
        amount: pi[i] - pe[i],
      ),
  ];
}

/// One partner's position on one site.
class Balance {
  int added = 0;
  int income = 0;
  int expense = 0;

  /// Transfers in and out, and balances taken over in a replacement.
  int other = 0;
  int balance = 0;
}

class SiteTotals {
  int added = 0;
  int income = 0;
  int expense = 0;
  int balance = 0;
}

class StatementRow {
  final Entry entry;
  final int amount;
  final int runningBalance;
  const StatementRow(this.entry, this.amount, this.runningBalance);
}

class ProjectionRow {
  final int partnerId;
  final int bp;
  final int now;
  final List<int> monthEnd;

  /// Largest shortfall reached across all planned entries (0 if none).
  final int shortfall;

  /// Date the largest shortfall is reached; null means it is already there.
  final String? shortfallDate;
  const ProjectionRow({
    required this.partnerId,
    required this.bp,
    required this.now,
    required this.monthEnd,
    required this.shortfall,
    required this.shortfallDate,
  });
}

class Projection {
  final List<String> monthLabels;
  final List<ProjectionRow> rows;
  const Projection(this.monthLabels, this.rows);
}

/// Read-only view of the ledger with every derived number. Balances are always
/// computed from saved allocations, never stored.
class Ledger {
  final LedgerData data;
  final String today;
  final Map<String, Balance> _balances = {};
  final Map<int, SiteTotals> _totals = {};

  Ledger(this.data, {String? today}) : today = today ?? todayIso() {
    for (final s in data.sites) {
      _totals[s.id] = SiteTotals();
    }
    for (final e in data.entries) {
      final t = _totals[e.siteId];
      if (t == null) continue;
      t.income += e.income;
      t.expense += e.expense;
      for (final a in e.allocations) {
        final b = _balances.putIfAbsent('${e.siteId}|${a.partnerId}', Balance.new);
        switch (e.kind) {
          case EntryKind.addMoney:
            b.added += a.amount;
            t.added += a.amount;
          case EntryKind.incomeExpense:
            b.income += a.income;
            b.expense += a.expense;
          case EntryKind.transferOut:
          case EntryKind.transferIn:
          case EntryKind.replacement:
            b.other += a.amount;
        }
        b.balance += a.amount;
        t.balance += a.amount;
      }
    }
  }

  Partner? partner(int id) {
    for (final p in data.partners) {
      if (p.id == id) return p;
    }
    return null;
  }

  Site? site(int id) {
    for (final s in data.sites) {
      if (s.id == id) return s;
    }
    return null;
  }

  String partnerName(int id) => partner(id)?.name ?? '(removed)';
  String siteName(int id) => site(id)?.name ?? '(removed)';

  /// Share versions of a site, oldest first.
  List<ShareVersion> versionsOf(int siteId) =>
      data.versions.where((v) => v.siteId == siteId).toList()
        ..sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom));

  /// The version in force on [date], or null if the site had no shares yet.
  ShareVersion? versionAt(int siteId, String date) {
    ShareVersion? found;
    for (final v in versionsOf(siteId)) {
      if (v.effectiveFrom.compareTo(date) <= 0) found = v;
    }
    return found;
  }

  ShareVersion? currentVersion(int siteId) {
    final now = versionAt(siteId, today);
    if (now != null) return now;
    final all = versionsOf(siteId);
    return all.isEmpty ? null : all.first;
  }

  /// Latest entry date on a site, or '' when it has no entries.
  String lastEntryDate(int siteId) {
    var d = '';
    for (final e in data.entries) {
      if (e.siteId == siteId && e.date.compareTo(d) > 0) d = e.date;
    }
    return d;
  }

  Balance balanceOf(int siteId, int partnerId) =>
      _balances['$siteId|$partnerId'] ?? Balance();

  SiteTotals totalsOf(int siteId) => _totals[siteId] ?? SiteTotals();

  int shareBp(int siteId, int partnerId) {
    final v = currentVersion(siteId);
    if (v == null) return 0;
    for (final l in v.lines) {
      if (l.partnerId == partnerId) return l.bp;
    }
    return 0;
  }

  /// Partners to show on a site: current share holders first, then former
  /// partners who still carry a balance there.
  List<int> sitePartnerIds(int siteId) {
    final v = currentVersion(siteId);
    final out = <int>[if (v != null) ...v.lines.map((l) => l.partnerId)];
    for (final p in data.partners) {
      if (!out.contains(p.id) && balanceOf(siteId, p.id).balance != 0) {
        out.add(p.id);
      }
    }
    return out;
  }

  /// True if the partner held a share on the site in any version.
  bool everOn(int siteId, int partnerId) => data.versions.any((v) =>
      v.siteId == siteId && v.lines.any((l) => l.partnerId == partnerId));

  /// Sites the partner can transfer between.
  List<Site> sitesEverOn(int partnerId) =>
      data.sites.where((s) => everOn(s.id, partnerId)).toList();

  /// Sites where the partner currently appears.
  List<Site> activeSitesOf(int partnerId) => data.sites
      .where((s) => sitePartnerIds(s.id).contains(partnerId))
      .toList();

  /// Sum of negative partner balances on a site, as a positive number.
  int needsOnSite(int siteId) {
    var n = 0;
    for (final pid in sitePartnerIds(siteId)) {
      final b = balanceOf(siteId, pid).balance;
      if (b < 0) n -= b;
    }
    return n;
  }

  /// Entries of a site, newest first.
  List<Entry> entriesOf(int siteId) =>
      data.entries.where((e) => e.siteId == siteId).toList()..sort(_newestFirst);

  static int _newestFirst(Entry a, Entry b) {
    final c = b.date.compareTo(a.date);
    return c != 0 ? c : b.id.compareTo(a.id);
  }

  /// A partner's entries with a running balance, newest first.
  List<StatementRow> statement(int partnerId, {int? siteId}) {
    final list = data.entries
        .where((e) =>
            (siteId == null || e.siteId == siteId) &&
            e.allocations.any((a) => a.partnerId == partnerId))
        .toList()
      ..sort((a, b) {
        final c = a.date.compareTo(b.date);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    var run = 0;
    final rows = <StatementRow>[];
    for (final e in list) {
      var amount = 0;
      for (final a in e.allocations) {
        if (a.partnerId == partnerId) amount += a.amount;
      }
      run += amount;
      rows.add(StatementRow(e, amount, run));
    }
    return rows.reversed.toList();
  }

  /// Planned entries, earliest due first.
  List<PlannedEntry> plannedOf({int? siteId}) =>
      data.planned.where((p) => siteId == null || p.siteId == siteId).toList()
        ..sort((a, b) {
          final c = a.due.compareTo(b.due);
          return c != 0 ? c : a.id.compareTo(b.id);
        });

  /// Month-end balances for the next three months if every planned entry
  /// happens and nobody adds money. Null when the site has no shares.
  Projection? projection(int siteId) {
    final v = currentVersion(siteId);
    if (v == null) return null;
    final base = DateTime.parse(today);
    final months = [
      for (var k = 0; k < 3; k++) DateTime(base.year, base.month + k, 1)
    ];
    final yms = [for (final m in months) isoDate(m).substring(0, 7)];
    final labels = [
      for (final m in months) '${monthNames[m.month - 1]} ${m.year}'
    ];
    final plan = plannedOf(siteId: siteId);
    final parts = [for (final p in plan) splitAmount(p.amount, v.lines)];
    final rows = <ProjectionRow>[];
    for (var i = 0; i < v.lines.length; i++) {
      final line = v.lines[i];
      final now = balanceOf(siteId, line.partnerId).balance;
      var run = now;
      var min = now;
      String? minDate;
      final ends = [now, now, now];
      for (var j = 0; j < plan.length; j++) {
        run += (plan[j].isIncome ? 1 : -1) * parts[j][i];
        if (run < min) {
          min = run;
          minDate = plan[j].due;
        }
        for (var k = 0; k < 3; k++) {
          if (plan[j].due.substring(0, 7).compareTo(yms[k]) <= 0) ends[k] = run;
        }
      }
      rows.add(ProjectionRow(
        partnerId: line.partnerId,
        bp: line.bp,
        now: now,
        monthEnd: ends,
        shortfall: min < 0 ? -min : 0,
        shortfallDate: min < 0 ? minDate : null,
      ));
    }
    return Projection(labels, rows);
  }
}
