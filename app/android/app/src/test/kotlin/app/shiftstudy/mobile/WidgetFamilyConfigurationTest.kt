package app.shiftstudy.mobile

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class WidgetFamilyConfigurationTest {
    @Test
    fun nextClassAndDeadlineConfigurationUseTheirOwnFamilyLabels() {
        assertEquals(
            "Next class layout is fixed for this widget. Resize it on your Home screen.",
            widgetFixedFamilyLayoutMessage(ScheduleWidgetConfigureActivity.CONTENT_CLASSES),
        )
        assertEquals(
            "Upcoming deadline layout is fixed for this widget. Resize it on your Home screen.",
            widgetFixedFamilyLayoutMessage(ScheduleWidgetConfigureActivity.CONTENT_DEADLINES),
        )
    }

    @Test
    fun nextClassAndDeadlinePreviewsUseFamilySpecificDetails() {
        assertEquals(
            "Next class",
            widgetFixedFamilyPreviewDetail(ScheduleWidgetConfigureActivity.CONTENT_CLASSES, hasEvent = true),
        )
        assertEquals(
            "Add a class to see the next one here.",
            widgetFixedFamilyPreviewDetail(ScheduleWidgetConfigureActivity.CONTENT_CLASSES, hasEvent = false),
        )
        assertEquals(
            "Upcoming deadline",
            widgetFixedFamilyPreviewDetail(ScheduleWidgetConfigureActivity.CONTENT_DEADLINES, hasEvent = true),
        )
        assertEquals(
            "Add a deadline to see it here.",
            widgetFixedFamilyPreviewDetail(ScheduleWidgetConfigureActivity.CONTENT_DEADLINES, hasEvent = false),
        )
    }

    @Test
    fun nextClassAndDeadlineLayoutLabelsUseTheirOwnWidgetFamilyNames() {
        assertEquals(
            "Next class · 2 × 2",
            widgetConfigurationTypeLabel(
                ScheduleWidgetConfigureActivity.TYPE_NEXT_EVENT,
                ScheduleWidgetConfigureActivity.CONTENT_CLASSES,
                "Next event · 2 × 2",
            ),
        )
        assertEquals(
            "Upcoming deadline · 2 × 2",
            widgetConfigurationTypeLabel(
                ScheduleWidgetConfigureActivity.TYPE_NEXT_EVENT,
                ScheduleWidgetConfigureActivity.CONTENT_DEADLINES,
                "Next event · 2 × 2",
            ),
        )
        assertEquals(
            "Next event · 2 × 2",
            widgetConfigurationTypeLabel(
                ScheduleWidgetConfigureActivity.TYPE_NEXT_EVENT,
                ScheduleWidgetConfigureActivity.CONTENT_ALL,
                "Next event · 2 × 2",
            ),
        )
    }

    @Test
    fun contentFiltersSelectDedicatedClassAndDeadlineProjections() {
        assertEquals("all", nextProjectionKey(ScheduleWidgetConfigureActivity.CONTENT_ALL))
        assertEquals("work", nextProjectionKey(ScheduleWidgetConfigureActivity.CONTENT_WORK))
        assertEquals("study", nextProjectionKey(ScheduleWidgetConfigureActivity.CONTENT_STUDY))
        assertEquals("class", nextProjectionKey(ScheduleWidgetConfigureActivity.CONTENT_CLASSES))
        assertEquals("deadline", nextProjectionKey(ScheduleWidgetConfigureActivity.CONTENT_DEADLINES))
        assertEquals(
            true,
            matchesWidgetContentFilter(ScheduleWidgetConfigureActivity.CONTENT_CLASSES, "classSession"),
        )
        assertEquals(
            false,
            matchesWidgetContentFilter(ScheduleWidgetConfigureActivity.CONTENT_CLASSES, "deadline"),
        )
        assertEquals(
            true,
            matchesWidgetContentFilter(ScheduleWidgetConfigureActivity.CONTENT_DEADLINES, "deadline"),
        )
        assertEquals(
            false,
            matchesWidgetContentFilter(ScheduleWidgetConfigureActivity.CONTENT_DEADLINES, "classSession"),
        )
    }

    @Test
    fun todayWidgetPreviewUsesSingularForOneScheduledEvent() {
        assertEquals("Today · 1 event", todayWidgetEventCountLabel(1))
        assertEquals("Today · 0 events", todayWidgetEventCountLabel(0))
        assertEquals("Today · 3 events", todayWidgetEventCountLabel(3))
    }

    @Test
    fun pinRequestSelectsTheRequestedWidgetProvider() {
        assertEquals(
            "app.shiftstudy.mobile.ScheduleWidgetProvider",
            WidgetPinProvider.className("nextEvent"),
        )
        assertEquals(
            "app.shiftstudy.mobile.TodayWidgetProvider",
            WidgetPinProvider.className("today"),
        )
        assertEquals(
            "app.shiftstudy.mobile.WeekWidgetProvider",
            WidgetPinProvider.className("week"),
        )
        assertEquals(
            "app.shiftstudy.mobile.NextClassWidgetProvider",
            WidgetPinProvider.className("nextClass"),
        )
        assertEquals(
            "app.shiftstudy.mobile.DeadlineWidgetProvider",
            WidgetPinProvider.className("upcomingDeadline"),
        )
    }

    @Test(expected = IllegalArgumentException::class)
    fun pinRequestRejectsUnknownWidgetProvider() {
        WidgetPinProvider.className("other")
    }

    @Test
    fun launcherPreviewCatalogCoversEveryWidgetFamilyAndRepublishesExistingInstalls() {
        val previews = WidgetPickerPreviewCatalog.entries()

        assertEquals(
            setOf(
                ScheduleWidgetProvider::class.java,
                TodayWidgetProvider::class.java,
                WeekWidgetProvider::class.java,
                NextClassWidgetProvider::class.java,
                DeadlineWidgetProvider::class.java,
            ),
            previews.map { it.providerClass }.toSet(),
        )
        assertEquals(
            setOf(
                R.layout.schedule_widget_preview,
                R.layout.today_widget_preview,
                R.layout.week_widget_preview,
                R.layout.next_class_widget_preview,
                R.layout.deadline_widget_preview,
            ),
            previews.map { it.layoutResource }.toSet(),
        )
        assertEquals(4, WidgetPickerPreviewCatalog.version)
    }

    @Test
    fun dedicatedFamiliesKeepTheirContentFilter() {
        assertEquals(
            ScheduleWidgetConfigureActivity.CONTENT_CLASSES,
            ScheduleWidgetProvider.defaultContent("app.shiftstudy.mobile.NextClassWidgetProvider"),
        )
        assertEquals(
            ScheduleWidgetConfigureActivity.CONTENT_DEADLINES,
            ScheduleWidgetProvider.defaultContent("app.shiftstudy.mobile.DeadlineWidgetProvider"),
        )
    }

    @Test
    fun newProviderInstancesKeepTheirPresetLayout() {
        assertEquals(
            ScheduleWidgetConfigureActivity.TYPE_NEXT_EVENT,
            ScheduleWidgetProvider.fixedConfigurationType(
                ScheduleWidgetProvider::class.java.name,
                hasSavedType = false,
            ),
        )
        assertEquals(
            ScheduleWidgetConfigureActivity.TYPE_TODAY,
            ScheduleWidgetProvider.fixedConfigurationType(
                TodayWidgetProvider::class.java.name,
                hasSavedType = false,
            ),
        )
        assertEquals(
            ScheduleWidgetConfigureActivity.TYPE_WEEK,
            ScheduleWidgetProvider.fixedConfigurationType(
                WeekWidgetProvider::class.java.name,
                hasSavedType = false,
            ),
        )
    }

    @Test
    fun savedLegacyScheduleWidgetKeepsItsExistingCustomizableLayout() {
        assertNull(
            ScheduleWidgetProvider.fixedConfigurationType(
                ScheduleWidgetProvider::class.java.name,
                hasSavedType = true,
            ),
        )
    }

    @Test
    fun fixedWidgetFamiliesUseTheirOwnProjectionWithoutSavedSettings() {
        assertEquals(
            ScheduleWidgetConfigureActivity.CONTENT_CLASSES,
            widgetContentForProvider(NextClassWidgetProvider::class.java.name, null),
        )
        assertEquals(
            ScheduleWidgetConfigureActivity.CONTENT_CLASSES,
            widgetContentForProvider(
                NextClassWidgetProvider::class.java.name,
                ScheduleWidgetConfigureActivity.CONTENT_ALL,
            ),
        )
        assertEquals(
            ScheduleWidgetConfigureActivity.CONTENT_DEADLINES,
            widgetContentForProvider(DeadlineWidgetProvider::class.java.name, null),
        )
        assertEquals(
            ScheduleWidgetConfigureActivity.CONTENT_WORK,
            widgetContentForProvider(
                ScheduleWidgetProvider::class.java.name,
                ScheduleWidgetConfigureActivity.CONTENT_WORK,
            ),
        )
        assertEquals(
            ScheduleWidgetConfigureActivity.CONTENT_ALL,
            widgetContentForProvider(ScheduleWidgetProvider::class.java.name, null),
        )
    }

    @Test
    fun narrowEmptyWidgetsUseConciseCopyForEachFixedCategory() {
        assertEquals(
            R.string.schedule_widget_empty_classes_compact to R.string.schedule_widget_empty_hint_compact,
            scheduleWidgetEmptyResources(
                ScheduleWidgetConfigureActivity.CONTENT_CLASSES,
                compact = true,
            ),
        )
        assertEquals(
            R.string.schedule_widget_empty_deadlines_compact to R.string.schedule_widget_empty_hint_compact,
            scheduleWidgetEmptyResources(
                ScheduleWidgetConfigureActivity.CONTENT_DEADLINES,
                compact = true,
            ),
        )
        assertEquals(
            R.string.schedule_widget_empty_work_compact to R.string.schedule_widget_empty_hint_compact,
            scheduleWidgetEmptyResources(
                ScheduleWidgetConfigureActivity.CONTENT_WORK,
                compact = true,
            ),
        )
    }

    @Test
    fun expandedEmptyWidgetsKeepTheExistingExplanatoryCopy() {
        assertEquals(
            R.string.schedule_widget_empty_classes to R.string.schedule_widget_no_upcoming,
            scheduleWidgetEmptyResources(
                ScheduleWidgetConfigureActivity.CONTENT_CLASSES,
                compact = false,
            ),
        )
    }

    @Test
    fun tallNarrowTwoByTwoWidgetUsesReadableSingleLineContent() {
        assertEquals(
            ScheduleWidgetLayout.TALL_NARROW,
            scheduleWidgetLayout(widthDp = 196f, heightDp = 272f),
        )
        assertEquals(
            ScheduleWidgetTextScale.TALL_NARROW,
            scheduleWidgetTextScale(ScheduleWidgetLayout.TALL_NARROW),
        )
        assertEquals(
            ScheduleWidgetLayout.COMPACT,
            scheduleWidgetLayout(widthDp = 175f, heightDp = 106f),
        )
        assertEquals(
            ScheduleWidgetLayout.SHORT_WIDE,
            scheduleWidgetLayout(widthDp = 360f, heightDp = 106f),
        )
    }

    @Test
    fun narrowWidgetKeepsEmptyStateCopyShortEvenWhenTall() {
        assertEquals(
            true,
            scheduleWidgetUsesCompactEmptyCopy(
                widthDp = 196f,
                layout = ScheduleWidgetLayout.TALL_NARROW,
            ),
        )
        assertEquals(
            false,
            scheduleWidgetUsesCompactEmptyCopy(
                widthDp = 360f,
                layout = ScheduleWidgetLayout.EXPANDED,
            ),
        )
    }
}
