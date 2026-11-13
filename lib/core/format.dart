/// Money is stored as integer paise. Percentages are stored as basis points
/// (100% = 10000). Dates are ISO strings (yyyy-MM-dd) so they sort as text.
library;

const List<String> monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _two(int n) => n.toString().padLeft(2, '0');

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

String todayIso() => isoDate(DateTime.now());

/// 2026-11-10 -> 10 Nov 2026
String formatDate(String iso) {
  final p = iso.split('-');
  if (p.length != 3) return iso;
  var m = (int.tryParse(p[1]) ?? 1) - 1;
  if (m < 0) m = 0;
  if (m > 11) m = 11;
  return '${p[2]} ${monthNames[m]} ${p[0]}';
}

/// Indian digit grouping: 12345678 -> 1,23,45,678
String groupIndian(int n) {
  final s = n.abs().toString();
  if (s.length <= 3) return s;
  final last = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${parts.join(',')},$last';
}

/// Unsigned amount; paise are shown only when they are not zero.
String formatNumber(int paise) {
  final a = paise.abs();
  final rupees = a ~/ 100;
  final p = a % 100;
  return p == 0 ? groupIndian(rupees) : '${groupIndian(rupees)}.${_two(p)}';
}

/// −₹8,75,000
String formatMoney(int paise) =>
    '${paise < 0 ? '−' : ''}₹${formatNumber(paise)}';

/// +₹5,75,000 / −₹8,75,000 / ₹0
String formatSigned(int paise) => paise == 0
    ? '₹0'
    : '${paise < 0 ? '−' : '+'}₹${formatNumber(paise)}';

/// Table cell: no currency sign, a dash for zero.
String formatCell(int paise) =>
    paise == 0 ? '—' : '${paise < 0 ? '−' : ''}${formatNumber(paise)}';

/// Reads "4,00,000.50" or "₹ 400000" as paise. Anything unreadable is 0.
int parseMoney(String text) {
  final clean = text.replaceAll(RegExp(r'[^0-9.]'), '');
  final v = double.tryParse(clean);
  if (v == null || !v.isFinite) return 0;
  return (v * 100).round();
}

/// Reads "12.5" as 1250 basis points. Anything unreadable or negative is 0.
int parsePercent(String text) {
  final v = double.tryParse(text.trim());
  if (v == null || !v.isFinite || v <= 0) return 0;
  return (v * 100).round();
}

/// 3500 -> 35%, 1250 -> 12.5%
String formatPercent(int bp) {
  final whole = bp ~/ 100;
  final frac = bp % 100;
  if (frac == 0) return '$whole%';
  var f = _two(frac);
  if (f.endsWith('0')) f = f.substring(0, 1);
  return '$whole.$f%';
}
