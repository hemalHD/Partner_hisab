import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/models.dart';

class BackupFile {
  final String path;
  final String name;
  final DateTime modified;
  const BackupFile(this.path, this.name, this.modified);
}

/// Writes the whole ledger as one JSON file per backup into [directory].
class BackupService {
  final Directory directory;
  const BackupService(this.directory);

  static String _two(int n) => n.toString().padLeft(2, '0');

  Future<BackupFile> backupNow(LedgerData data) async {
    await directory.create(recursive: true);
    final t = DateTime.now();
    final name = 'ledger-${t.year}${_two(t.month)}${_two(t.day)}-'
        '${_two(t.hour)}${_two(t.minute)}${_two(t.second)}.json';
    final file = File(p.join(directory.path, name));
    await file.writeAsString(jsonEncode(data.toJson()), flush: true);
    return BackupFile(file.path, name, t);
  }

  /// Backups in the folder, newest first.
  Future<List<BackupFile>> list() async {
    if (!await directory.exists()) return [];
    final out = <BackupFile>[];
    await for (final e in directory.list()) {
      if (e is File && e.path.toLowerCase().endsWith('.json')) {
        out.add(BackupFile(e.path, p.basename(e.path), await e.lastModified()));
      }
    }
    out.sort((a, b) => b.modified.compareTo(a.modified));
    return out;
  }

  Future<LedgerData> read(String path) async {
    final text = await File(path).readAsString();
    final json = jsonDecode(text);
    if (json is! Map) throw const FormatException('Not a Partner Ledger backup');
    return LedgerData.fromJson(Map<String, dynamic>.from(json));
  }

  /// Writes one backup per day, the first time the app opens with data.
  Future<void> autoBackup(LedgerData data) async {
    if (data.isEmpty) return;
    final t = DateTime.now();
    final prefix = 'ledger-${t.year}${_two(t.month)}${_two(t.day)}-';
    final existing = await list();
    if (existing.any((b) => b.name.startsWith(prefix))) return;
    await backupNow(data);
  }
}
