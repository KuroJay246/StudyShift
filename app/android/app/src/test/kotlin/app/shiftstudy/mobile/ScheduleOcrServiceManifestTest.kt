package app.shiftstudy.mobile

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Test

class ScheduleOcrServiceManifestTest {
    @Test
    fun ocrServiceRunsInPrivateProcessAndIsNotExported() {
        val manifest = DocumentBuilderFactory.newInstance().apply {
            isNamespaceAware = true
        }
            .newDocumentBuilder()
            .parse(File("src/main/AndroidManifest.xml"))
        val services = manifest.getElementsByTagName("service")
        var service: org.w3c.dom.Element? = null
        for (index in 0 until services.length) {
            val candidate = services.item(index) as org.w3c.dom.Element
            if (candidate.getAttributeNS(ANDROID_NAMESPACE, "name") == ".ScheduleOcrService") {
                service = candidate
                break
            }
        }

        assertNotNull("OCR service is declared", service)
        assertEquals(":schedule_ocr", service!!.getAttributeNS(ANDROID_NAMESPACE, "process"))
        assertFalse(service.getAttributeNS(ANDROID_NAMESPACE, "exported").toBoolean())
    }

    private companion object {
        const val ANDROID_NAMESPACE = "http://schemas.android.com/apk/res/android"
    }
}
