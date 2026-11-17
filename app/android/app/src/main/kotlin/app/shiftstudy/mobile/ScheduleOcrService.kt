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
import org.json.JSONArray
import org.json.JSONObject
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
            val document = ScheduleOcrReader.extract(contentResolver, uri, name)
            result.data.putString(KEY_TEXT, document.text)
            result.data.putString(KEY_TOKENS, document.tokens.toJsonWithinLimit())
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
        const val KEY_TOKENS = "tokens"
        const val KEY_ERROR = "error"
    }
}

private const val MAX_OCR_LAYOUT_JSON_CHARS = 300_000

private fun List<OcrTextToken>.toJsonWithinLimit(): String = buildString {
    append('[')
    var count = 0
    for (token in this@toJsonWithinLimit) {
        val value = JSONObject()
            .put("text", token.text)
            .put("left", token.left.toDouble())
            .put("top", token.top.toDouble())
            .put("right", token.right.toDouble())
            .put("bottom", token.bottom.toDouble())
            .put("page", token.page)
            .toString()
        val extra = value.length + if (count == 0) 0 else 1
        if (length + extra + 1 > MAX_OCR_LAYOUT_JSON_CHARS) break
        if (count++ > 0) append(',')
        append(value)
    }
    append(']')
}
