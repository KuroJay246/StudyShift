package app.shiftstudy.mobile

import org.junit.Assert.assertEquals
import org.junit.Test

class ScheduleOcrRenderingTest {
    @Test
    fun `portrait roster PDF is rendered at the higher readable resolution`() {
        assertEquals(
            OcrPixelSize(width = 1584, height = 2448),
            pdfOcrPixelSize(pageWidth = 792, pageHeight = 1224),
        )
    }

    @Test
    fun `wide pages stay within the raster size bound`() {
        val size = pdfOcrPixelSize(pageWidth = 4000, pageHeight = 2000)

        assertEquals(3000, maxOf(size.width, size.height))
        assertEquals(1500, minOf(size.width, size.height))
    }

    @Test
    fun `roster OCR strips overlap while covering the full page with two passes`() {
        assertEquals(
            listOf(OcrStrip(0, 600), OcrStrip(400, 1000)),
            rosterOcrStrips(pageHeight = 1000),
        )
    }

    @Test
    fun `focused roster OCR keeps the dense table side within page coordinates`() {
        assertEquals(780, rosterOcrFocusWidth(pageWidth = 1000))
        assertEquals(1, rosterOcrFocusWidth(pageWidth = 1))
    }

    @Test
    fun `focused OCR strips can upscale further while respecting the pixel cap`() {
        assertEquals(
            OcrPixelSize(width = 3000, height = 1500),
            pdfOcrPixelSize(
                pageWidth = 1000,
                pageHeight = 500,
                maxDimension = 3000,
                maxScale = 3f,
            ),
        )
    }

    @Test
    fun `repeated OCR passes merge overlapping copies but retain real repeated words`() {
        val tokens = listOf(
            OcrTextToken("Kevin", .10f, .20f, .15f, .22f, 0),
            OcrTextToken("Kevin", .101f, .201f, .151f, .221f, 0),
            OcrTextToken("Kevin", .17f, .20f, .22f, .22f, 0),
            OcrTextToken("Kevin", .13f, .20f, .18f, .22f, 0),
        )

        assertEquals(
            listOf(tokens[0], tokens[2]),
            deduplicateOcrTokens(tokens),
        )
    }
}
