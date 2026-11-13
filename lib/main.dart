import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/backup_service.dart';
import 'data/sqlite_ledger_repository.dart';
import 'domain/ledger_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The database lives in the app's own data folder; backups go to Documents
  // so they are easy to find and copy.
  final support = await getApplicationSupportDirectory();
  await support.create(recursive: true);
  final repository =
      SqliteLedgerRepository.open(p.join(support.path, 'partner_ledger.db'));

  final documents = await getApplicationDocumentsDirectory();
  final backups =
      BackupService(Directory(p.join(documents.path, 'PartnerLedgerBackups')));

  runApp(LedgerApp(service: LedgerService(repository), backups: backups));
}
