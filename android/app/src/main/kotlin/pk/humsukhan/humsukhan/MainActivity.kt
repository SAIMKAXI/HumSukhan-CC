package pk.humsukhan.humsukhan

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter engine and forwards one thing from the platform: whether
 * the app was launched by the Quick Settings tile asking to toggle monitoring.
 */
class MainActivity : FlutterActivity() {

    private var channel: MethodChannel? = null
    private var speechInstall: SpeechInstallPlugin? = null
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
                    // Written here rather than from Dart's own storage so both
                    // sides read the same file with the same encoding.
                    "publishActive" -> {
                        val active = call.arguments as? Boolean ?: false
                        getSharedPreferences(
                            MonitoringTileService.PREFS,
                            MODE_PRIVATE,
                        ).edit()
                            .putBoolean(MonitoringTileService.KEY_ACTIVE, active)
                            .apply()
                        MonitoringTileService.refreshTile(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // Speech language packs: the one place the app is allowed to ask the
        // operating system to fetch something on the user's behalf.
        val install = SpeechInstallPlugin(applicationContext) { this }
        speechInstall = install
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SpeechInstallPlugin.METHOD_CHANNEL,
        ).setMethodCallHandler(install)
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SpeechInstallPlugin.EVENT_CHANNEL,
        ).setStreamHandler(install)
    }

    /** Releases the on-device recogniser the install plugin may hold. */
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        speechInstall?.dispose()
        speechInstall = null
        channel = null
        super.cleanUpFlutterEngine(flutterEngine)
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
