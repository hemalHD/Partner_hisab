/// Plain immutable models. No code generation.
library;

enum EntryKind { incomeExpense, addMoney, transferOut, transferIn, replacement }

const Map<EntryKind, String> _kindCodes = {
  EntryKind.incomeExpense: 'ie',
  EntryKind.addMoney: 'add',
  EntryKind.transferOut: 'tout',
  EntryKind.transferIn: 'tin',
  EntryKind.replacement: 'rep',
};

String kindCode(EntryKind k) => _kindCodes[k]!;

EntryKind kindFromCode(String code) => _kindCodes.entries
    .firstWhere((e) => e.value == code,
        orElse: () => const MapEntry(EntryKind.incomeExpense, 'ie'))
    .key;

class Partner {
  final int id;
  final String name;
  final String phone;
  final String notes;
  final bool isCompany;

  const Partner({
    required this.id,
    required this.name,
    this.phone = '',
    this.notes = '',
    this.isCompany = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'notes': notes,
        'isCompany': isCompany,
      };

  factory Partner.fromJson(Map<String, dynamic> j) => Partner(
        id: j['id'] as int,
        name: j['name'] as String,
        phone: (j['phone'] as String?) ?? '',
        notes: (j['notes'] as String?) ?? '',
        isCompany: (j['isCompany'] as bool?) ?? false,
      );
}

class Site {
  final int id;
  final String name;
  final String location;
  final String startDate;
  final String notes;

  const Site({
    required this.id,
    required this.name,
    this.location = '',
    required this.startDate,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'startDate': startDate,
        'notes': notes,
      };

  factory Site.fromJson(Map<String, dynamic> j) => Site(
        id: j['id'] as int,
        name: j['name'] as String,
        location: (j['location'] as String?) ?? '',
        startDate: j['startDate'] as String,
        notes: (j['notes'] as String?) ?? '',
      );
}

class ShareLine {
  final int partnerId;

  /// Basis points: 100% = 10000.
  final int bp;

  const ShareLine({required this.partnerId, required this.bp});

  Map<String, dynamic> toJson() => {'partnerId': partnerId, 'bp': bp};

  factory ShareLine.fromJson(Map<String, dynamic> j) =>
      ShareLine(partnerId: j['partnerId'] as int, bp: j['bp'] as int);
}

/// The percentages in force on a site from [effectiveFrom] until the next
/// version starts. Lines always total 10000.
class ShareVersion {
  final int id;
  final int siteId;
  final String effectiveFrom;
  final String note;
  final List<ShareLine> lines;

  const ShareVersion({
    required this.id,
    required this.siteId,
    required this.effectiveFrom,
    this.note = '',
    required this.lines,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'siteId': siteId,
        'effectiveFrom': effectiveFrom,
        'note': note,
        'lines': lines.map((l) => l.toJson()).toList(),
      };

  factory ShareVersion.fromJson(Map<String, dynamic> j) => ShareVersion(
        id: j['id'] as int,
        siteId: j['siteId'] as int,
        effectiveFrom: j['effectiveFrom'] as String,
        note: (j['note'] as String?) ?? '',
        lines: (j['lines'] as List)
            .map((e) => ShareLine.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// One partner's part of an entry, saved when the entry is made so that later
/// share changes never rewrite history. [amount] is the signed effect on the
/// partner's balance; [income] and [expense] are filled for income/expense
/// entries only.
class Allocation {
  final int partnerId;
  final int amount;
  final int income;
  final int expense;

  const Allocation({
    required this.partnerId,
    required this.amount,
    this.income = 0,
    this.expense = 0,
  });

  Map<String, dynamic> toJson() => {
        'partnerId': partnerId,
        'amount': amount,
        'income': income,
        'expense': expense,
      };

  factory Allocation.fromJson(Map<String, dynamic> j) => Allocation(
        partnerId: j['partnerId'] as int,
        amount: j['amount'] as int,
        income: (j['income'] as int?) ?? 0,
        expense: (j['expense'] as int?) ?? 0,
      );
}

class Entry {
  final int id;
  final int siteId;
  final String date;
  final EntryKind kind;
  final int income;
  final int expense;

  /// The partner for add money and transfers.
  final int? partnerId;

  /// The other site of a transfer.
  final int? otherSiteId;

  /// Shared by the two sides of a transfer.
  final int? groupId;

  /// Set on a reversal: the entry it cancels.
  final int? reversesId;

  /// Set on an original once it has been reversed.
  final int? reversedById;
  final String note;
  final List<Allocation> allocations;

  const Entry({
    this.id = 0,
    required this.siteId,
    required this.date,
    required this.kind,
    this.income = 0,
    this.expense = 0,
    this.partnerId,
    this.otherSiteId,
    this.groupId,
    this.reversesId,
    this.reversedById,
    this.note = '',
    required this.allocations,
  });

  bool get isReversal => reversesId != null;
  bool get isReversed => reversedById != null;
  bool get canReverse =>
      !isReversal && !isReversed && kind != EntryKind.replacement;

  Entry copyWith({int? id, int? groupId, int? reversedById}) => Entry(
        id: id ?? this.id,
        siteId: siteId,
        date: date,
        kind: kind,
        income: income,
        expense: expense,
        partnerId: partnerId,
        otherSiteId: otherSiteId,
        groupId: groupId ?? this.groupId,
        reversesId: reversesId,
        reversedById: reversedById ?? this.reversedById,
        note: note,
        allocations: allocations,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'siteId': siteId,
        'date': date,
        'kind': kindCode(kind),
        'income': income,
        'expense': expense,
        'partnerId': partnerId,
        'otherSiteId': otherSiteId,
        'groupId': groupId,
        'reversesId': reversesId,
        'reversedById': reversedById,
        'note': note,
        'allocations': allocations.map((a) => a.toJson()).toList(),
      };

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
        id: j['id'] as int,
        siteId: j['siteId'] as int,
        date: j['date'] as String,
        kind: kindFromCode(j['kind'] as String),
        income: (j['income'] as int?) ?? 0,
        expense: (j['expense'] as int?) ?? 0,
        partnerId: j['partnerId'] as int?,
        otherSiteId: j['otherSiteId'] as int?,
        groupId: j['groupId'] as int?,
        reversesId: j['reversesId'] as int?,
        reversedById: j['reversedById'] as int?,
        note: (j['note'] as String?) ?? '',
        allocations: (j['allocations'] as List)
            .map((e) => Allocation.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class PlannedEntry {
  final int id;
  final int siteId;
  final String due;
  final bool isIncome;
  final int amount;
  final String note;

  const PlannedEntry({
    this.id = 0,
    required this.siteId,
    required this.due,
    required this.isIncome,
    required this.amount,
    this.note = '',
  });

  int get signedAmount => isIncome ? amount : -amount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'siteId': siteId,
        'due': due,
        'isIncome': isIncome,
        'amount': amount,
        'note': note,
      };

  factory PlannedEntry.fromJson(Map<String, dynamic> j) => PlannedEntry(
        id: j['id'] as int,
        siteId: j['siteId'] as int,
        due: j['due'] as String,
        isIncome: j['isIncome'] as bool,
        amount: j['amount'] as int,
        note: (j['note'] as String?) ?? '',
      );
}

/// Everything in the ledger. Also the backup file format.
class LedgerData {
  final List<Partner> partners;
  final List<Site> sites;
  final List<ShareVersion> versions;
  final List<Entry> entries;
  final List<PlannedEntry> planned;

  const LedgerData({
    this.partners = const [],
    this.sites = const [],
    this.versions = const [],
    this.entries = const [],
    this.planned = const [],
  });

  bool get isEmpty => partners.isEmpty && sites.isEmpty;

  Map<String, dynamic> toJson() => {
        'format': 'partner-ledger',
        'formatVersion': 1,
        'partners': partners.map((e) => e.toJson()).toList(),
        'sites': sites.map((e) => e.toJson()).toList(),
        'versions': versions.map((e) => e.toJson()).toList(),
        'entries': entries.map((e) => e.toJson()).toList(),
        'planned': planned.map((e) => e.toJson()).toList(),
      };

  factory LedgerData.fromJson(Map<String, dynamic> j) {
    List<T> read<T>(String key, T Function(Map<String, dynamic>) f) =>
        ((j[key] as List?) ?? const [])
            .map((e) => f(Map<String, dynamic>.from(e as Map)))
            .toList();
    if (j['format'] != 'partner-ledger') {
      throw const FormatException('Not a Partner Ledger backup');
    }
    return LedgerData(
      partners: read('partners', Partner.fromJson),
      sites: read('sites', Site.fromJson),
      versions: read('versions', ShareVersion.fromJson),
      entries: read('entries', Entry.fromJson),
      planned: read('planned', PlannedEntry.fromJson),
    );
  }
}
