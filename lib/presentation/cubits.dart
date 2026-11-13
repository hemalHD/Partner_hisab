import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/backup_service.dart';
import '../domain/ledger.dart';
import '../domain/ledger_service.dart';
import '../domain/models.dart';
import '../domain/sample_data.dart';

enum Section { dashboard, sites, partners, planner, reports, settings }

/// Where the app is. A site or partner id opens that detail page.
class AppRoute {
  final Section section;
  final int? siteId;
  final int? partnerId;

  const AppRoute(this.section, {this.siteId, this.partnerId});
  const AppRoute.site(int id) : this(Section.sites, siteId: id);
  const AppRoute.partner(int id) : this(Section.partners, partnerId: id);
}

class NavCubit extends Cubit<AppRoute> {
  NavCubit() : super(const AppRoute(Section.dashboard));

  void go(AppRoute route) => emit(route);
  void section(Section s) => emit(AppRoute(s));
}

class LedgerState {
  final Ledger? ledger;
  final String? error;
  const LedgerState({this.ledger, this.error});
}

/// Holds the current [Ledger]. Every action saves through the service and then
/// reloads, so the screens always show numbers computed from what is stored.
/// Actions throw [LedgerError] for the dialogs to show.
class LedgerCubit extends Cubit<LedgerState> {
  final LedgerService service;
  final BackupService backups;

  LedgerCubit(this.service, this.backups) : super(const LedgerState());

  Ledger get _ledger {
    final l = state.ledger;
    if (l == null) throw const LedgerError('The ledger is still loading.');
    return l;
  }

  Future<void> init() async {
    try {
      await reload();
    } catch (e) {
      emit(LedgerState(error: 'Could not open the ledger: $e'));
      return;
    }
    try {
      await backups.autoBackup(_ledger.data);
    } catch (_) {
      // A failed automatic backup must not stop the app from opening.
    }
  }

  Future<void> reload() async => emit(LedgerState(ledger: await service.load()));

  Future<int> addPartner(
      {required String name, String phone = '', bool isCompany = false}) async {
    final id =
        await service.addPartner(name: name, phone: phone, isCompany: isCompany);
    await reload();
    return id;
  }

  Future<int> addSite(
      {required String name,
      String location = '',
      required String startDate}) async {
    final id = await service.addSite(
        name: name, location: location, startDate: startDate);
    await reload();
    return id;
  }

  Future<void> saveShares(
      {required int siteId,
      required String date,
      required Map<int, int> bpByPartner,
      String note = ''}) async {
    await service.saveShares(_ledger,
        siteId: siteId, date: date, bpByPartner: bpByPartner, note: note);
    await reload();
  }

  Future<void> addIncomeExpense(
      {required int siteId,
      required String date,
      required int income,
      required int expense,
      String note = '',
      int? plannedId}) async {
    await service.addIncomeExpense(_ledger,
        siteId: siteId,
        date: date,
        income: income,
        expense: expense,
        note: note,
        plannedId: plannedId);
    await reload();
  }

  Future<void> addMoney(
      {required int siteId,
      required int partnerId,
      required String date,
      required int amount,
      String note = ''}) async {
    await service.addMoney(_ledger,
        siteId: siteId,
        partnerId: partnerId,
        date: date,
        amount: amount,
        note: note);
    await reload();
  }

  Future<void> transfer(
      {required int partnerId,
      required int fromSiteId,
      required int toSiteId,
      required String date,
      required int amount,
      String note = ''}) async {
    await service.transfer(_ledger,
        partnerId: partnerId,
        fromSiteId: fromSiteId,
        toSiteId: toSiteId,
        date: date,
        amount: amount,
        note: note);
    await reload();
  }

  Future<void> replacePartner(
      {required int siteId,
      required int leavingId,
      required int newId,
      required String date}) async {
    await service.replacePartner(_ledger,
        siteId: siteId, leavingId: leavingId, newId: newId, date: date);
    await reload();
  }

  Future<void> reverse(int entryId) async {
    await service.reverse(_ledger, entryId);
    await reload();
  }

  Future<void> addPlanned(
      {required int siteId,
      required String due,
      required bool isIncome,
      required int amount,
      String note = ''}) async {
    await service.addPlanned(_ledger,
        siteId: siteId,
        due: due,
        isIncome: isIncome,
        amount: amount,
        note: note);
    await reload();
  }

  Future<void> deletePlanned(int id) async {
    await service.deletePlanned(id);
    await reload();
  }

  Future<BackupFile> backupNow() => backups.backupNow(_ledger.data);

  Future<void> restore(String path) async {
    final data = await backups.read(path);
    await service.replaceAll(data);
    await reload();
  }

  Future<void> loadSample() async {
    await service.replaceAll(buildSampleData());
    await reload();
  }

  Future<void> eraseAll() async {
    await service.replaceAll(const LedgerData());
    await reload();
  }
}
