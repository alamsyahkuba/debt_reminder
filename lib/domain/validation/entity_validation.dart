import '../../core/errors/app_exception.dart';
import '../entities/debt_group.dart';

const int maxSafeRupiah = 9007199254740991;

String validateText(
  String value, {
  required String field,
  int minLength = 1,
  int maxLength = 200,
}) {
  final normalized = value.trim();

  if (normalized.length < minLength || normalized.length > maxLength) {
    throw AppException(
      code: AppErrorCode.validation,
      message: '$field harus memiliki panjang $minLength-$maxLength karakter.',
    );
  }

  return normalized;
}

String? validateOptionalText(
  String? value, {
  required String field,
  int maxLength = 2000,
}) {
  if (value == null) {
    return null;
  }

  final normalized = value.trim();
  if (normalized.isEmpty) {
    return null;
  }

  if (normalized.length > maxLength) {
    throw AppException(
      code: AppErrorCode.validation,
      message: '$field maksimal $maxLength karakter.',
    );
  }

  return normalized;
}

int validatePositiveRupiah(int amount, {required String field}) {
  if (amount <= 0 || amount > maxSafeRupiah) {
    throw AppException(
      code: AppErrorCode.validation,
      message: '$field harus berupa integer rupiah positif.',
    );
  }

  return amount;
}

int validateSortOrder(int value) {
  if (value < 0 || value > 1000000) {
    throw const AppException(
      code: AppErrorCode.validation,
      message: 'Urutan group harus antara 0 dan 1.000.000.',
    );
  }

  return value;
}

String? validateHexColor(String? value) {
  if (value == null) {
    return null;
  }

  final normalized = value.trim();
  if (normalized.isEmpty) {
    return null;
  }

  if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(normalized)) {
    throw const AppException(
      code: AppErrorCode.validation,
      message: 'Warna group harus menggunakan format #RRGGBB.',
    );
  }

  return normalized;
}

String? validateDebtGroupIcon(String? value) {
  if (value == null) {
    return null;
  }

  final normalized = value.trim();
  if (normalized.isEmpty) {
    return null;
  }

  if (!allowedDebtGroupIcons.contains(normalized)) {
    throw const AppException(
      code: AppErrorCode.validation,
      message: 'Ikon group tidak valid.',
    );
  }

  return normalized;
}

DateTime? normalizeDueDate(DateTime? value) {
  if (value == null) {
    return null;
  }

  return DateTime.utc(value.year, value.month, value.day);
}

DateTime normalizeTimestamp(DateTime value) => value.toUtc();

DateTime nowUtc() => DateTime.now().toUtc();
