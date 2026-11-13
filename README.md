# Partner Ledger

Single-user desktop app for a real estate company to track how much each
partner has invested in each site, and how much they still need to add.
Built with Flutter for Windows; the same code runs on Android for testing.

> **Status:** this code was written without a Flutter toolchain available, so
> it has **not been compiled or run yet**. The ledger logic is a direct port of
> the tested web prototype, and `test/ledger_test.dart` checks it against the
> same figures. Expect to fix a few small compile or analyzer issues on the
> first build.

## First run

You need Flutter 3.22 or newer. For Windows builds you also need Visual Studio
with the "Desktop development with C++" workload.

```bash
# 1. Generate the Windows and Android runner folders (they are not in this zip).
#    This does not touch lib/ or pubspec.yaml.
flutter create --platforms=windows,android --project-name partner_ledger .

# 2. If step 1 created test/widget_test.dart, delete it: it refers to a
#    counter app that does not exist here.

# 3. Get packages, run the tests, start the app.
flutter pub get
flutter test
flutter run -d windows        # or: flutter run -d <android-device>

# 4. Release build
flutter build windows
```

On first launch the ledger is empty. Use **Load sample data** on the dashboard
to get 3 example sites and 5 partners, or add your own partners and a site.

## How the ledger works

- Every site has **share versions**: the partners and their percentages from an
  effective date. Percentages are stored as basis points and must total 100%.
- An **income/expense entry** is split across partners using the version in
  force on the entry's date. The split is saved with the entry (allocations),
  so later share changes never rewrite history.
- **Add money** credits one partner on one site. More than the amount owed is
  an advance; less leaves part of the negative balance pending.
- A partner's **balance on a site** is the sum of their allocations there:
  money added + income share − expense share ± transfers. Negative means they
  need to add money.
- A **transfer** is a linked pair of entries moving one partner's money from
  one site to another.
- **Replace partner** starts a new share version with the new person in the
  same slot and moves the full balance (including a negative one) to them.
  Any payment between the two happens outside the app.
- Entries are **never edited or deleted**. A correction is a reversal: an
  opposite entry dated today, with the original marked as reversed.
- Money is integer paise. Leftover paise in a split go to the largest shares
  first, so the parts always add up exactly.
- A share change or replacement must be dated after the current version and on
  or after the site's last entry.

## Code layout

```
lib/
  main.dart                     opens the database, starts the app
  app.dart                      theme, navigation shell, keyboard shortcuts
  core/format.dart              Indian number format, dates, parsing
  domain/
    models.dart                 Partner, Site, ShareVersion, Entry, Allocation...
    ledger.dart                 split rule and every derived number (pure Dart)
    ledger_service.dart         all write operations with their validation
    ledger_repository.dart      storage interface
    sample_data.dart            example ledger
  data/
    sqlite_ledger_repository.dart   SQLite storage (package:sqlite3)
    memory_ledger_repository.dart   in-memory storage for tests
    backup_service.dart             JSON backup files
  presentation/
    cubits.dart                 LedgerCubit (state) and NavCubit (navigation)
    theme.dart                  colours, fonts and control styles from the HTML prototype
    widgets.dart                shared widgets
    dialogs.dart                add money, new entry, transfer, replace partner,
                                edit shares, new site, new partner, reverse
    pages_main.dart             dashboard, sites, site detail, partners, partner
    pages_more.dart             planner, reports, settings
test/ledger_test.dart           unit tests for the domain layer
```

The domain layer has no Flutter or database imports, so it can be tested and
reused on its own. Storage sits behind `LedgerRepository`; to move to Drift or
a server later, write another implementation of that interface.

## Where data lives

- Database: `partner_ledger.db` in the app support folder
  (`getApplicationSupportDirectory()`).
- Backups: `Documents/PartnerLedgerBackups/ledger-YYYYMMDD-HHMMSS.json`.
  One is written automatically the first time the app opens each day, and
  **Settings > Back up now** writes one on demand. Restore lists the ten most
  recent files in that folder.

## Keyboard shortcuts

| Keys | Action |
| --- | --- |
| Ctrl+N | New entry |
| Ctrl+M | Add money |
| Ctrl+T | Transfer |
| Esc | Close a dialog |

## Not built yet

- PDF and Excel export (Reports has "Copy as CSV" for now)
- Bill photo attachments
- Choosing a custom backup folder, or restoring from a file elsewhere
- Editing or archiving partners and sites
- A Windows installer (MSIX or Inno Setup)
