import 'package:intl/intl.dart';

final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');
final DateFormat _dateTimeFormatter = DateFormat('dd/MM/yyyy HH:mm');

/// Formats a date-only value as `dd/MM/yyyy` without timezone conversion.
String formatDate(DateTime value) => _dateFormatter.format(value);

/// Formats a timestamp in local time as `dd/MM/yyyy HH:mm`.
String formatDateTime(DateTime value) =>
    _dateTimeFormatter.format(value.toLocal());

/// Adds calendar months to a date-only value, clamping the day to the end of
/// the target month (31 Jan + 1 month = 28/29 Feb).
DateTime addMonthsClamped(DateTime value, int months) {
  final date = DateTime.utc(value.year, value.month, value.day);
  final totalMonths = date.year * 12 + (date.month - 1) + months;
  final year = totalMonths ~/ 12;
  final month = totalMonths % 12 + 1;
  final lastDay = DateTime.utc(year, month + 1, 0).day;
  return DateTime.utc(year, month, date.day > lastDay ? lastDay : date.day);
}
