/// Calendar-day arithmetic that stays correct across daylight-saving changes.
///
/// `Duration(days: n)` and `difference().inDays` count 24-hour blocks, so on
/// local DateTimes they drift by a day around a DST transition.
library;

/// Strips the time of day, keeping the local calendar date.
DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Returns local midnight [days] calendar days after [date] (negative = before).
DateTime addCalendarDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

/// Whole calendar days from [from] to [to]; negative when [to] is earlier.
int calendarDaysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}
