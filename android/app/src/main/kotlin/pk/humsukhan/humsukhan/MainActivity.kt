package pk.humsukhan.humsukhan

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter engine and forwards one thing from the platform: whether
 * the app was launched by the Quick Settings tile asking to toggle monitoring.
 */
class MainActivity : FlutterActivity() {

    private var channel: MethodChannel? = null
    private var pendingToggle = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingToggle = pendingToggle ||
            intent.getBooleanExtra(MonitoringTileService.EXTRA_TOGGLE_MONITORING, false)

        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    // Consumed exactly once: a rebuild must not toggle again.
                    "consumeTileRequest" -> {
                        val requested = pendingToggle
                        pendingToggle = false
                        result.success(requested)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra(MonitoringTileService.EXTRA_TOGGLE_MONITORING, false)) {
            pendingToggle = true
            channel?.invokeMethod("tileRequested", null)
        }
    }

    companion object {
        private const val CHANNEL = "pk.humsukhan/quick_tile"
    }
}
