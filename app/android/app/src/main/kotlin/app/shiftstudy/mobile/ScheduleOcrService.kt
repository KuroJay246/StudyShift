package app.shiftstudy.mobile

import android.app.Service
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Message
import android.os.Messenger
import android.util.Log
import com.google.mlkit.common.MlKit
import java.io.IOException

internal class ScheduleOcrService : Service() {
    private lateinit var worker: HandlerThread
    private lateinit var messenger: Messenger

    override fun onCreate() {
        super.onCreate()
        // The ML Kit initializer provider runs in the default app process, not
        // this isolated OCR process. Initialize its context here before use.
        MlKit.initialize(applicationContext)
        worker = HandlerThread("studyshift-schedule-ocr").apply { start() }
        messenger = Messenger(
            Handler(worker.looper) { request ->
                extract(request)
                true
            },
        )
    }

    override fun onBind(intent: Intent?): IBinder = messenger.binder

    override fun onDestroy() {
        worker.quitSafely()
        super.onDestroy()
    }

    private fun extract(request: Message) {
        val replyTo = request.replyTo ?: return
        val data = request.data
        val name = data.getString(KEY_NAME)
        val uri = data.getString(KEY_URI)?.let(Uri::parse)
        val result = Message.obtain(null, MESSAGE_RESULT)
        result.data = Bundle()
        try {
            if (name.isNullOrBlank() || uri?.scheme != "content") {
                throw IOException("The selected document could not be opened.")
            }
            result.data.putString(
                KEY_TEXT,
                ScheduleOcrReader.extract(contentResolver, uri, name),
            )
        } catch (error: Exception) {
            Log.w(TAG, "Schedule OCR failed (${error.javaClass.simpleName}).")
            result.data.putString(
                KEY_ERROR,
                "Text could not be read from this file. Try a clearer image or a smaller PDF.",
            )
        }
        runCatching { replyTo.send(result) }
    }

    companion object {
        private const val TAG = "StudyShiftOCR"
        const val MESSAGE_EXTRACT = 1
        const val MESSAGE_RESULT = 2
        const val KEY_URI = "uri"
        const val KEY_NAME = "name"
        const val KEY_TEXT = "text"
        const val KEY_ERROR = "error"
    }
}
