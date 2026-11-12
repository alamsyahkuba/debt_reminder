import '../../core/errors/app_exception.dart';

Never throwConflict(String entityName) {
  throw AppException(
    code: AppErrorCode.conflict,
    message: '$entityName telah berubah. Muat ulang data lalu coba lagi.',
  );
}

Never throwNotFound(String entityName) {
  throw AppException(
    code: AppErrorCode.notFound,
    message: '$entityName tidak ditemukan.',
  );
}

void ensureExpectedVersion({
  required int currentVersion,
  required int expectedVersion,
  required String entityName,
}) {
  if (currentVersion != expectedVersion) {
    throwConflict(entityName);
  }
}

String dateOnlyString(DateTime value) {
  final utc = value.toUtc();
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}-$month-$day';
}

String timestampString(DateTime value) => value.toUtc().toIso8601String();
