import '../domain/ledger_repository.dart';
import '../domain/models.dart';

/// Keeps the ledger in memory. Used by the unit tests; also handy for demos.
class MemoryLedgerRepository implements LedgerRepository {
  final List<Partner> _partners = [];
  final List<Site> _sites = [];
  final List<ShareVersion> _versions = [];
  final List<Entry> _entries = [];
  final List<PlannedEntry> _planned = [];
  int _nextId = 1;

  MemoryLedgerRepository([LedgerData? initial]) {
    if (initial != null) _set(initial);
  }

  void _set(LedgerData data) {
    _partners
      ..clear()
      ..addAll(data.partners);
    _sites
      ..clear()
      ..addAll(data.sites);
    _versions
      ..clear()
      ..addAll(data.versions);
    _entries
      ..clear()
      ..addAll(data.entries);
    _planned
      ..clear()
      ..addAll(data.planned);
    var max = 0;
    for (final id in [
      ..._partners.map((e) => e.id),
      ..._sites.map((e) => e.id),
      ..._versions.map((e) => e.id),
      ..._entries.map((e) => e.id),
      ..._planned.map((e) => e.id),
    ]) {
      if (id > max) max = id;
    }
    _nextId = max + 1;
  }

  @override
  Future<LedgerData> load() async => LedgerData(
        partners: List.of(_partners),
        sites: List.of(_sites),
        versions: List.of(_versions),
        entries: List.of(_entries),
        planned: List.of(_planned),
      );

  @override
  Future<int> insertPartner(Partner p) async {
    final id = _nextId++;
    _partners.add(Partner(
        id: id,
        name: p.name,
        phone: p.phone,
        notes: p.notes,
        isCompany: p.isCompany));
    return id;
  }

  @override
  Future<int> insertSite(Site s) async {
    final id = _nextId++;
    _sites.add(Site(
        id: id,
        name: s.name,
        location: s.location,
        startDate: s.startDate,
        notes: s.notes));
    return id;
  }

  @override
  Future<int> insertVersion(ShareVersion v) async {
    final id = _nextId++;
    _versions.add(ShareVersion(
        id: id,
        siteId: v.siteId,
        effectiveFrom: v.effectiveFrom,
        note: v.note,
        lines: v.lines));
    return id;
  }

  @override
  Future<List<int>> insertEntries(
    List<Entry> entries, {
    bool group = false,
    ShareVersion? version,
    int? deletePlannedId,
  }) async {
    if (version != null) await insertVersion(version);
    final ids = <int>[];
    int? groupId;
    for (final e in entries) {
      final id = _nextId++;
      if (group) groupId ??= id;
      _entries.add(e.copyWith(id: id, groupId: group ? groupId : null));
      final reverses = e.reversesId;
      if (reverses != null) {
        final i = _entries.indexWhere((x) => x.id == reverses);
        if (i >= 0) _entries[i] = _entries[i].copyWith(reversedById: id);
      }
      ids.add(id);
    }
    if (deletePlannedId != null) {
      _planned.removeWhere((p) => p.id == deletePlannedId);
    }
    return ids;
  }

  @override
  Future<int> insertPlanned(PlannedEntry p) async {
    final id = _nextId++;
    _planned.add(PlannedEntry(
        id: id,
        siteId: p.siteId,
        due: p.due,
        isIncome: p.isIncome,
        amount: p.amount,
        note: p.note));
    return id;
  }

  @override
  Future<void> deletePlanned(int id) async {
    _planned.removeWhere((p) => p.id == id);
  }

  @override
  Future<void> replaceAll(LedgerData data) async => _set(data);
}
