package app.shiftstudy.mobile

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class MainActivityExposureTest {
    @Test
    fun blueLauncherAliasIsAvailableOnFreshInstall() {
        val manifest = mainManifest()
        val aliases = manifest.getElementsByTagName("activity-alias")
        var blueAlias: org.w3c.dom.Element? = null
        for (index in 0 until aliases.length) {
            val candidate = aliases.item(index) as org.w3c.dom.Element
            if (candidate.getAttributeNS(ANDROID_NAMESPACE, "name") == ".LauncherBlue") {
                blueAlias = candidate
            }
        }

        assertNotNull("The default StudyShift blue launcher alias is declared.", blueAlias)
        assertTrue(
            "A fresh install needs an exported launcher entry point before Flutter starts.",
            blueAlias!!.getAttributeNS(ANDROID_NAMESPACE, "enabled").toBoolean(),
        )
    }

    @Test
    fun mainActivityIsPrivateBecauseLauncherAliasesAreTheEntryPoints() {
        val manifest = mainManifest()
        val activities = manifest.getElementsByTagName("activity")
        var mainActivity: org.w3c.dom.Element? = null
        for (index in 0 until activities.length) {
            val candidate = activities.item(index) as org.w3c.dom.Element
            if (candidate.getAttributeNS(ANDROID_NAMESPACE, "name") == ".MainActivity") {
                mainActivity = candidate
                break
            }
        }

        assertNotNull("MainActivity is declared", mainActivity)
        assertFalse(
            "Only the explicitly declared launcher aliases should be externally startable.",
            mainActivity!!.getAttributeNS(ANDROID_NAMESPACE, "exported").toBoolean(),
        )
    }

    @Test
    fun mainManifestRequestsOnlyTheReviewedPermissionSet() {
        val manifest = mainManifest()
        val nodes = manifest.getElementsByTagName("uses-permission")
        val requested = buildSet {
            for (index in 0 until nodes.length) {
                val permission = nodes.item(index) as org.w3c.dom.Element
                add(permission.getAttributeNS(ANDROID_NAMESPACE, "name"))
            }
        }

        assertEquals(
            setOf(
                "android.permission.INTERNET",
                "android.permission.ACCESS_COARSE_LOCATION",
                "android.permission.RECEIVE_BOOT_COMPLETED",
                "android.permission.SCHEDULE_EXACT_ALARM",
                "com.android.alarm.permission.SET_ALARM",
            ),
            requested,
        )
    }

    private fun mainManifest() = DocumentBuilderFactory.newInstance().apply {
        isNamespaceAware = true
    }
        .newDocumentBuilder()
        .parse(File("src/main/AndroidManifest.xml"))

    private companion object {
        const val ANDROID_NAMESPACE = "http://schemas.android.com/apk/res/android"
    }
}
