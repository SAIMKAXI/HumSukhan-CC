package pk.humsukhan.humsukhan

import android.annotation.SuppressLint
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi

/**
 * A Quick Settings tile for environmental monitoring.
 *
 * The tile never starts audio capture itself. It reflects the state Dart last
 * wrote and hands the toggle back to the app, so there is exactly one owner of
 * the microphone and one place that can report why monitoring failed to start.
 */
@RequiresApi(Build.VERSION_CODES.N)
class MonitoringTileService : TileService() {

    override fun onStartListening() {
        super.onStartListening()
        refresh()
    }

    override fun onClick() {
        super.onClick()
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(EXTRA_TOGGLE_MONITORING, true)
        }
        // Collapses the shade and brings the app forward, where the toggle can
        // ask for the microphone permission and show a failure if it fails.
        startActivityAndCollapseCompat(intent)
    }

    @SuppressLint("StartActivityAndCollapseDeprecated")
    private fun startActivityAndCollapseCompat(intent: Intent) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(
                android.app.PendingIntent.getActivity(
                    this,
                    0,
                    intent,
                    android.app.PendingIntent.FLAG_IMMUTABLE or
                        android.app.PendingIntent.FLAG_UPDATE_CURRENT,
                )
            )
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }

    private fun refresh() {
        val tile: Tile = qsTile ?: return
        val active = getSharedPreferences(PREFS, MODE_PRIVATE)
            .getBoolean(KEY_ACTIVE, false)
        tile.state = if (active) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.label = getString(R.string.monitoring_tile_label)
        tile.updateTile()
    }

    companion object {
        /** The app's own preference file, written by MainActivity. */
        const val PREFS = "humsukhan_tile"

        /** Whether monitoring is running, as the app last reported it. */
        const val KEY_ACTIVE = "monitoring_active"

        /** Set on the launch intent when the tile asked for a toggle. */
        const val EXTRA_TOGGLE_MONITORING = "humsukhan.toggle_monitoring"

        /** Asks the platform to re-read the tile's state. */
        fun refreshTile(context: android.content.Context) {
            requestListeningState(
                context,
                android.content.ComponentName(
                    context,
                    MonitoringTileService::class.java,
                ),
            )
        }
    }
}
