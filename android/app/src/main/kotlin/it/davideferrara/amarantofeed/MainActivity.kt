package it.davideferrara.amarantofeed

import android.content.res.Configuration
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val updateChannel = "it.davideferrara.amarantofeed/update"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updateChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "installApk") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("invalid_path", "APK path is missing", null)
                    return@setMethodCallHandler
                }
                installApk(path, result)
            }
    }

    private fun installApk(path: String, result: MethodChannel.Result) {
        val apk = File(path).canonicalFile
        val updatesDirectory = File(cacheDir, "updates").canonicalFile
        if (!apk.path.startsWith(updatesDirectory.path + File.separator) || !apk.isFile) {
            result.error("invalid_apk", "APK file is unavailable", null)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()) {
            val settings = Intent(
                android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName")
            )
            startActivity(settings)
            result.success("permission_required")
            return
        }

        val apkUri = FileProvider.getUriForFile(
            this,
            "$packageName.updateprovider",
            apk
        )
        val installIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(apkUri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            startActivity(installIntent)
            result.success("installer_opened")
        } catch (error: Exception) {
            result.error("installer_unavailable", error.message, null)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val dark = (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && dark) {
            splashScreen.setOnExitAnimationListener { splash ->
                // The OS entry frame only supports a solid color. Once handed
                // to us, use the same generated gradient as the app background.
                splash.setBackgroundResource(R.drawable.brand_launch_background)
                splash.animate().alpha(0f).setDuration(180L)
                    .withEndAction { splash.remove() }.start()
            }
        }
    }
}
