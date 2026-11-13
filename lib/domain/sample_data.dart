import 'ledger.dart';
import 'models.dart';

/// Example ledger: 3 sites, 5 partners. For trying the app, never real data.
LedgerData buildSampleData() {
  var nextId = 1;
  final partners = <Partner>[];
  final sites = <Site>[];
  final versions = <ShareVersion>[];
  final entries = <Entry>[];
  final planned = <PlannedEntry>[];

  // Lakhs to paise.
  int lakh(double x) => (x * 100000).round() * 100;

  int partner(String name, {bool company = false}) {
    final id = nextId++;
    partners.add(Partner(id: id, name: name, isCompany: company));
    return id;
  }

  int site(String name, String start, List<ShareLine> lines) {
    final id = nextId++;
    sites.add(Site(id: id, name: name, startDate: start));
    versions.add(ShareVersion(
      id: nextId++,
      siteId: id,
      effectiveFrom: start,
      note: 'Site started',
      lines: lines,
    ));
    return id;
  }

  List<ShareLine> linesOf(int siteId) =>
      versions.firstWhere((v) => v.siteId == siteId).lines;

  void add(int siteId, int partnerId, String date, double lakhs,
      [String note = '']) {
    entries.add(Entry(
      id: nextId++,
      siteId: siteId,
      date: date,
      kind: EntryKind.addMoney,
      partnerId: partnerId,
      note: note,
      allocations: [Allocation(partnerId: partnerId, amount: lakh(lakhs))],
    ));
  }

  void ie(int siteId, String date, double incLakhs, double expLakhs,
      String note) {
    entries.add(Entry(
      id: nextId++,
      siteId: siteId,
      date: date,
      kind: EntryKind.incomeExpense,
      income: lakh(incLakhs),
      expense: lakh(expLakhs),
      note: note,
      allocations: allocateIncomeExpense(
          lakh(incLakhs), lakh(expLakhs), linesOf(siteId)),
    ));
  }

  void plan(int siteId, String due, bool isIncome, double lakhs, String note) {
    planned.add(PlannedEntry(
      id: nextId++,
      siteId: siteId,
      due: due,
      isIncome: isIncome,
      amount: lakh(lakhs),
      note: note,
    ));
  }

  final rajesh = partner('Rajesh Patel');
  final meera = partner('Meera Shah');
  final kiran = partner('Kiran Desai');
  final anil = partner('Anil Joshi');
  final company = partner('Company', company: true);

  final green = site('Green Valley Plots', '2025-01-12', [
    ShareLine(partnerId: rajesh, bp: 3500),
    ShareLine(partnerId: meera, bp: 2500),
    ShareLine(partnerId: kiran, bp: 2000),
    ShareLine(partnerId: company, bp: 2000),
  ]);
  add(green, rajesh, '2025-01-20', 50, 'Opening investment');
  add(green, meera, '2025-01-20', 25, 'Opening investment');
  add(green, kiran, '2025-01-20', 31, 'Opening investment');
  add(green, company, '2025-01-20', 40, 'Opening investment');
  ie(green, '2025-02-10', 0, 223.5, 'Land purchase and registration');
  ie(green, '2026-08-30', 63, 0, 'Plot sales to date');
  ie(green, '2026-09-20', 0, 9.5, 'Land levelling');
  ie(green, '2026-10-02', 15, 0, 'Plot sale balance payment');
  add(green, rajesh, '2026-10-15', 10);
  ie(green, '2026-10-22', 0, 7.8, 'Road laying');
  add(green, meera, '2026-10-28', 5);
  ie(green, '2026-11-06', 12, 0, 'Plot booking instalment');
  ie(green, '2026-11-10', 0, 4.2, 'Boundary wall work');

  final river = site('Riverside Heights', '2025-06-01', [
    ShareLine(partnerId: rajesh, bp: 3000),
    ShareLine(partnerId: meera, bp: 3000),
    ShareLine(partnerId: anil, bp: 2000),
    ShareLine(partnerId: company, bp: 2000),
  ]);
  add(river, rajesh, '2025-06-10', 45, 'Opening investment');
  add(river, meera, '2025-06-10', 35, 'Opening investment');
  add(river, anil, '2025-06-10', 30, 'Opening investment');
  add(river, company, '2025-06-10', 25, 'Opening investment');
  ie(river, '2025-07-05', 0, 150, 'Land and approvals');
  ie(river, '2026-05-18', 0, 57.4, 'Foundation and plinth');
  ie(river, '2026-09-12', 70, 0, 'Flat bookings');

  final sunrise = site('Sunrise Enclave', '2026-02-01', [
    ShareLine(partnerId: kiran, bp: 4000),
    ShareLine(partnerId: anil, bp: 3000),
    ShareLine(partnerId: company, bp: 3000),
  ]);
  add(sunrise, kiran, '2026-02-05', 10, 'Opening investment');
  add(sunrise, anil, '2026-02-05', 12, 'Opening investment');
  add(sunrise, company, '2026-02-05', 20, 'Opening investment');
  ie(sunrise, '2026-03-01', 0, 60, 'Land advance');
  ie(sunrise, '2026-10-05', 25, 0, 'Booking advance');

  plan(green, '2026-11-25', false, 6, 'Drainage line');
  plan(river, '2026-12-05', false, 9, 'Lift installation');
  plan(green, '2026-12-15', true, 10, 'Plot booking instalment');
  plan(sunrise, '2026-12-20', true, 5, 'Flat booking');
  plan(green, '2027-01-10', false, 8, 'Compound gate and lighting');

  return LedgerData(
    partners: partners,
    sites: sites,
    versions: versions,
    entries: entries,
    planned: planned,
  );
}
