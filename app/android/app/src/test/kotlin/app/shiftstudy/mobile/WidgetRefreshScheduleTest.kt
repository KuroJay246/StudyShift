package app.shiftstudy.mobile

import android.content.Intent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class WidgetRefreshScheduleTest {
    @Test
    fun requestsWidgetRefreshAfterTheAppPackageIsReplaced() {
        assertEquals(true, shouldRefreshWidgetProvider(Intent.ACTION_MY_PACKAGE_REPLACED))
    }

    @Test
    fun selectsTheNextStartOrEndBoundary() {
        val now = 1_000L

        assertEquals(
            1_200L,
            nextWidgetRefreshAt(
                intervals = listOf(900L to 1_200L, 1_500L to 2_000L),
                nowMillis = now,
            ),
        )
    }

    @Test
    fun schedulesMinuteTicksForAVisibleNextEventCountdown() {
        assertEquals(
            60_000L,
            nextWidgetRefreshAt(
                intervals = listOf(120_000L to 180_000L),
                nowMillis = 1_000L,
                refreshCountdown = true,
            ),
        )
    }

    @Test
    fun keepsAnEventBoundaryEarlierThanTheNextCountdownTick() {
        assertEquals(
            30_000L,
            nextWidgetRefreshAt(
                intervals = listOf(30_000L to 180_000L),
                nowMillis = 1_000L,
                refreshCountdown = true,
            ),
        )
    }

    @Test
    fun doesNotAddMinuteTicksWhenOnlyNonCountdownWidgetsAreInstalled() {
        assertEquals(
            120_000L,
            nextWidgetRefreshAt(
                intervals = listOf(120_000L to 180_000L),
                nowMillis = 1_000L,
            ),
        )
    }

    @Test
    fun returnsNullWhenNoFutureBoundaryExists() {
        assertNull(
            nextWidgetRefreshAt(
                intervals = listOf(100L to 200L),
                nowMillis = 200L,
            ),
        )
    }
}
