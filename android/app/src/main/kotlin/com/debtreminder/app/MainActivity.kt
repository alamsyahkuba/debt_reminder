package com.debtreminder.app

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.StatFs
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.debtreminder.app/installer",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canRequestPackageInstalls" -> {
                    result.success(if (canRequestPackageInstalls()) "allowed" else "denied")
                }

                "availableStorageBytes" -> {
                    result.success(availableStorageBytes())
                }

                "openInstallPermissionSettings" -> {
                    result.success(openInstallPermissionSettings())
                }

                "installApk" -> {
                    val apkPath = call.argument<String>("apkPath")
                    val expectedPackage = call.argument<String>("packageName")
                    val expectedVersion = call.argument<Int>("versionCode")
                    if (apkPath == null || expectedPackage == null || expectedVersion == null) {
                        result.success(installResult("invalid_package"))
                        return@setMethodCallHandler
                    }
                    result.success(
                        installApk(apkPath, expectedPackage, expectedVersion.toLong()),
                    )
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun canRequestPackageInstalls(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun availableStorageBytes(): Long? {
        return try {
            @Suppress("DEPRECATION")
            val stat = StatFs(cacheDir.absolutePath)
            stat.availableBytes
        } catch (_: Exception) {
            null
        }
    }

    private fun openInstallPermissionSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return true
        }

        return try {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
            )
            startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        }
    }

    private fun installApk(
        apkPath: String,
        expectedPackage: String,
        expectedVersion: Long,
    ): Map<String, Any?> {
        val file = File(apkPath)
        if (!file.isFile || file.length() == 0L) {
            return installResult("invalid_package", "File APK tidak ditemukan.")
        }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            @Suppress("DEPRECATION")
            PackageManager.GET_SIGNATURES
        }

        val archive = packageManager.getPackageArchiveInfo(apkPath, flags)
            ?: return installResult("invalid_package", "APK tidak dapat dibaca.")
        if (archive.packageName != expectedPackage) {
            return installResult("invalid_package", "Package APK tidak cocok.")
        }

        val archiveVersion = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            archive.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            archive.versionCode.toLong()
        }
        if (archiveVersion != expectedVersion) {
            return installResult("invalid_package", "Versi APK tidak cocok.")
        }

        val archiveSignature = signatureDigest(archive)
        val installedSignature = try {
            val installed = packageManager.getPackageInfo(packageName, flags)
            signatureDigest(installed)
        } catch (_: PackageManager.NameNotFoundException) {
            null
        }
        if (archiveSignature == null || archiveSignature != installedSignature) {
            return installResult(
                "signature_mismatch",
                "Tanda tangan APK tidak cocok dengan aplikasi terpasang.",
            )
        }

        if (!canRequestPackageInstalls()) {
            return installResult("permission_required")
        }

        return try {
            val uri = FileProvider.getUriForFile(
                this,
                "$packageName.fileprovider",
                file,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
            installResult("installer_opened")
        } catch (_: ActivityNotFoundException) {
            installResult("unavailable", "Installer Android tidak tersedia.")
        } catch (error: SecurityException) {
            installResult("failed", error.message ?: "Installer tidak dapat dibuka.")
        } catch (error: Exception) {
            installResult("failed", error.message ?: "Installer tidak dapat dibuka.")
        }
    }

    private fun signatureDigest(info: android.content.pm.PackageInfo): String? {
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.signingInfo?.apkContentsSigners
        } else {
            @Suppress("DEPRECATION")
            info.signatures
        } ?: return null
        if (signatures.isEmpty()) {
            return null
        }

        val digest = MessageDigest.getInstance("SHA-256")
        return digest.digest(signatures[0].toByteArray())
            .joinToString("") { "%02x".format(it) }
    }

    private fun installResult(
        status: String,
        message: String? = null,
    ): Map<String, Any?> {
        return mapOf(
            "status" to status,
            "message" to message,
        )
    }
}
