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
    private const val MAX_PDF_DIMENSION = 3000
    private const val MAX_TEXT_CHARS = 500_000

    fun extract(
        resolver: ContentResolver,
        uri: Uri,
        name: String,
        rosterTable: Boolean = false,
    ): OcrDocument {
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        return try {
            val text = when (name.substringAfterLast('.', "").lowercase()) {
                "pdf" -> extractPdf(resolver, uri, recognizer, rosterTable)
                "png", "jpg", "jpeg", "webp", "bmp" -> extractImage(resolver, uri, recognizer, rosterTable)
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
        rosterTable: Boolean,
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
        return bitmap.useOcr(recognizer, page = 0, rosterTable = rosterTable)
    }

    private fun extractPdf(
        resolver: ContentResolver,
        uri: Uri,
        recognizer: com.google.mlkit.vision.text.TextRecognizer,
        rosterTable: Boolean,
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
                        val size = pdfOcrPixelSize(
                            pageWidth = page.width,
                            pageHeight = page.height,
                            maxDimension = MAX_PDF_DIMENSION,
                        )
                        val width = size.width
                        val height = size.height
                        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                        try {
                            Canvas(bitmap).drawColor(Color.WHITE)
                            page.render(
                                bitmap,
                                Rect(0, 0, width, height),
                                null,
                                PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY,
                            )
                            val document = bitmap.useOcr(
                                recognizer,
                                page = index,
                                rosterTable = rosterTable,
                            )
                            text.append("\n--- Page ${index + 1} ---\n")
                            text.append(document.text).append('\n')
                            tokens.addAll(document.tokens)
                        } finally {
                            if (!bitmap.isRecycled) bitmap.recycle()
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
        rosterTable: Boolean = false,
    ): OcrDocument = try {
        val recognized = Tasks.await(recognizer.process(InputImage.fromBitmap(this, 0)), 30, TimeUnit.SECONDS)
        val tokens = recognized.toTokens(page, width, height).toMutableList()
        if (rosterTable) tokens.addAll(recognizeRosterStrips(recognizer, page))
        OcrDocument(recognized.text.take(MAX_TEXT_CHARS), deduplicateOcrTokens(tokens).take(MAX_TOKENS))
    } finally {
        recycle()
    }

    private fun Bitmap.recognizeRosterStrips(
        recognizer: com.google.mlkit.vision.text.TextRecognizer,
        page: Int,
    ): List<OcrTextToken> {
        val result = mutableListOf<OcrTextToken>()
        // Roster pages often place a dense date grid beside a separate
        // legend. Re-read the left table area without spending OCR pixels on
        // the unrelated right-hand panel; keep the full-page pass above too.
        val focusedWidth = rosterOcrFocusWidth(width)
        for (strip in rosterOcrStrips(height)) {
            val stripHeight = strip.bottomExclusive - strip.top
            val crop = Bitmap.createBitmap(this, 0, strip.top, focusedWidth, stripHeight)
            val size = pdfOcrPixelSize(
                crop.width,
                crop.height,
                MAX_STRIP_DIMENSION,
                maxScale = MAX_STRIP_SCALE,
            )
            val scaled = if (size.width == crop.width && size.height == crop.height) {
                crop
            } else {
                Bitmap.createScaledBitmap(crop, size.width, size.height, true)
            }
            try {
                val recognized = Tasks.await(
                    recognizer.process(InputImage.fromBitmap(scaled, 0)),
                    30,
                    TimeUnit.SECONDS,
                )
                result.addAll(
                    recognized.toTokens(
                        page = page,
                        width = scaled.width,
                        height = scaled.height,
                        pageWidth = width,
                        sourceStripWidth = focusedWidth,
                        pageTop = strip.top,
                        pageHeight = height,
                        sourceStripHeight = stripHeight,
                    ),
                )
            } finally {
                if (scaled !== crop) scaled.recycle()
                crop.recycle()
            }
        }
        return deduplicateOcrTokens(result).take(MAX_TOKENS)
    }

    private fun Text.toTokens(
        page: Int,
        width: Int,
        height: Int,
        pageWidth: Int = width,
        pageLeft: Int = 0,
        sourceStripWidth: Int = pageWidth,
        pageTop: Int = 0,
        pageHeight: Int = height,
        sourceStripHeight: Int = pageHeight,
    ): List<OcrTextToken> =
        textBlocks.asSequence()
            .flatMap { it.lines.asSequence() }
            .flatMap { it.elements.asSequence() }
            .mapNotNull { element ->
                val box = element.boundingBox ?: return@mapNotNull null
                if (element.text.isBlank()) return@mapNotNull null
                OcrTextToken(
                    text = element.text,
                    left = (
                        (pageLeft + box.left.toFloat() / width * sourceStripWidth) /
                            pageWidth
                        ).coerceIn(0f, 1f),
                    top = ((pageTop + box.top.toFloat() / height * sourceStripHeight) / pageHeight).coerceIn(0f, 1f),
                    right = (
                        (pageLeft + box.right.toFloat() / width * sourceStripWidth) /
                            pageWidth
                        ).coerceIn(0f, 1f),
                    bottom = ((pageTop + box.bottom.toFloat() / height * sourceStripHeight) / pageHeight).coerceIn(0f, 1f),
                    page = page,
                )
            }
            .take(MAX_TOKENS)
            .toList()

    private const val MAX_TOKENS = 10_000
    private const val MAX_STRIP_DIMENSION = 3000
    private const val MAX_STRIP_SCALE = 3f
}

internal data class OcrDocument(val text: String, val tokens: List<OcrTextToken>)

internal data class OcrPixelSize(val width: Int, val height: Int)

internal data class OcrStrip(val top: Int, val bottomExclusive: Int)

internal fun rosterOcrFocusWidth(pageWidth: Int, widthFraction: Float = .78f): Int {
    require(pageWidth > 0 && widthFraction > 0f && widthFraction <= 1f)
    return (pageWidth * widthFraction).toInt().coerceAtLeast(1)
}

internal fun rosterOcrStrips(pageHeight: Int, stripCount: Int = 2): List<OcrStrip> {
    require(pageHeight > 0 && stripCount > 0)
    if (stripCount == 1) return listOf(OcrStrip(0, pageHeight))
    val stripHeight = (pageHeight / stripCount * 1.2f)
        .toInt()
        .coerceAtLeast(1)
        .coerceAtMost(pageHeight)
    val step = (pageHeight - stripHeight).toFloat() / (stripCount - 1)
    return List(stripCount) { index ->
        val top = (step * index).toInt()
        OcrStrip(top = top, bottomExclusive = (top + stripHeight).coerceAtMost(pageHeight))
    }
}

internal fun pdfOcrPixelSize(
    pageWidth: Int,
    pageHeight: Int,
    maxDimension: Int = 3000,
    maxScale: Float = 2f,
): OcrPixelSize {
    require(pageWidth > 0 && pageHeight > 0 && maxDimension > 0 && maxScale > 0f)
    val scale = minOf(
        maxScale,
        maxDimension.toFloat() / pageWidth,
        maxDimension.toFloat() / pageHeight,
    )
    return OcrPixelSize(
        width = (pageWidth * scale).toInt().coerceAtLeast(1),
        height = (pageHeight * scale).toInt().coerceAtLeast(1),
    )
}

internal data class OcrTextToken(
    val text: String,
    val left: Float,
    val top: Float,
    val right: Float,
    val bottom: Float,
    val page: Int,
)

internal fun deduplicateOcrTokens(tokens: List<OcrTextToken>): List<OcrTextToken> {
    val unique = mutableListOf<OcrTextToken>()
    for (token in tokens) {
        val normalizedText = token.text.trim().lowercase()
        val duplicated = unique.any { existing ->
            if (existing.page != token.page || existing.text.trim().lowercase() != normalizedText) {
                return@any false
            }
            val overlapWidth = minOf(existing.right, token.right) - maxOf(existing.left, token.left)
            val overlapHeight = minOf(existing.bottom, token.bottom) - maxOf(existing.top, token.top)
            val intersection = overlapWidth.coerceAtLeast(0f) * overlapHeight.coerceAtLeast(0f)
            val smallerArea = minOf(
                (existing.right - existing.left) * (existing.bottom - existing.top),
                (token.right - token.left) * (token.bottom - token.top),
            )
            smallerArea > 0f && intersection / smallerArea >= .35f
        }
        if (!duplicated) unique.add(token)
    }
    return unique
}
