import 'models.dart';

/// Storage boundary. The app ships with a SQLite implementation; tests use the
/// in-memory one. Swap in Drift or a server later without touching the rest.
abstract class LedgerRepository {
  Future<LedgerData> load();

  Future<int> insertPartner(Partner partner);

  Future<int> insertSite(Site site);

  Future<int> insertVersion(ShareVersion version);

  /// Saves entries with their allocations in one transaction and returns the
  /// new ids in order.
  ///
  /// * [group]: link all the entries as one transfer (they share a group id).
  /// * [version]: also save this share version (used by partner replacement).
  /// * [deletePlannedId]: also remove this planned entry.
  /// * An entry with `reversesId` marks its original as reversed.
  Future<List<int>> insertEntries(
    List<Entry> entries, {
    bool group = false,
    ShareVersion? version,
    int? deletePlannedId,
  });

  Future<int> insertPlanned(PlannedEntry planned);

  Future<void> deletePlanned(int id);

  /// Replaces the whole ledger, keeping the ids in [data]. Used by restore,
  /// sample data and "erase everything".
  Future<void> replaceAll(LedgerData data);
}
