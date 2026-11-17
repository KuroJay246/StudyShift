package app.shiftstudy.mobile

import android.content.ContentResolver
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Rect
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.ParcelFileDescriptor
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.google.mlkit.vision.text.Text
import java.io.IOException
import java.util.concurrent.TimeUnit

internal object ScheduleOcrReader {
    private const val MAX_PAGES = 12
    private const val MAX_DIMENSION = 1800
    private const val MAX_TEXT_CHARS = 500_000

    fun extract(resolver: ContentResolver, uri: Uri, name: String): OcrDocument {
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        return try {
            val text = when (name.substringAfterLast('.', "").lowercase()) {
                "pdf" -> extractPdf(resolver, uri, recognizer)
                "png", "jpg", "jpeg", "webp", "bmp" -> extractImage(resolver, uri, recognizer)
                else -> throw IOException("Choose a PDF or a PNG, JPG, WebP or BMP image.")
            }
            OcrDocument(text.text.take(MAX_TEXT_CHARS), text.tokens)
        } finally {
            recognizer.close()
        }
    }

    private fun extractImage(
        resolver: ContentResolver,
        uri: Uri,
        recognizer: com.google.mlkit.vision.text.TextRecognizer,
    ): OcrDocument {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        val boundsStream = resolver.openInputStream(uri)
            ?: throw IOException("The selected image could not be opened.")
        boundsStream.use { BitmapFactory.decodeStream(it, null, bounds) }
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) throw IOException("The image could not be read.")
        val largestSide = maxOf(bounds.outWidth, bounds.outHeight)
        var sample = 1
        while (largestSide / sample > MAX_DIMENSION) sample *= 2
        val options = BitmapFactory.Options().apply { inSampleSize = sample }
        val bitmap = resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, options) }
            ?: throw IOException("The selected image could not be opened.")
        return bitmap.useOcr(recognizer, page = 0)
    }

    private fun extractPdf(
        resolver: ContentResolver,
        uri: Uri,
        recognizer: com.google.mlkit.vision.text.TextRecognizer,
    ): OcrDocument {
        val descriptor = resolver.openFileDescriptor(uri, "r")
            ?: throw IOException("The selected PDF could not be opened.")
        return descriptor.use { file ->
            PdfRenderer(file).use { renderer ->
                if (renderer.pageCount > MAX_PAGES) {
                    throw IOException("This PDF has ${renderer.pageCount} pages. Choose a document with $MAX_PAGES pages or fewer.")
                }
                val text = StringBuilder()
                val tokens = mutableListOf<OcrTextToken>()
                for (index in 0 until renderer.pageCount) {
                    if (text.length > MAX_TEXT_CHARS) break
                    renderer.openPage(index).use { page ->
                        val scale = minOf(2f, MAX_DIMENSION.toFloat() / page.width, MAX_DIMENSION.toFloat() / page.height)
                        val width = (page.width * scale).toInt().coerceAtLeast(1)
                        val height = (page.height * scale).toInt().coerceAtLeast(1)
                        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                        try {
                            Canvas(bitmap).drawColor(Color.WHITE)
                            page.render(bitmap, Rect(0, 0, width, height), null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                            val recognized = Tasks.await(recognizer.process(InputImage.fromBitmap(bitmap, 0)), 30, TimeUnit.SECONDS)
                            text.append("\n--- Page ${index + 1} ---\n")
                            text.append(recognized.text).append('\n')
                            tokens.addAll(recognized.toTokens(index, width, height))
                        } finally {
                            bitmap.recycle()
                        }
                    }
                }
                OcrDocument(text.toString().take(MAX_TEXT_CHARS), tokens)
            }
        }
    }

    private fun Bitmap.useOcr(
        recognizer: com.google.mlkit.vision.text.TextRecognizer,
        page: Int,
    ): OcrDocument = try {
        val recognized = Tasks.await(recognizer.process(InputImage.fromBitmap(this, 0)), 30, TimeUnit.SECONDS)
        OcrDocument(recognized.text.take(MAX_TEXT_CHARS), recognized.toTokens(page, width, height))
    } finally {
        recycle()
    }

    private fun Text.toTokens(page: Int, width: Int, height: Int): List<OcrTextToken> =
        textBlocks.asSequence()
            .flatMap { it.lines.asSequence() }
            .flatMap { it.elements.asSequence() }
            .mapNotNull { element ->
                val box = element.boundingBox ?: return@mapNotNull null
                if (element.text.isBlank()) return@mapNotNull null
                OcrTextToken(
                    text = element.text,
                    left = (box.left.toFloat() / width).coerceIn(0f, 1f),
                    top = (box.top.toFloat() / height).coerceIn(0f, 1f),
                    right = (box.right.toFloat() / width).coerceIn(0f, 1f),
                    bottom = (box.bottom.toFloat() / height).coerceIn(0f, 1f),
                    page = page,
                )
            }
            .take(10000)
            .toList()
}

internal data class OcrDocument(val text: String, val tokens: List<OcrTextToken>)

internal data class OcrTextToken(
    val text: String,
    val left: Float,
    val top: Float,
    val right: Float,
    val bottom: Float,
    val page: Int,
)
