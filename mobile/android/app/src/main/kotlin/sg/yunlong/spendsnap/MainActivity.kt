package sg.yunlong.spendsnap

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // Today's tasks for the Home Screen widget (lib/today_widget.dart).
        MethodChannel(messenger, "spendsnap/widget").setMethodCallHandler { call, result ->
            if (call.method == "update") {
                TodayWidgetProvider.save(applicationContext, call.arguments as? String ?: "")
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        // The share sheet for a picture or a backup (lib/share.dart).
        MethodChannel(messenger, "spendsnap/share").setMethodCallHandler { call, result ->
            if (call.method == "file") {
                result.success(shareFile(call.arguments as? String))
            } else {
                result.notImplemented()
            }
        }
    }

    /** Opens Android's share sheet for a file the app just wrote to its cache. */
    private fun shareFile(path: String?): Boolean {
        if (path == null) return false
        return try {
            val file = File(path)
            val uri = FileProvider.getUriForFile(this, "$packageName.share", file)
            val mime = when {
                file.name.endsWith(".png") -> "image/png"
                file.name.endsWith(".json") -> "application/json"
                else -> "*/*"
            }
            val send = Intent(Intent.ACTION_SEND).apply {
                type = mime
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(send, null))
            true
        } catch (e: Exception) {
            false
        }
    }
}
