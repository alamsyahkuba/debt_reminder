#!/usr/bin/env bash
set -euo pipefail

APK="${1:?Usage: verify_apk.sh <apk> <version-name> <build-number> [package]}"
EXPECTED_VERSION_NAME="${2:?}"
EXPECTED_BUILD_NUMBER="${3:?}"
PACKAGE="${4:-com.debtreminder.app}"

if [[ ! -f "$APK" ]]; then
  echo "APK tidak ditemukan: $APK" >&2
  exit 1
fi

SDK_ROOT="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [[ -z "$SDK_ROOT" ]]; then
  echo "ANDROID_HOME/ANDROID_SDK_ROOT tidak diset." >&2
  exit 1
fi

AAPT="$(find "$SDK_ROOT/build-tools" -type f -name aapt 2>/dev/null | sort -V | tail -1)"
APKSIGNER="$(find "$SDK_ROOT/build-tools" -type f -name apksigner 2>/dev/null | sort -V | tail -1)"
if [[ -z "$AAPT" || -z "$APKSIGNER" ]]; then
  echo "aapt/apksigner tidak ditemukan di $SDK_ROOT/build-tools." >&2
  exit 1
fi

BADGING="$("$AAPT" dump badging "$APK")"
echo "$BADGING" | grep -Fq "package: name='$PACKAGE'" || {
  echo "Package bukan $PACKAGE." >&2
  exit 1
}
echo "$BADGING" | grep -Fq "versionCode='$EXPECTED_BUILD_NUMBER'" || {
  echo "versionCode bukan $EXPECTED_BUILD_NUMBER." >&2
  exit 1
}
echo "$BADGING" | grep -Fq "versionName='$EXPECTED_VERSION_NAME'" || {
  echo "versionName bukan $EXPECTED_VERSION_NAME." >&2
  exit 1
}

"$AAPT" dump permissions "$APK" | grep -Fq "android.permission.INTERNET" || {
  echo "Izin INTERNET tidak ada di APK." >&2
  exit 1
}

"$APKSIGNER" verify --print-certs "$APK" >/dev/null
CERT="$("$APKSIGNER" verify --print-certs "$APK" | grep -F 'Signer #1 certificate SHA-256 digest' | head -1 || true)"

if [[ -n "${SUPABASE_URL:-}" ]]; then
  HOST="${SUPABASE_URL#*://}"
  HOST="${HOST%%/*}"
  if ! unzip -p "$APK" lib/arm64-v8a/libapp.so 2>/dev/null | grep -F "$HOST" >/dev/null; then
    echo "Host Supabase $HOST tidak ditemukan di libapp.so." >&2
    exit 1
  fi
  echo "Supabase host tertanam: $HOST"
fi

echo "APK valid: $PACKAGE $EXPECTED_VERSION_NAME+$EXPECTED_BUILD_NUMBER"
if [[ -n "$CERT" ]]; then
  echo "$CERT"
fi
