import 'package:sqlite3/sqlite3.dart';

import '../domain/ledger_repository.dart';
import '../domain/models.dart';

/// SQLite storage in one local file. Money is INTEGER paise, shares are
/// INTEGER basis points, dates are TEXT (yyyy-MM-dd).
class SqliteLedgerRepository implements LedgerRepository {
  final Database db;

  SqliteLedgerRepository(this.db) {
    _migrate();
  }

  factory SqliteLedgerRepository.open(String path) =>
      SqliteLedgerRepository(sqlite3.open(path));

  void close() => db.dispose();

  void _migrate() {
    db.execute('PRAGMA foreign_keys = ON');
    if (db.userVersion >= 1) return;
    db.execute('''
      CREATE TABLE partners (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        is_company INTEGER NOT NULL DEFAULT 0
      )''');
    db.execute('''
      CREATE TABLE sites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        location TEXT NOT NULL DEFAULT '',
        start_date TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT ''
      )''');
    db.execute('''
      CREATE TABLE share_versions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        site_id INTEGER NOT NULL REFERENCES sites(id),
        effective_from TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )''');
    db.execute('''
      CREATE TABLE share_lines (
        version_id INTEGER NOT NULL REFERENCES share_versions(id),
        partner_id INTEGER NOT NULL REFERENCES partners(id),
        bp INTEGER NOT NULL,
        position INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (version_id, partner_id)
      )''');
    db.execute('''
      CREATE TABLE entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        site_id INTEGER NOT NULL REFERENCES sites(id),
        date TEXT NOT NULL,
        kind TEXT NOT NULL,
        income INTEGER NOT NULL DEFAULT 0,
        expense INTEGER NOT NULL DEFAULT 0,
        partner_id INTEGER,
        other_site_id INTEGER,
        group_id INTEGER,
        reverses_id INTEGER,
        reversed_by_id INTEGER,
        note TEXT NOT NULL DEFAULT ''
      )''');
    db.execute('''
      CREATE TABLE allocations (
        entry_id INTEGER NOT NULL REFERENCES entries(id),
        partner_id INTEGER NOT NULL REFERENCES partners(id),
        amount INTEGER NOT NULL,
        income INTEGER NOT NULL DEFAULT 0,
        expense INTEGER NOT NULL DEFAULT 0,
        position INTEGER NOT NULL DEFAULT 0
      )''');
    db.execute('''
      CREATE TABLE planned (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        site_id INTEGER NOT NULL REFERENCES sites(id),
        due TEXT NOT NULL,
        is_income INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )''');
    db.execute('CREATE INDEX idx_entries_site ON entries(site_id, date)');
    db.execute('CREATE INDEX idx_alloc_entry ON allocations(entry_id)');
    db.userVersion = 1;
  }

  T _tx<T>(T Function() body) {
    db.execute('BEGIN IMMEDIATE');
    try {
      final result = body();
      db.execute('COMMIT');
      return result;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  Future<LedgerData> load() async {
    final partners = [
      for (final r in db.select('SELECT * FROM partners ORDER BY id'))
        Partner(
          id: r['id'] as int,
          name: r['name'] as String,
          phone: r['phone'] as String,
          notes: r['notes'] as String,
          isCompany: (r['is_company'] as int) != 0,
        ),
    ];
    final sites = [
      for (final r in db.select('SELECT * FROM sites ORDER BY id'))
        Site(
          id: r['id'] as int,
          name: r['name'] as String,
          location: r['location'] as String,
          startDate: r['start_date'] as String,
          notes: r['notes'] as String,
        ),
    ];
    final lines = <int, List<ShareLine>>{};
    for (final r in db.select(
        'SELECT * FROM share_lines ORDER BY version_id, position, partner_id')) {
      lines.putIfAbsent(r['version_id'] as int, () => []).add(
          ShareLine(partnerId: r['partner_id'] as int, bp: r['bp'] as int));
    }
    final versions = [
      for (final r in db.select('SELECT * FROM share_versions ORDER BY id'))
        ShareVersion(
          id: r['id'] as int,
          siteId: r['site_id'] as int,
          effectiveFrom: r['effective_from'] as String,
          note: r['note'] as String,
          lines: lines[r['id'] as int] ?? const [],
        ),
    ];
    final allocs = <int, List<Allocation>>{};
    for (final r in db
        .select('SELECT * FROM allocations ORDER BY entry_id, position')) {
      allocs.putIfAbsent(r['entry_id'] as int, () => []).add(Allocation(
            partnerId: r['partner_id'] as int,
            amount: r['amount'] as int,
            income: r['income'] as int,
            expense: r['expense'] as int,
          ));
    }
    final entries = [
      for (final r in db.select('SELECT * FROM entries ORDER BY id'))
        Entry(
          id: r['id'] as int,
          siteId: r['site_id'] as int,
          date: r['date'] as String,
          kind: kindFromCode(r['kind'] as String),
          income: r['income'] as int,
          expense: r['expense'] as int,
          partnerId: r['partner_id'] as int?,
          otherSiteId: r['other_site_id'] as int?,
          groupId: r['group_id'] as int?,
          reversesId: r['reverses_id'] as int?,
          reversedById: r['reversed_by_id'] as int?,
          note: r['note'] as String,
          allocations: allocs[r['id'] as int] ?? const [],
        ),
    ];
    final planned = [
      for (final r in db.select('SELECT * FROM planned ORDER BY id'))
        PlannedEntry(
          id: r['id'] as int,
          siteId: r['site_id'] as int,
          due: r['due'] as String,
          isIncome: (r['is_income'] as int) != 0,
          amount: r['amount'] as int,
          note: r['note'] as String,
        ),
    ];
    return LedgerData(
      partners: partners,
      sites: sites,
      versions: versions,
      entries: entries,
      planned: planned,
    );
  }

  // The private writers take an explicit id (restore) or null (new row).

  int _writePartner(Partner p, {int? id}) {
    db.execute(
        'INSERT INTO partners (id, name, phone, notes, is_company) VALUES (?, ?, ?, ?, ?)',
        [id, p.name, p.phone, p.notes, p.isCompany ? 1 : 0]);
    return db.lastInsertRowId;
  }

  int _writeSite(Site s, {int? id}) {
    db.execute(
        'INSERT INTO sites (id, name, location, start_date, notes) VALUES (?, ?, ?, ?, ?)',
        [id, s.name, s.location, s.startDate, s.notes]);
    return db.lastInsertRowId;
  }

  int _writeVersion(ShareVersion v, {int? id}) {
    db.execute(
        'INSERT INTO share_versions (id, site_id, effective_from, note) VALUES (?, ?, ?, ?)',
        [id, v.siteId, v.effectiveFrom, v.note]);
    final vid = db.lastInsertRowId;
    for (var i = 0; i < v.lines.length; i++) {
      db.execute(
          'INSERT INTO share_lines (version_id, partner_id, bp, position) VALUES (?, ?, ?, ?)',
          [vid, v.lines[i].partnerId, v.lines[i].bp, i]);
    }
    return vid;
  }

  int _writeEntry(Entry e, {int? id}) {
    db.execute(
        'INSERT INTO entries (id, site_id, date, kind, income, expense, partner_id, other_site_id, group_id, reverses_id, reversed_by_id, note) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          id,
          e.siteId,
          e.date,
          kindCode(e.kind),
          e.income,
          e.expense,
          e.partnerId,
          e.otherSiteId,
          e.groupId,
          e.reversesId,
          e.reversedById,
          e.note,
        ]);
    final eid = db.lastInsertRowId;
    for (var i = 0; i < e.allocations.length; i++) {
      final a = e.allocations[i];
      db.execute(
          'INSERT INTO allocations (entry_id, partner_id, amount, income, expense, position) VALUES (?, ?, ?, ?, ?, ?)',
          [eid, a.partnerId, a.amount, a.income, a.expense, i]);
    }
    return eid;
  }

  int _writePlanned(PlannedEntry p, {int? id}) {
    db.execute(
        'INSERT INTO planned (id, site_id, due, is_income, amount, note) VALUES (?, ?, ?, ?, ?, ?)',
        [id, p.siteId, p.due, p.isIncome ? 1 : 0, p.amount, p.note]);
    return db.lastInsertRowId;
  }

  @override
  Future<int> insertPartner(Partner partner) async => _writePartner(partner);

  @override
  Future<int> insertSite(Site site) async => _writeSite(site);

  @override
  Future<int> insertVersion(ShareVersion version) async =>
      _tx(() => _writeVersion(version));

  @override
  Future<List<int>> insertEntries(
    List<Entry> entries, {
    bool group = false,
    ShareVersion? version,
    int? deletePlannedId,
  }) async {
    return _tx(() {
      if (version != null) _writeVersion(version);
      final ids = <int>[];
      int? groupId;
      for (final e in entries) {
        final id = _writeEntry(e);
        if (group) {
          groupId ??= id;
          db.execute(
              'UPDATE entries SET group_id = ? WHERE id = ?', [groupId, id]);
        }
        if (e.reversesId != null) {
          db.execute('UPDATE entries SET reversed_by_id = ? WHERE id = ?',
              [id, e.reversesId]);
        }
        ids.add(id);
      }
      if (deletePlannedId != null) {
        db.execute('DELETE FROM planned WHERE id = ?', [deletePlannedId]);
      }
      return ids;
    });
  }

  @override
  Future<int> insertPlanned(PlannedEntry planned) async =>
      _writePlanned(planned);

  @override
  Future<void> deletePlanned(int id) async {
    db.execute('DELETE FROM planned WHERE id = ?', [id]);
  }

  @override
  Future<void> replaceAll(LedgerData data) async {
    _tx(() {
      for (final t in const [
        'allocations',
        'entries',
        'planned',
        'share_lines',
        'share_versions',
        'sites',
        'partners',
      ]) {
        db.execute('DELETE FROM $t');
      }
      for (final p in data.partners) {
        _writePartner(p, id: p.id);
      }
      for (final s in data.sites) {
        _writeSite(s, id: s.id);
      }
      for (final v in data.versions) {
        _writeVersion(v, id: v.id);
      }
      for (final e in data.entries) {
        _writeEntry(e, id: e.id);
      }
      for (final p in data.planned) {
        _writePlanned(p, id: p.id);
      }
    });
  }
}
