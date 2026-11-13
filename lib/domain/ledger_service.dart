import '../core/format.dart';
import 'ledger.dart';
import 'ledger_repository.dart';
import 'models.dart';

/// A rule was broken. [message] is written for the person using the app.
class LedgerError implements Exception {
  final String message;
  const LedgerError(this.message);

  @override
  String toString() => message;
}

/// Every change to the ledger goes through here. Each method validates against
/// the current [Ledger], builds the entries with their allocations, and saves
/// them. Entries are never edited or deleted: corrections are reversals.
class LedgerService {
  final LedgerRepository repo;
  const LedgerService(this.repo);

  Future<Ledger> load() async => Ledger(await repo.load());

  Future<int> addPartner({
    required String name,
    String phone = '',
    bool isCompany = false,
  }) {
    final n = name.trim();
    if (n.isEmpty) throw const LedgerError('Enter a name.');
    return repo.insertPartner(
        Partner(id: 0, name: n, phone: phone.trim(), isCompany: isCompany));
  }

  Future<int> addSite({
    required String name,
    String location = '',
    required String startDate,
  }) {
    final n = name.trim();
    if (n.isEmpty) throw const LedgerError('Enter a site name.');
    if (startDate.isEmpty) throw const LedgerError('Choose a start date.');
    return repo.insertSite(
        Site(id: 0, name: n, location: location.trim(), startDate: startDate));
  }

  /// A share change must not sit before the current version or before entries
  /// that were already split with the old shares.
  void _checkVersionDate(Ledger l, int siteId, String date) {
    final versions = l.versionsOf(siteId);
    if (versions.isEmpty) return;
    final last = versions.last;
    if (date.compareTo(last.effectiveFrom) <= 0) {
      throw LedgerError(
          'Pick a date after ${formatDate(last.effectiveFrom)}, when the current shares started.');
    }
    final lastEntry = l.lastEntryDate(siteId);
    if (lastEntry.isNotEmpty && date.compareTo(lastEntry) < 0) {
      throw LedgerError(
          'Pick ${formatDate(lastEntry)} or later. This site already has entries up to that date.');
    }
  }

  /// Starts a new share version. [bpByPartner] maps partner id to basis points;
  /// zero or missing means the partner is not on the site.
  Future<void> saveShares(
    Ledger l, {
    required int siteId,
    required String date,
    required Map<int, int> bpByPartner,
    String note = '',
  }) async {
    if (l.site(siteId) == null) throw const LedgerError('Choose a site.');
    if (date.isEmpty) throw const LedgerError('Choose a date.');
    final lines = <ShareLine>[
      for (final p in l.data.partners)
        if ((bpByPartner[p.id] ?? 0) > 0)
          ShareLine(partnerId: p.id, bp: bpByPartner[p.id]!),
    ];
    final total = lines.fold<int>(0, (a, x) => a + x.bp);
    if (total != 10000) {
      throw const LedgerError('Shares must total exactly 100%.');
    }
    _checkVersionDate(l, siteId, date);
    final first = l.versionsOf(siteId).isEmpty;
    await repo.insertVersion(ShareVersion(
      id: 0,
      siteId: siteId,
      effectiveFrom: date,
      note: note.trim().isNotEmpty
          ? note.trim()
          : (first ? 'Site started' : 'Shares changed'),
      lines: lines,
    ));
  }

  Future<void> addIncomeExpense(
    Ledger l, {
    required int siteId,
    required String date,
    required int income,
    required int expense,
    String note = '',
    int? plannedId,
  }) async {
    if (l.site(siteId) == null) throw const LedgerError('Choose a site.');
    if (income <= 0 && expense <= 0) {
      throw const LedgerError('Enter an income or an expense amount.');
    }
    if (income < 0 || expense < 0) {
      throw const LedgerError('Amounts cannot be negative.');
    }
    if (date.isEmpty) throw const LedgerError('Choose a date.');
    final v = l.versionAt(siteId, date);
    if (v == null) {
      throw const LedgerError(
          'This site has no shares in force on that date. Set shares or pick a later date.');
    }
    await repo.insertEntries([
      Entry(
        siteId: siteId,
        date: date,
        kind: EntryKind.incomeExpense,
        income: income,
        expense: expense,
        note: note.trim(),
        allocations: allocateIncomeExpense(income, expense, v.lines),
      ),
    ], deletePlannedId: plannedId);
  }

  Future<void> addMoney(
    Ledger l, {
    required int siteId,
    required int partnerId,
    required String date,
    required int amount,
    String note = '',
  }) async {
    if (l.site(siteId) == null) throw const LedgerError('Choose a site.');
    if (l.partner(partnerId) == null) {
      throw const LedgerError('Choose a partner.');
    }
    if (amount <= 0) throw const LedgerError('Enter an amount above zero.');
    if (date.isEmpty) throw const LedgerError('Choose a date.');
    if (!l.everOn(siteId, partnerId)) {
      throw const LedgerError('This partner is not on that site.');
    }
    await repo.insertEntries([
      Entry(
        siteId: siteId,
        date: date,
        kind: EntryKind.addMoney,
        partnerId: partnerId,
        note: note.trim(),
        allocations: [Allocation(partnerId: partnerId, amount: amount)],
      ),
    ]);
  }

  /// Moves a partner's money between two sites as a linked pair of entries.
  /// The partner may go negative on the source site: that is a valid state.
  Future<void> transfer(
    Ledger l, {
    required int partnerId,
    required int fromSiteId,
    required int toSiteId,
    required String date,
    required int amount,
    String note = '',
  }) async {
    if (l.partner(partnerId) == null) {
      throw const LedgerError('Choose a partner.');
    }
    if (fromSiteId == toSiteId) {
      throw const LedgerError('Choose two different sites.');
    }
    if (!l.everOn(fromSiteId, partnerId) || !l.everOn(toSiteId, partnerId)) {
      throw const LedgerError(
          'The partner needs to be on both sites to transfer.');
    }
    if (amount <= 0) throw const LedgerError('Enter an amount above zero.');
    if (date.isEmpty) throw const LedgerError('Choose a date.');
    await repo.insertEntries([
      Entry(
        siteId: fromSiteId,
        date: date,
        kind: EntryKind.transferOut,
        partnerId: partnerId,
        otherSiteId: toSiteId,
        note: note.trim(),
        allocations: [Allocation(partnerId: partnerId, amount: -amount)],
      ),
      Entry(
        siteId: toSiteId,
        date: date,
        kind: EntryKind.transferIn,
        partnerId: partnerId,
        otherSiteId: fromSiteId,
        note: note.trim(),
        allocations: [Allocation(partnerId: partnerId, amount: amount)],
      ),
    ], group: true);
  }

  /// The new partner takes the leaving partner's share and full balance on the
  /// site (including a negative one). Any payment between them is outside the
  /// app.
  Future<void> replacePartner(
    Ledger l, {
    required int siteId,
    required int leavingId,
    required int newId,
    required String date,
  }) async {
    final versions = l.versionsOf(siteId);
    if (versions.isEmpty) {
      throw const LedgerError('This site has no shares yet.');
    }
    final last = versions.last;
    if (!last.lines.any((x) => x.partnerId == leavingId)) {
      throw const LedgerError('Choose a leaving partner who is on this site.');
    }
    if (l.partner(newId) == null) {
      throw const LedgerError('Choose a new partner.');
    }
    if (last.lines.any((x) => x.partnerId == newId)) {
      throw const LedgerError('The new partner is already on this site.');
    }
    if (date.isEmpty) throw const LedgerError('Choose a date.');
    _checkVersionDate(l, siteId, date);
    final balance = l.balanceOf(siteId, leavingId).balance;
    final leaving = l.partnerName(leavingId);
    final incoming = l.partnerName(newId);
    await repo.insertEntries(
      [
        Entry(
          siteId: siteId,
          date: date,
          kind: EntryKind.replacement,
          note: balance == 0
              ? '$incoming took over from $leaving'
              : '$incoming took over from $leaving with balance ${formatSigned(balance)}',
          allocations: [
            Allocation(partnerId: leavingId, amount: -balance),
            Allocation(partnerId: newId, amount: balance),
          ],
        ),
      ],
      version: ShareVersion(
        id: 0,
        siteId: siteId,
        effectiveFrom: date,
        note: '$incoming replaced $leaving at the same share',
        lines: [
          for (final x in last.lines)
            ShareLine(
                partnerId: x.partnerId == leavingId ? newId : x.partnerId,
                bp: x.bp),
        ],
      ),
    );
  }

  /// Adds an opposite entry dated today and marks the original as reversed.
  /// Both sides of a transfer are reversed together.
  Future<void> reverse(Ledger l, int entryId) async {
    final matches = l.data.entries.where((e) => e.id == entryId).toList();
    if (matches.isEmpty) throw const LedgerError('Entry not found.');
    final target = matches.first;
    if (target.kind == EntryKind.replacement) {
      throw const LedgerError('A partner replacement cannot be reversed.');
    }
    if (!target.canReverse) {
      throw const LedgerError('This entry is already reversed.');
    }
    final originals = target.groupId == null
        ? [target]
        : l.data.entries
            .where((e) => e.groupId == target.groupId && e.canReverse)
            .toList();
    await repo.insertEntries([
      for (final e in originals)
        Entry(
          siteId: e.siteId,
          date: l.today,
          kind: e.kind,
          income: -e.income,
          expense: -e.expense,
          partnerId: e.partnerId,
          otherSiteId: e.otherSiteId,
          groupId: e.groupId,
          reversesId: e.id,
          note: e.note,
          allocations: [
            for (final a in e.allocations)
              Allocation(
                partnerId: a.partnerId,
                amount: -a.amount,
                income: -a.income,
                expense: -a.expense,
              ),
          ],
        ),
    ]);
  }

  Future<void> addPlanned(
    Ledger l, {
    required int siteId,
    required String due,
    required bool isIncome,
    required int amount,
    String note = '',
  }) async {
    if (l.site(siteId) == null) throw const LedgerError('Choose a site.');
    if (amount <= 0) throw const LedgerError('Enter an amount above zero.');
    if (due.isEmpty) throw const LedgerError('Choose a due date.');
    await repo.insertPlanned(PlannedEntry(
      siteId: siteId,
      due: due,
      isIncome: isIncome,
      amount: amount,
      note: note.trim(),
    ));
  }

  Future<void> deletePlanned(int id) => repo.deletePlanned(id);

  Future<void> replaceAll(LedgerData data) => repo.replaceAll(data);
}
