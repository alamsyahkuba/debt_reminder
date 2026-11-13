import 'package:intl/intl.dart';

final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');
final DateFormat _dateTimeFormatter = DateFormat('dd/MM/yyyy HH:mm');

/// Formats a date-only value as `dd/MM/yyyy` without timezone conversion.
String formatDate(DateTime value) => _dateFormatter.format(value);

/// Formats a timestamp in local time as `dd/MM/yyyy HH:mm`.
String formatDateTime(DateTime value) =>
    _dateTimeFormatter.format(value.toLocal());
