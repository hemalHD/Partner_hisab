import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:partner_ledger/core/format.dart';
import 'package:partner_ledger/data/memory_ledger_repository.dart';
import 'package:partner_ledger/domain/ledger.dart';
import 'package:partner_ledger/domain/ledger_service.dart';
import 'package:partner_ledger/domain/models.dart';
import 'package:partner_ledger/domain/sample_data.dart';

const today = '2026-11-12';

int lakh(double x) => (x * 100000).round() * 100;

void main() {
  group('format', () {
    test('Indian grouping and signs', () {
      expect(formatMoney(lakh(338)), '₹3,38,00,000');
      expect(formatMoney(-87500000), '−₹8,75,000');
      expect(formatSigned(57500000), '+₹5,75,000');
      expect(formatSigned(0), '₹0');
      expect(formatNumber(100001), '1,000.01');
      expect(formatCell(0), '—');
      expect(formatNumber(99900), '999');
    });
    test('parsing', () {
      expect(parseMoney('4,00,000'), 40000000);
      expect(parseMoney('₹ 1,000.01'), 100001);
      expect(parseMoney('abc'), 0);
      expect(parsePercent('12.5'), 1250);
      expect(formatPercent(1250), '12.5%');
      expect(formatPercent(3500), '35%');
      expect(formatDate('2026-11-10'), '10 Nov 2026');
    });
  });

  group('splitAmount', () {
    const lines = [
      ShareLine(partnerId: 1, bp: 3500),
      ShareLine(partnerId: 2, bp: 2500),
      ShareLine(partnerId: 3, bp: 2000),
      ShareLine(partnerId: 4, bp: 2000),
    ];
    test('parts always add up, leftover goes to the largest share', () {
      expect(splitAmount(100001, lines), [35001, 25000, 20000, 20000]);
      for (final amount in [0, 1, 3, 99, 100001, 123456789]) {
        final parts = splitAmount(amount, lines);
        expect(parts.fold<int>(0, (a, b) => a + b), amount);
      }
    });
    test('equal shares break ties by partner id', () {
      const thirds = [
        ShareLine(partnerId: 7, bp: 3333),
        ShareLine(partnerId: 5, bp: 3334),
        ShareLine(partnerId: 6, bp: 3333),
      ];
      final parts = splitAmount(100, thirds);
      expect(parts.fold<int>(0, (a, b) => a + b), 100);
    });
  });

  group('sample ledger', () {
    final l = Ledger(buildSampleData(), today: today);
    int site(String name) => l.data.sites.firstWhere((s) => s.name == name).id;
    int partner(String name) =>
        l.data.partners.firstWhere((p) => p.name == name).id;

    test('partner balances on Green Valley Plots', () {
      final g = site('Green Valley Plots');
      expect(l.balanceOf(g, partner('Rajesh Patel')).balance, lakh(5.75));
      expect(l.balanceOf(g, partner('Meera Shah')).balance, -lakh(8.75));
      expect(l.balanceOf(g, partner('Kiran Desai')).balance, 0);
      expect(l.balanceOf(g, partner('Company')).balance, lakh(9));
      final m = l.balanceOf(g, partner('Meera Shah'));
      expect(m.added, lakh(30));
      expect(m.income, lakh(22.5));
      expect(m.expense, lakh(61.25));
    });

    test('site and overall totals', () {
      final g = l.totalsOf(site('Green Valley Plots'));
      expect(g.added, lakh(161));
      expect(g.income, lakh(90));
      expect(g.expense, lakh(245));
      expect(g.balance, lakh(6));
      expect(l.totalsOf(site('Riverside Heights')).balance, -lakh(2.4));
      expect(l.totalsOf(site('Sunrise Enclave')).balance, lakh(7));
      final needs = l.data.sites
          .fold<int>(0, (a, s) => a + l.needsOnSite(s.id));
      expect(needs, lakh(21.45));
    });

    test('statement running balance ends at the current balance', () {
      final g = site('Green Valley Plots');
      final rows = l.statement(partner('Meera Shah'), siteId: g);
      expect(rows.first.runningBalance, -lakh(8.75));
      expect(rows.first.amount, -lakh(1.05));
    });

    test('projection', () {
      final p = l.projection(site('Green Valley Plots'))!;
      expect(p.monthLabels, ['Nov 2026', 'Dec 2026', 'Jan 2027']);
      final meera =
          p.rows.firstWhere((r) => r.partnerId == partner('Meera Shah'));
      expect(meera.monthEnd, [-lakh(10.25), -lakh(7.75), -lakh(9.75)]);
      expect(meera.shortfall, lakh(10.25));
      expect(meera.shortfallDate, '2026-11-25');
      final kiran =
          p.rows.firstWhere((r) => r.partnerId == partner('Kiran Desai'));
      expect(kiran.shortfall, lakh(1.2));
      final rajesh =
          p.rows.firstWhere((r) => r.partnerId == partner('Rajesh Patel'));
      expect(rajesh.shortfall, 0);
    });

    test('backup round trip', () {
      final json = jsonDecode(jsonEncode(l.data.toJson()));
      final back = Ledger(
          LedgerData.fromJson(Map<String, dynamic>.from(json as Map)),
          today: today);
      final g = site('Green Valley Plots');
      expect(back.balanceOf(g, partner('Meera Shah')).balance, -lakh(8.75));
      expect(back.data.entries.length, l.data.entries.length);
    });
  });

  group('service', () {
    late MemoryLedgerRepository repo;
    late LedgerService service;
    Future<Ledger> load() async => Ledger(await repo.load(), today: today);
    late int green, river, rajesh, meera, anil;

    setUp(() async {
      repo = MemoryLedgerRepository(buildSampleData());
      service = LedgerService(repo);
      final l = await load();
      green = l.data.sites.firstWhere((s) => s.name == 'Green Valley Plots').id;
      river = l.data.sites.firstWhere((s) => s.name == 'Riverside Heights').id;
      rajesh = l.data.partners.firstWhere((p) => p.name == 'Rajesh Patel').id;
      meera = l.data.partners.firstWhere((p) => p.name == 'Meera Shah').id;
      anil = l.data.partners.firstWhere((p) => p.name == 'Anil Joshi').id;
    });

    test('add money clears a negative balance', () async {
      await service.addMoney(await load(),
          siteId: green, partnerId: meera, date: today, amount: lakh(8.75));
      expect((await load()).balanceOf(green, meera).balance, 0);
    });

    test('expense is split by share and can be reversed', () async {
      await service.addIncomeExpense(await load(),
          siteId: green, date: today, income: 0, expense: 100001);
      var l = await load();
      expect(l.balanceOf(green, rajesh).balance, lakh(5.75) - 35001);
      expect(l.balanceOf(green, meera).balance, -lakh(8.75) - 25000);
      final entry = l.entriesOf(green).first;
      await service.reverse(l, entry.id);
      l = await load();
      expect(l.balanceOf(green, rajesh).balance, lakh(5.75));
      expect(l.totalsOf(green).expense, lakh(245));
      expect(() => service.reverse(l, entry.id), throwsA(isA<LedgerError>()));
    });

    test('transfer keeps the partner total and reverses as a pair', () async {
      await service.transfer(await load(),
          partnerId: rajesh,
          fromSiteId: green,
          toSiteId: river,
          date: today,
          amount: lakh(2));
      var l = await load();
      expect(l.balanceOf(green, rajesh).balance, lakh(3.75));
      expect(l.balanceOf(river, rajesh).balance, lakh(5.78));
      final out = l.entriesOf(green).first;
      expect(out.groupId, isNotNull);
      await service.reverse(l, out.id);
      l = await load();
      expect(l.balanceOf(green, rajesh).balance, lakh(5.75));
      expect(l.balanceOf(river, rajesh).balance, lakh(3.78));
    });

    test('transfer needs the partner on both sites', () async {
      final l = await load();
      final sunrise =
          l.data.sites.firstWhere((s) => s.name == 'Sunrise Enclave').id;
      expect(
          () => service.transfer(l,
              partnerId: rajesh,
              fromSiteId: green,
              toSiteId: sunrise,
              date: today,
              amount: 100),
          throwsA(isA<LedgerError>()));
    });

    test('replacement hands over share and negative balance', () async {
      await service.replacePartner(await load(),
          siteId: green, leavingId: meera, newId: anil, date: today);
      final l = await load();
      expect(l.balanceOf(green, meera).balance, 0);
      expect(l.balanceOf(green, anil).balance, -lakh(8.75));
      expect(l.shareBp(green, anil), 2500);
      expect(l.shareBp(green, meera), 0);
      expect(l.totalsOf(green).balance, lakh(6));
      // Older entries keep the old split.
      expect(l.versionAt(green, '2026-01-01')!.lines.any((x) => x.partnerId == meera), true);
    });

    test('shares must total 100% and cannot be backdated', () async {
      final l = await load();
      expect(
          () => service.saveShares(l,
              siteId: green, date: today, bpByPartner: {rajesh: 5000, meera: 4000}),
          throwsA(isA<LedgerError>()));
      expect(
          () => service.saveShares(l,
              siteId: green,
              date: '2026-01-01',
              bpByPartner: {rajesh: 5000, meera: 5000}),
          throwsA(isA<LedgerError>()));
      await service.saveShares(l,
          siteId: green, date: today, bpByPartner: {rajesh: 5000, meera: 5000});
      final after = await load();
      expect(after.shareBp(green, rajesh), 5000);
      // Balances do not move when shares change.
      expect(after.balanceOf(green, meera).balance, -lakh(8.75));
    });

    test('entry before the site has shares is refused', () async {
      expect(
          () async => service.addIncomeExpense(await load(),
              siteId: green, date: '2024-01-01', income: 100, expense: 0),
          throwsA(isA<LedgerError>()));
    });

    test('entering a planned entry removes it from the plan', () async {
      var l = await load();
      final plan = l.plannedOf(siteId: green).first;
      await service.addIncomeExpense(l,
          siteId: green,
          date: today,
          income: plan.isIncome ? plan.amount : 0,
          expense: plan.isIncome ? 0 : plan.amount,
          plannedId: plan.id);
      l = await load();
      expect(l.plannedOf(siteId: green).any((p) => p.id == plan.id), false);
    });
  });
}
