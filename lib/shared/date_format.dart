const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "YYYY-MM-DD", the format the API expects for dates.
String dateParam(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// "12 Oct 2026" from "2026-10-12" (or a full ISO timestamp).
String prettyDate(String? raw) {
  if (raw == null) return '—';
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// One date when start and end are the same day, otherwise "12 Oct – 15 Oct 2026".
String prettyRange(String start, String end) {
  if (start == end) return prettyDate(start);
  final s = DateTime.tryParse(start);
  final e = DateTime.tryParse(end);
  if (s == null || e == null) return '$start – $end';
  if (s.year == e.year) {
    return '${s.day} ${_months[s.month - 1]} – ${e.day} ${_months[e.month - 1]} ${e.year}';
  }
  return '${prettyDate(start)} – ${prettyDate(end)}';
}

/// "5 min ago", "3 h ago", "2 d ago", or a date for anything older.
String timeAgo(String? raw) {
  if (raw == null) return '';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return '';
  final d = parsed.toLocal();
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}