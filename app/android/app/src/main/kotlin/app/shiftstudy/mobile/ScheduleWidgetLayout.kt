package app.shiftstudy.mobile

import java.time.LocalDate

internal enum class ScheduleWidgetLayout {
    COMPACT,
    SHORT_WIDE,
    TALL_NARROW,
    EXPANDED,
    TALL_EXPANDED,
}

internal enum class ScheduleWidgetContentAlignment {
    CENTER_VERTICAL,
    TOP,
}

internal data class ScheduleWidgetInterval(val startMillis: Long, val endMillis: Long)

internal data class ScheduleWidgetEvent(
    val id: String,
    val kind: String,
    val title: String,
    val localDate: LocalDate,
    val isDayOff: Boolean,
    val intervals: List<ScheduleWidgetInterval>,
)

internal data class ScheduleWidgetEventLine(
    val event: ScheduleWidgetEvent,
    val startMillis: Long?,
    val endMillis: Long?,
    val ongoing: Boolean,
)

internal data class WeekWidgetSelection(
    val date: LocalDate,
    val events: List<ScheduleWidgetEventLine>,
)

/** The compact 4x1 strip keeps counts; taller sizes add a short event preview. */
internal fun weekWidgetEventLimit(layout: ScheduleWidgetLayout): Int = when (layout) {
    ScheduleWidgetLayout.COMPACT, ScheduleWidgetLayout.SHORT_WIDE -> 0
    ScheduleWidgetLayout.TALL_EXPANDED -> 2
    ScheduleWidgetLayout.TALL_NARROW, ScheduleWidgetLayout.EXPANDED -> 1
}

/** Selects the current or next eventful date within the current Monday-Sunday week. */
internal fun weekWidgetSelection(
    events: List<ScheduleWidgetEvent>,
    today: LocalDate,
    nowMillis: Long,
    limit: Int,
): WeekWidgetSelection {
    require(limit >= 0)
    val weekEnd = today.minusDays((today.dayOfWeek.value - 1).toLong()).plusDays(6)
    val eventsByDate = events.asSequence()
        .filter { !it.localDate.isBefore(today) && !it.localDate.isAfter(weekEnd) }
        .distinctBy { it.id to it.localDate }
        .groupBy { it.localDate }

    var date = today
    while (!date.isAfter(weekEnd)) {
        val lines = eventsByDate[date].orEmpty().mapNotNull { event ->
            if (event.isDayOff || (event.kind == "deadline" && event.intervals.isEmpty())) {
                ScheduleWidgetEventLine(event, null, null, false)
            } else {
                val interval = event.intervals
                    .filter { it.startMillis > 0L && it.endMillis > nowMillis && it.endMillis > it.startMillis }
                    .minByOrNull { interval -> if (interval.startMillis <= nowMillis) nowMillis else interval.startMillis }
                    ?: return@mapNotNull null
                ScheduleWidgetEventLine(
                    event = event,
                    startMillis = interval.startMillis,
                    endMillis = interval.endMillis,
                    ongoing = interval.startMillis <= nowMillis,
                )
            }
        }.sortedWith(
            compareBy<ScheduleWidgetEventLine> { it.startMillis ?: Long.MAX_VALUE }
                .thenBy { it.event.id },
        )
        if (lines.isNotEmpty()) return WeekWidgetSelection(date, lines.take(limit))
        date = date.plusDays(1)
    }

    return WeekWidgetSelection(today, emptyList())
}

/** Finds the nearest date-only deadline without inventing a time of day. */
internal fun nextAllDayDeadline(
    events: Iterable<ScheduleWidgetEvent>,
    today: LocalDate,
    nextBeyondVisibleProjection: ScheduleWidgetEvent? = null,
): ScheduleWidgetEvent? = sequence {
    yieldAll(events)
    nextBeyondVisibleProjection?.let { yield(it) }
}
    .filter { it.kind == "deadline" && it.intervals.isEmpty() && !it.localDate.isBefore(today) }
    .minByOrNull { it.localDate }

/** Picks unique schedule entries that still intersect the current local day. */
internal fun todayWidgetEvents(
    events: List<ScheduleWidgetEvent>,
    today: LocalDate,
    nowMillis: Long,
    dayStartMillis: Long,
    dayEndMillis: Long,
    contentFilter: Int,
    limit: Int = 2,
): List<ScheduleWidgetEventLine> {
    fun matches(event: ScheduleWidgetEvent): Boolean = when (contentFilter) {
        ScheduleWidgetConfigureActivity.CONTENT_WORK -> event.kind == "work"
        ScheduleWidgetConfigureActivity.CONTENT_STUDY ->
            event.kind == "classSession" || event.kind == "deadline"
        else -> true
    }

    return events.asSequence()
        .filter(::matches)
        .mapNotNull { event ->
            if (event.isDayOff) {
                if (event.localDate == today) ScheduleWidgetEventLine(event, null, null, false)
                else null
            } else {
                val interval = event.intervals
                    .filter { it.endMillis > nowMillis && it.startMillis < dayEndMillis && it.endMillis > dayStartMillis }
                    .minByOrNull { interval -> if (interval.startMillis <= nowMillis) nowMillis else interval.startMillis }
                    ?: return@mapNotNull null
                ScheduleWidgetEventLine(
                    event = event,
                    startMillis = interval.startMillis,
                    endMillis = interval.endMillis,
                    ongoing = interval.startMillis <= nowMillis,
                )
            }
        }
        .distinctBy { it.event.id to it.event.localDate }
        .sortedWith(compareBy<ScheduleWidgetEventLine> { it.startMillis ?: Long.MAX_VALUE }.thenBy { it.event.id })
        .take(limit.coerceAtLeast(0))
        .toList()
}

internal fun scheduleWidgetShowsSecondTodayEvent(
    widgetType: Int,
    layout: ScheduleWidgetLayout,
): Boolean = widgetType == ScheduleWidgetConfigureActivity.TYPE_TODAY &&
    scheduleWidgetTodayEventLimit(layout) >= 2

internal fun scheduleWidgetShowsThirdTodayEvent(
    widgetType: Int,
    layout: ScheduleWidgetLayout,
): Boolean = widgetType == ScheduleWidgetConfigureActivity.TYPE_TODAY &&
    scheduleWidgetTodayEventLimit(layout) >= 3

/** Visible Today rows follow real launcher height; empty space is never filled. */
internal fun scheduleWidgetTodayEventLimit(layout: ScheduleWidgetLayout): Int = when (layout) {
    ScheduleWidgetLayout.COMPACT,
    ScheduleWidgetLayout.SHORT_WIDE,
    ScheduleWidgetLayout.TALL_NARROW -> 1
    ScheduleWidgetLayout.EXPANDED -> 2
    ScheduleWidgetLayout.TALL_EXPANDED -> 3
}

internal fun todayWidgetOverflowCount(totalCount: Int, visibleCount: Int): Int =
    (totalCount - visibleCount).coerceAtLeast(0)

internal data class ScheduleWidgetTextScale(
    val dateSp: Float,
    val countSp: Float,
    val categorySp: Float,
    val headingSp: Float,
    val detailSp: Float,
    val headingMaxLines: Int,
    val detailMaxLines: Int,
) {
    companion object {
        val COMPACT = ScheduleWidgetTextScale(12f, 11f, 11f, 14f, 10f, 1, 1)
        val SHORT_WIDE = ScheduleWidgetTextScale(12f, 12f, 11f, 16f, 13f, 1, 1)
        // A tall 2x2 tile has spare vertical room; keep its typography compact
        // so empty copy and event details do not dominate the launcher tile.
        val TALL_NARROW = ScheduleWidgetTextScale(12f, 11f, 10f, 16f, 12f, 2, 1)
        val EXPANDED = ScheduleWidgetTextScale(14f, 14f, 12f, 20f, 16f, 2, 2)
    }
}

/** Localized empty-state copy sized for the provider's selected content and bounds. */
internal fun scheduleWidgetEmptyResources(contentFilter: Int, compact: Boolean): Pair<Int, Int> {
    val title = when (contentFilter) {
        ScheduleWidgetConfigureActivity.CONTENT_WORK ->
            if (compact) R.string.schedule_widget_empty_work_compact else R.string.schedule_widget_empty_work
        ScheduleWidgetConfigureActivity.CONTENT_STUDY ->
            if (compact) R.string.schedule_widget_empty_study_compact else R.string.schedule_widget_empty_study
        ScheduleWidgetConfigureActivity.CONTENT_CLASSES ->
            if (compact) R.string.schedule_widget_empty_classes_compact else R.string.schedule_widget_empty_classes
        ScheduleWidgetConfigureActivity.CONTENT_DEADLINES ->
            if (compact) R.string.schedule_widget_empty_deadlines_compact else R.string.schedule_widget_empty_deadlines
        else -> if (compact) R.string.schedule_widget_empty_compact else R.string.schedule_widget_no_events
    }
    val detail = if (compact && contentFilter != ScheduleWidgetConfigureActivity.CONTENT_ALL) {
        R.string.schedule_widget_empty_hint_compact
    } else if (compact) {
        R.string.schedule_widget_no_upcoming_compact
    } else {
        R.string.schedule_widget_no_upcoming
    }
    return title to detail
}

/** Classifies actual launcher-provided dp bounds, not a guessed cell count. */
internal fun scheduleWidgetLayout(widthDp: Float, heightDp: Float): ScheduleWidgetLayout =
    when {
        // Some launchers give a 2x2 widget a narrow width. Only collapse its
        // content when the measured height is short too.
        widthDp < 200f && heightDp < 145f -> ScheduleWidgetLayout.COMPACT
        heightDp < 145f -> ScheduleWidgetLayout.SHORT_WIDE
        // A portrait 2x2 tile has enough height for useful event detail but
        // not enough width for expanded typography without wrapping/cropping.
        widthDp < 220f -> ScheduleWidgetLayout.TALL_NARROW
        // Expand row count only when the launcher provides both the vertical
        // room and enough width for three compact event rows.
        heightDp >= 220f -> ScheduleWidgetLayout.TALL_EXPANDED
        else -> ScheduleWidgetLayout.EXPANDED
    }

internal fun scheduleWidgetTextScale(layout: ScheduleWidgetLayout): ScheduleWidgetTextScale =
    when (layout) {
        ScheduleWidgetLayout.COMPACT -> ScheduleWidgetTextScale.COMPACT
        ScheduleWidgetLayout.SHORT_WIDE -> ScheduleWidgetTextScale.SHORT_WIDE
        ScheduleWidgetLayout.TALL_NARROW -> ScheduleWidgetTextScale.TALL_NARROW
        ScheduleWidgetLayout.EXPANDED -> ScheduleWidgetTextScale.EXPANDED
        ScheduleWidgetLayout.TALL_EXPANDED -> ScheduleWidgetTextScale.EXPANDED
    }

/** Keeps Today readable when launchers resize its wider, denser schedule view. */
internal fun scheduleWidgetTextScaleForType(
    widgetType: Int,
    layout: ScheduleWidgetLayout,
): ScheduleWidgetTextScale {
    if (widgetType != ScheduleWidgetConfigureActivity.TYPE_TODAY) {
        return scheduleWidgetTextScale(layout)
    }
    return when (layout) {
        ScheduleWidgetLayout.COMPACT ->
            ScheduleWidgetTextScale(12f, 11f, 10f, 14f, 11f, 1, 1)
        ScheduleWidgetLayout.SHORT_WIDE ->
            ScheduleWidgetTextScale(12f, 12f, 10f, 16f, 12f, 1, 1)
        ScheduleWidgetLayout.TALL_NARROW ->
            ScheduleWidgetTextScale(12f, 12f, 10f, 16f, 12f, 2, 2)
        ScheduleWidgetLayout.EXPANDED ->
            ScheduleWidgetTextScale(12f, 12f, 10f, 16f, 12f, 2, 2)
        ScheduleWidgetLayout.TALL_EXPANDED ->
            ScheduleWidgetTextScale(12f, 12f, 9f, 14f, 10f, 1, 1)
    }
}

internal fun scheduleWidgetHeadingText(
    title: String,
    widgetType: Int,
    layout: ScheduleWidgetLayout,
): String = if (
    widgetType == ScheduleWidgetConfigureActivity.TYPE_NEXT_EVENT &&
    layout == ScheduleWidgetLayout.TALL_NARROW &&
    title.length > 16 && title.none(Char::isWhitespace)
) {
    "${title.take(16)}…"
} else {
    title
}

internal fun scheduleWidgetContentAlignment(
    widgetType: Int,
    hasContent: Boolean = true,
    layout: ScheduleWidgetLayout = ScheduleWidgetLayout.EXPANDED,
): ScheduleWidgetContentAlignment =
    when {
        widgetType == ScheduleWidgetConfigureActivity.TYPE_NEXT_EVENT &&
            layout != ScheduleWidgetLayout.COMPACT && layout != ScheduleWidgetLayout.SHORT_WIDE ->
            ScheduleWidgetContentAlignment.CENTER_VERTICAL
        !hasContent && widgetType == ScheduleWidgetConfigureActivity.TYPE_TODAY ->
            ScheduleWidgetContentAlignment.CENTER_VERTICAL
        !hasContent && widgetType == ScheduleWidgetConfigureActivity.TYPE_NEXT_EVENT ->
            ScheduleWidgetContentAlignment.CENTER_VERTICAL
        else -> ScheduleWidgetContentAlignment.TOP
    }

internal fun scheduleWidgetUsesCompactEmptyCopy(
    widthDp: Float,
    layout: ScheduleWidgetLayout,
): Boolean = layout == ScheduleWidgetLayout.COMPACT || widthDp < 200f

internal fun weekWidgetSummary(counts: IntArray, compact: Boolean): String {
    require(counts.size == 7)
    val labels = listOf("M", "Tu", "W", "Th", "F", "Sa", "Su")
    return labels.indices.joinToString(if (compact) " " else "     ") { index ->
        if (compact) "${labels[index]}${counts[index]}" else "${labels[index]} ${counts[index]}"
    }
}

internal fun todayWidgetEventCountLabel(count: Int): String {
    val safeCount = count.coerceAtLeast(0)
    val noun = if (safeCount == 1) "event" else "events"
    return "Today · $safeCount $noun"
}
