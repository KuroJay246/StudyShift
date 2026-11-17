package app.shiftstudy.mobile

import org.junit.Assert.assertEquals
import org.junit.Test

class LauncherAliasComponentTest {
    @Test
    fun launcherAliasClassUsesAndroidNamespaceInsteadOfFlavorApplicationId() {
        assertEquals(
            "app.shiftstudy.mobile.LauncherRed",
            launcherAliasClassName("app.shiftstudy.mobile.MainActivity", "LauncherRed"),
        )
    }
}
