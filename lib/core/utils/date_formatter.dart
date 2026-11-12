import 'package:intl/intl.dart';

final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');

/// Formats a date-only value as `dd/MM/yyyy` without timezone conversion.
String formatDate(DateTime value) => _dateFormatter.format(value);
