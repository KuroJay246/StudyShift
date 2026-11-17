package app.shiftstudy.mobile

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate

class ScheduleWidgetLayoutTest {
    @Test
    fun deadlineWidgetIncludesTheNearestDateOnlyDeadline() {
        val today = LocalDate.parse("2026-11-15")
        val selected = nextAllDayDeadline(
            events = listOf(
                ScheduleWidgetEvent(
                    id = "later", kind = "deadline", title = "Later", localDate = today.plusDays(5),
                    isDayOff = false, intervals = emptyList(),
                ),
                ScheduleWidgetEvent(
                    id = "old", kind = "deadline", title = "Past", localDate = today.minusDays(1),
                    isDayOff = false, intervals = emptyList(),
                ),
                ScheduleWidgetEvent(
                    id = "class", kind = "classSession", title = "Class", localDate = today.plusDays(1),
                    isDayOff = false, intervals = emptyList(),
                ),
                ScheduleWidgetEvent(
                    id = "nearest", kind = "deadline", title = "Nearest", localDate = today.plusDays(2),
                    isDayOff = false, intervals = emptyList(),
                ),
            ),
            today = today,
        )

        assertEquals("nearest", selected?.id)
    }

    @Test
    fun deadlineWidgetIncludesDateOnlyDeadlinesBeyondVisibleMonth() {
        val today = LocalDate.parse("2026-11-15")
        val withinProjection = ScheduleWidgetEvent(
            id = "near", kind = "deadline", title = "Near", localDate = today.plusDays(12),
            isDayOff = false, intervals = emptyList(),
        )
        val nextAllDayByFilter = ScheduleWidgetEvent(
            id = "long-range", kind = "deadline", title = "Long range",
            localDate = today.plusDays(45), isDayOff = false, intervals = emptyList(),
        )

        assertEquals(
            "near",
            nextAllDayDeadline(listOf(withinProjection), today, nextAllDayByFilter)?.id,
        )
        assertEquals(
            "long-range",
            nextAllDayDeadline(emptyList(), today, nextAllDayByFilter)?.id,
        )
    }

    @Test
    fun widgetAcceptsSnapshotSchemaSevenForLongRangeDateOnlyDeadlines() {
        assertEquals(true, isSupportedWidgetSnapshotSchema(7))
        assertEquals(false, isSupportedWidgetSnapshotSchema(8))
    }

    @Test
    fun todayWidgetShowsNextTwoUniqueEventsAndKeepsSplitIntervalsTogether() {
        val today = LocalDate.parse("2026-11-14")
        val start = 100_000L
        val events = listOf(
            ScheduleWidgetEvent(
                id = "split-work", kind = "work", title = "Ramp shift", localDate = today,
                isDayOff = false,
                intervals = listOf(ScheduleWidgetInterval(start + 10_000, start + 20_000),
                    ScheduleWidgetInterval(start + 30_000, start + 40_000)),
            ),
            ScheduleWidgetEvent(
                id = "class", kind = "classSession", title = "Operations", localDate = today,
                isDayOff = false, intervals = listOf(ScheduleWidgetInterval(start + 25_000, start + 28_000)),
            ),
            ScheduleWidgetEvent(
                id = "later", kind = "work", title = "Later shift", localDate = today,
                isDayOff = false, intervals = listOf(ScheduleWidgetInterval(start + 50_000, start + 60_000)),
            ),
        )

        val selected = todayWidgetEvents(
            events = events,
            today = today,
            nowMillis = start,
            dayStartMillis = start - 1_000,
            dayEndMillis = start + 100_000,
            contentFilter = ScheduleWidgetConfigureActivity.CONTENT_ALL,
        )

        assertEquals(listOf("split-work", "class"), selected.map { it.event.id })
        assertEquals(start + 10_000, selected.first().startMillis)
    }

    @Test
    fun todayWidgetFiltersEventsAndKeepsAnOngoingOvernightShiftVisible() {
        val today = LocalDate.parse("2026-11-14")
        val events = listOf(
            ScheduleWidgetEvent(
                id = "overnight", kind = "work", title = "Night shift", localDate = today.minusDays(1),
                isDayOff = false, intervals = listOf(ScheduleWidgetInterval(10_000, 30_000)),
            ),
            ScheduleWidgetEvent(
                id = "class", kind = "classSession", title = "Class", localDate = today,
                isDayOff = false, intervals = listOf(ScheduleWidgetInterval(40_000, 50_000)),
            ),
            ScheduleWidgetEvent(
                id = "off", kind = "work", title = "Rest day", localDate = today,
                isDayOff = true, intervals = emptyList(),
            ),
        )

        val workOnly = todayWidgetEvents(
            events, today, 20_000, 0, 86_400, ScheduleWidgetConfigureActivity.CONTENT_WORK,
        )

        assertEquals(listOf("overnight", "off"), workOnly.map { it.event.id })
        assertEquals(true, workOnly.first().ongoing)
        assertEquals(null, workOnly.last().startMillis)
    }

    @Test
    fun secondTodayEntryIsShownOnlyInExpandedTodayWidget() {
        assertEquals(
            true,
            scheduleWidgetShowsSecondTodayEvent(
                ScheduleWidgetConfigureActivity.TYPE_TODAY,
                ScheduleWidgetLayout.EXPANDED,
            ),
        )
        assertEquals(
            false,
            scheduleWidgetShowsSecondTodayEvent(
                ScheduleWidgetConfigureActivity.TYPE_TODAY,
                ScheduleWidgetLayout.TALL_NARROW,
            ),
        )
        assertEquals(
            false,
            scheduleWidgetShowsSecondTodayEvent(
                ScheduleWidgetConfigureActivity.TYPE_NEXT_EVENT,
                ScheduleWidgetLayout.EXPANDED,
            ),
        )
        assertEquals(
            true,
            scheduleWidgetShowsThirdTodayEvent(
                ScheduleWidgetConfigureActivity.TYPE_TODAY,
                ScheduleWidgetLayout.TALL_EXPANDED,
            ),
        )
        assertEquals(
            false,
            scheduleWidgetShowsThirdTodayEvent(
                ScheduleWidgetConfigureActivity.TYPE_TODAY,
                ScheduleWidgetLayout.EXPANDED,
            ),
        )
    }

    @Test
    fun widgetSnapshotAcceptsTheCurrentSchemaAndRejectsUnknownVersions() {
        assertEquals(true, isSupportedWidgetSnapshotSchema(4))
        assertEquals(true, isSupportedWidgetSnapshotSchema(5))
        assertEquals(true, isSupportedWidgetSnapshotSchema(6))
        assertEquals(true, isSupportedWidgetSnapshotSchema(7))
        assertEquals(false, isSupportedWidgetSnapshotSchema(3))
        assertEquals(false, isSupportedWidgetSnapshotSchema(8))
    }

    @Test
    fun nextProjectionUsesTheConfiguredContentFilter() {
        assertEquals(
            "all",
            nextProjectionKey(ScheduleWidgetConfigureActivity.CONTENT_ALL),
        )
        assertEquals(
            "work",
            nextProjectionKey(ScheduleWidgetConfigureActivity.CONTENT_WORK),
        )
        assertEquals(
            "study",
            nextProjectionKey(ScheduleWidgetConfigureActivity.CONTENT_STUDY),
        )
    }

    @Test
    fun compactWeekSummaryKeepsAllSevenDaysReadableInTwoColumns() {
        assertEquals(
            "M0 Tu2 W0 Th1 F3 Sa0 Su0",
            weekWidgetSummary(intArrayOf(0, 2, 0, 1, 3, 0, 0), compact = true),
        )
    }

    @Test
    fun wideWeekSummaryKeepsSpacedDayCounts() {
        assertEquals(
            "M 0     Tu 2     W 0     Th 1     F 3     Sa 0     Su 0",
            weekWidgetSummary(intArrayOf(0, 2, 0, 1, 3, 0, 0), compact = false),
        )
    }

    @Test
    fun weekWidgetAddsOneOrTwoEventRowsOnlyWhenResizedTaller() {
        assertEquals(
            0,
            weekWidgetEventLimit(scheduleWidgetLayout(widthDp = 334f, heightDp = 106f)),
        )
        assertEquals(
            1,
            weekWidgetEventLimit(scheduleWidgetLayout(widthDp = 334f, heightDp = 179f)),
        )
        assertEquals(
            2,
            weekWidgetEventLimit(scheduleWidgetLayout(widthDp = 334f, heightDp = 250f)),
        )
    }

    @Test
    fun tallerWeekWidgetSelectsTheNextDayWithUpcomingEventsAndLimitsRows() {
        val today = LocalDate.parse("2026-11-16")
        val events = listOf(
            ScheduleWidgetEvent(
                id = "finished-today", kind = "work", title = "Finished shift", localDate = today,
                isDayOff = false, intervals = listOf(ScheduleWidgetInterval(100L, 900L)),
            ),
            ScheduleWidgetEvent(
                id = "class-first", kind = "classSession", title = "Morning class", localDate = today.plusDays(1),
                isDayOff = false, intervals = listOf(ScheduleWidgetInterval(2_000L, 3_000L)),
            ),
            ScheduleWidgetEvent(
                id = "shift-second", kind = "work", title = "Ramp shift", localDate = today.plusDays(1),
                isDayOff = false, intervals = listOf(ScheduleWidgetInterval(4_000L, 5_000L)),
            ),
            ScheduleWidgetEvent(
                id = "later-tomorrow", kind = "deadline", title = "Later deadline", localDate = today.plusDays(1),
                isDayOff = false, intervals = listOf(ScheduleWidgetInterval(6_000L, 7_000L)),
            ),
            ScheduleWidgetEvent(
                id = "next-week", kind = "work", title = "Next week", localDate = today.plusDays(8),
                isDayOff = false, intervals = listOf(ScheduleWidgetInterval(8_000L, 9_000L)),
            ),
        )

        val selection = weekWidgetSelection(events, today, nowMillis = 1_000L, limit = 2)

        assertEquals(today.plusDays(1), selection.date)
        assertEquals(listOf("class-first", "shift-second"), selection.events.map { it.event.id })
        assertEquals(2_000L, selection.events.first().startMillis)
    }

    @Test
    fun tallerWeekWidgetKeepsAnOngoingEventOnTheCurrentDate() {
        val today = LocalDate.parse("2026-11-16")
        val events = listOf(
            ScheduleWidgetEvent(
                id = "active", kind = "work", title = "Active shift", localDate = today,
                isDayOff = false,
                intervals = listOf(ScheduleWidgetInterval(900L, 1_100L)),
            ),
            ScheduleWidgetEvent(
                id = "later-today", kind = "classSession", title = "Later class", localDate = today,
                isDayOff = false,
                intervals = listOf(ScheduleWidgetInterval(1_200L, 1_500L)),
            ),
        )

        val selection = weekWidgetSelection(events, today, nowMillis = 1_000L, limit = 2)

        assertEquals(today, selection.date)
        assertEquals(listOf("active", "later-today"), selection.events.map { it.event.id })
        assertEquals(true, selection.events.first().ongoing)
    }

    @Test
    fun samsungWideTwoRowWidgetUsesExpandedLayout() {
        assertEquals(
            ScheduleWidgetLayout.EXPANDED,
            scheduleWidgetLayout(widthDp = 334f, heightDp = 179f),
        )
        assertEquals(2, scheduleWidgetTodayEventLimit(ScheduleWidgetLayout.EXPANDED))
        assertEquals(
            ScheduleWidgetTextScale.EXPANDED,
            scheduleWidgetTextScale(ScheduleWidgetLayout.EXPANDED),
        )
    }

    @Test
    fun tallerTodayLayoutShowsThreeRowsAndReportsRemainingEvents() {
        val layout = scheduleWidgetLayout(widthDp = 334f, heightDp = 250f)
        assertEquals(ScheduleWidgetLayout.TALL_EXPANDED, layout)
        assertEquals(3, scheduleWidgetTodayEventLimit(layout))

        val today = LocalDate.parse("2026-11-14")
        val events = (0 until 5).map { index ->
            val start = 100_000L + index * 20_000L
            ScheduleWidgetEvent(
                id = "event-$index",
                kind = "work",
                title = "Shift $index",
                localDate = today,
                isDayOff = false,
                intervals = listOf(ScheduleWidgetInterval(start, start + 10_000)),
            )
        }
        val visible = todayWidgetEvents(
            events = events,
            today = today,
            nowMillis = 0,
            dayStartMillis = 0,
            dayEndMillis = 1_000_000,
            contentFilter = ScheduleWidgetConfigureActivity.CONTENT_ALL,
            limit = scheduleWidgetTodayEventLimit(layout),
        )

        assertEquals(listOf("event-0", "event-1", "event-2"), visible.map { it.event.id })
        assertEquals(2, todayWidgetOverflowCount(events.size, visible.size))
    }

    @Test
    fun emptyTodayLayoutKeepsZeroRowsAndNoOverflowAtEverySize() {
        for (layout in ScheduleWidgetLayout.entries) {
            val visible = todayWidgetEvents(
                events = emptyList(),
                today = LocalDate.parse("2026-11-14"),
                nowMillis = 0,
                dayStartMillis = 0,
                dayEndMillis = 1_000,
                contentFilter = ScheduleWidgetConfigureActivity.CONTENT_ALL,
                limit = scheduleWidgetTodayEventLimit(layout),
            )
            assertEquals(0, visible.size)
            assertEquals(0, todayWidgetOverflowCount(0, visible.size))
        }
    }

    @Test
    fun tallNarrowProfileUsesWidgetHeightAndKeepsLongTitlesReadable() {
        val narrow = scheduleWidgetTextScale(ScheduleWidgetLayout.TALL_NARROW)
        val wide = scheduleWidgetTextScale(ScheduleWidgetLayout.EXPANDED)

        assertEquals(16f, narrow.headingSp)
        assertEquals(12f, narrow.detailSp)
        assertEquals(2, narrow.headingMaxLines)
        assertEquals(1, narrow.detailMaxLines)
        assertEquals(20f, wide.headingSp)
        assertEquals(16f, wide.detailSp)
        assertEquals(2, wide.headingMaxLines)
        assertEquals(2, wide.detailMaxLines)
    }

    @Test
    fun narrowNextEventWidgetDoesNotSplitLongUnbrokenTitlesAcrossLines() {
        assertEquals(
            "QAWidgetShiftUpd…",
            scheduleWidgetHeadingText(
                "QAWidgetShiftUpdated",
                ScheduleWidgetConfigureActivity.TYPE_NEXT_EVENT,
                ScheduleWidgetLayout.TALL_NARROW,
            ),
        )
    }

    @Test
    fun todayWidgetUsesResponsiveTypographyAtCompactAndExpandedSizes() {
        assertEquals(
            ScheduleWidgetTextScale(12f, 11f, 10f, 14f, 11f, 1, 1),
            scheduleWidgetTextScaleForType(
                ScheduleWidgetConfigureActivity.TYPE_TODAY,
                ScheduleWidgetLayout.COMPACT,
            ),
        )
        assertEquals(
            ScheduleWidgetTextScale(12f, 12f, 10f, 16f, 12f, 2, 2),
            scheduleWidgetTextScaleForType(
                ScheduleWidgetConfigureActivity.TYPE_TODAY,
                ScheduleWidgetLayout.EXPANDED,
            ),
        )
        assertEquals(
            ScheduleWidgetTextScale(12f, 12f, 10f, 16f, 12f, 2, 2),
            scheduleWidgetTextScaleForType(
                ScheduleWidgetConfigureActivity.TYPE_TODAY,
                ScheduleWidgetLayout.TALL_NARROW,
            ),
        )
    }

    @Test
    fun populatedNextEventWidgetUsesVerticalSpaceOnlyWhenItsTileIsTall() {
        assertEquals(
            ScheduleWidgetLayout.TALL_NARROW,
            scheduleWidgetLayout(widthDp = 156f, heightDp = 179f),
        )
        assertEquals(
            ScheduleWidgetContentAlignment.CENTER_VERTICAL,
            scheduleWidgetContentAlignment(
                ScheduleWidgetConfigureActivity.TYPE_NEXT_EVENT,
                hasContent = true,
                layout = ScheduleWidgetLayout.TALL_NARROW,
            ),
        )
        assertEquals(
            ScheduleWidgetContentAlignment.TOP,
            scheduleWidgetContentAlignment(
                ScheduleWidgetConfigureActivity.TYPE_NEXT_EVENT,
                hasContent = true,
                layout = ScheduleWidgetLayout.SHORT_WIDE,
            ),
        )
    }

    @Test
    fun shortTwoColumnWidgetKeepsCompactLayout() {
        assertEquals(
            ScheduleWidgetLayout.COMPACT,
            scheduleWidgetLayout(widthDp = 175f, heightDp = 106f),
        )
        assertEquals(1, scheduleWidgetTodayEventLimit(ScheduleWidgetLayout.COMPACT))
    }

    @Test
    fun wideSingleRowWidgetUsesShortWideLayout() {
        assertEquals(
            ScheduleWidgetLayout.SHORT_WIDE,
            scheduleWidgetLayout(widthDp = 334f, heightDp = 90f),
        )
    }

    @Test
    fun emptySummaryWidgetsCenterAndPopulatedSingleEventWidgetsUseTheTileBetter() {
        assertEquals(
            ScheduleWidgetContentAlignment.CENTER_VERTICAL,
            scheduleWidgetContentAlignment(
                ScheduleWidgetConfigureActivity.TYPE_NEXT_EVENT,
                hasContent = false,
            ),
        )
        assertEquals(
            ScheduleWidgetContentAlignment.CENTER_VERTICAL,
            scheduleWidgetContentAlignment(
                ScheduleWidgetConfigureActivity.TYPE_NEXT_EVENT,
                hasContent = true,
            ),
        )
        assertEquals(
            ScheduleWidgetContentAlignment.TOP,
            scheduleWidgetContentAlignment(ScheduleWidgetConfigureActivity.TYPE_TODAY, hasContent = true),
        )
        assertEquals(
            ScheduleWidgetContentAlignment.TOP,
            scheduleWidgetContentAlignment(ScheduleWidgetConfigureActivity.TYPE_WEEK),
        )
    }

    @Test
    fun emptyTodayWidgetCentersItsShortCopyInTheAvailableTile() {
        assertEquals(
            ScheduleWidgetContentAlignment.CENTER_VERTICAL,
            scheduleWidgetContentAlignment(
                ScheduleWidgetConfigureActivity.TYPE_TODAY,
                hasContent = false,
            ),
        )
    }

    @Test
    fun widgetCardFillsAndPacksContentAtTheTopOfTheLauncherAllocation() {
        val layout = File("src/main/res/layout/schedule_widget.xml").readText()
        val cardAttributes = layout
            .substringAfter("android:id=\"@+id/widget_card\"")
            .substringBefore(">")

        assertTrue(cardAttributes.contains("android:gravity=\"top\""))
        assertTrue(cardAttributes.contains("android:layout_height=\"match_parent\""))

        listOf(
            "schedule_widget_preview.xml",
            "next_class_widget_preview.xml",
            "deadline_widget_preview.xml",
        ).forEach { name ->
            val preview = File("src/main/res/layout/$name").readText()
            val previewCard = preview
                .substringAfter("<LinearLayout")
                .substringBefore(">")
            assertTrue("$name should fill the 2x2 preview height", previewCard.contains("android:layout_height=\"match_parent\""))
        }
    }

    @Test
    fun todayAndWeekWidgetPreviewsAlignTheirContentAtTheTop() {
        listOf("today_widget_preview.xml", "week_widget_preview.xml").forEach { name ->
            val layout = File("src/main/res/layout/$name").readText()
            assertTrue("$name should align content at the top", layout.contains("android:gravity=\"top\""))
        }
    }
}
