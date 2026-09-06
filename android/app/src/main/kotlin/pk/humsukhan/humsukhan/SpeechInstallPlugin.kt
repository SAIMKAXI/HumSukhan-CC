package pk.humsukhan.humsukhan

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.speech.ModelDownloadListener
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executor

/**
 * Installs speech language packs using the device's own machinery.
 *
 * The product rule this exists to satisfy: a user who is missing an Urdu voice
 * presses one button and the phone fetches it. They are never told to open
 * Settings, find a speech engine, and hunt for a language list — an instruction
 * that is hard for anyone and unreasonable for the users this app is for.
 *
 * Two very different platform paths hide behind one Dart interface:
 *
 *  - Recognition, on Android 13+, has a real in-process API. We call
 *    [SpeechRecognizer.triggerModelDownload] and, on Android 14+, receive
 *    genuine progress. The user never leaves the app.
 *  - Synthesis has no such API at any level. The only sanctioned route is the
 *    engine's own installer activity, so we launch it directly and treat the
 *    user's return as the cue to re-check. That is a hand-off, reported as
 *    such, not a dead end.
 */
class SpeechInstallPlugin(
    private val context: Context,
    private val activityProvider: () -> Activity?,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val main = Handler(Looper.getMainLooper())
    private val mainExecutor = Executor { command -> main.post(command) }
    private var events: EventChannel.EventSink? = null
    private var recognizer: SpeechRecognizer? = null

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        events = sink
    }

    override fun onCancel(arguments: Any?) {
        events = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "canInstall" -> result.success(canInstall(call.argument<String>("facility")))
            "installTts" -> installTts(call.argument<String>("locale"), result)
            "installStt" -> installStt(call.argument<String>("locale"), result)
            "sttLocales" -> sttLocales(result)
            else -> result.notImplemented()
        }
    }

    /** Whether offering the flow at all would be honest on this device. */
    private fun canInstall(facility: String?): Boolean = when (facility) {
        "tts" -> installerIntent().resolveActivity(context.packageManager) != null
        "stt" -> Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
        else -> false
    }

    private fun installerIntent() = Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA)

    /**
     * Launches the speech engine's language installer.
     *
     * Reported as a hand-off rather than a completion: nothing is installed
     * until the user acts, and Dart re-probes the engine when the app resumes
     * rather than believing this call.
     */
    private fun installTts(locale: String?, result: MethodChannel.Result) {
        val activity = activityProvider()
        if (activity == null) {
            result.error("no_activity", "No activity is attached.", null)
            return
        }
        val intent = installerIntent().apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            // Advisory. Engines that honour it open on the right language;
            // engines that ignore it still open a usable list.
            locale?.let { putExtra(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, it) }
        }
        if (intent.resolveActivity(context.packageManager) == null) {
            result.error("unsupported", "No installer on this device.", null)
            return
        }
        try {
            activity.startActivity(intent)
            result.success("handedOff")
        } catch (error: Exception) {
            result.error("launch_failed", error.message, null)
        }
    }

    /**
     * Downloads the on-device recognition model, in the app, with progress
     * where the platform provides it.
     */
    private fun installStt(locale: String?, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.error("unsupported", "Needs Android 13 or newer.", null)
            return
        }
        if (locale.isNullOrBlank()) {
            result.error("invalid", "No locale given.", null)
            return
        }
        if (!SpeechRecognizer.isOnDeviceRecognitionAvailable(context)) {
            result.error("unsupported", "No on-device recogniser.", null)
            return
        }

        main.post {
            try {
                val recogniser = SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
                recognizer?.destroy()
                recognizer = recogniser
                val intent = recognitionIntent(locale)

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    recogniser.triggerModelDownload(
                        intent,
                        mainExecutor,
                        object : ModelDownloadListener {
                            override fun onProgress(completedPercent: Int) {
                                send(mapOf("state" to "downloading", "progress" to completedPercent / 100.0))
                            }

                            override fun onSuccess() {
                                send(mapOf("state" to "completed"))
                                release()
                            }

                            // The download was accepted but will run later. The
                            // user is told it is queued rather than being shown
                            // a bar that never moves.
                            override fun onScheduled() {
                                send(mapOf("state" to "scheduled"))
                            }

                            override fun onError(error: Int) {
                                send(mapOf("state" to "failed", "code" to error))
                                release()
                            }
                        },
                    )
                } else {
                    // Android 13 accepts the request but reports nothing back.
                    // Dart polls the locale list instead of inventing progress.
                    recogniser.triggerModelDownload(intent)
                    send(mapOf("state" to "scheduled"))
                }
                result.success("started")
            } catch (error: Exception) {
                release()
                result.error("trigger_failed", error.message, null)
            }
        }
    }

    /** The locales the on-device recogniser already has models for. */
    private fun sttLocales(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            !SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
        ) {
            result.success(emptyList<String>())
            return
        }
        main.post {
            var settled = false
            val recogniser = try {
                SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
            } catch (error: Exception) {
                result.success(emptyList<String>())
                return@post
            }
            // The callback is not guaranteed to fire. Without this the Dart
            // side would await a future that never completes — a spinner with
            // no end, which the product forbids outright.
            val timeout = Runnable {
                if (!settled) {
                    settled = true
                    recogniser.destroy()
                    result.success(emptyList<String>())
                }
            }
            main.postDelayed(timeout, 4_000)

            try {
                recogniser.checkRecognitionSupport(
                    recognitionIntent(null),
                    mainExecutor,
                    object : RecognitionSupportCallback {
                        override fun onSupportResult(support: RecognitionSupport) {
                            if (settled) return
                            settled = true
                            main.removeCallbacks(timeout)
                            recogniser.destroy()
                            result.success(
                                (support.installedOnDeviceLanguages +
                                    support.supportedOnDeviceLanguages).distinct(),
                            )
                        }

                        override fun onError(error: Int) {
                            if (settled) return
                            settled = true
                            main.removeCallbacks(timeout)
                            recogniser.destroy()
                            result.success(emptyList<String>())
                        }
                    },
                )
            } catch (error: Exception) {
                if (!settled) {
                    settled = true
                    main.removeCallbacks(timeout)
                    recogniser.destroy()
                    result.success(emptyList<String>())
                }
            }
        }
    }

    private fun recognitionIntent(locale: String?): Intent =
        Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            locale?.let {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, it)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, it)
            }
        }

    private fun send(payload: Map<String, Any?>) {
        main.post { events?.success(payload) }
    }

    private fun release() {
        main.post {
            recognizer?.destroy()
            recognizer = null
        }
    }

    /** Releases the recogniser when the engine goes away. */
    fun dispose() {
        release()
        events = null
    }

    companion object {
        const val METHOD_CHANNEL = "pk.humsukhan/speech_install"
        const val EVENT_CHANNEL = "pk.humsukhan/speech_install_events"
    }
}
