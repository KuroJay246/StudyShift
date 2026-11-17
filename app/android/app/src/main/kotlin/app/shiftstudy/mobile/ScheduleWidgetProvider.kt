package app.shiftstudy.mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.util.SizeF
import android.view.View
import android.view.Gravity
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter

internal fun nextProjectionKey(contentFilter: Int): String = when (contentFilter) {
    ScheduleWidgetConfigureActivity.CONTENT_WORK -> "work"
    ScheduleWidgetConfigureActivity.CONTENT_STUDY -> "study"
    ScheduleWidgetConfigureActivity.CONTENT_CLASSES -> "class"
    ScheduleWidgetConfigureActivity.CONTENT_DEADLINES -> "deadline"
    else -> "all"
}

internal fun matchesWidgetContentFilter(contentFilter: Int, kind: String): Boolean = when (contentFilter) {
    ScheduleWidgetConfigureActivity.CONTENT_WORK -> kind == "work"
    ScheduleWidgetConfigureActivity.CONTENT_STUDY -> kind == "classSession" || kind == "deadline"
    ScheduleWidgetConfigureActivity.CONTENT_CLASSES -> kind == "classSession"
    ScheduleWidgetConfigureActivity.CONTENT_DEADLINES -> kind == "deadline"
    else -> true
}

internal fun isSupportedWidgetSnapshotSchema(version: Int): Boolean = version in 4..7

internal fun widgetContentForProvider(providerClassName: String, savedContent: Int?): Int =
    ScheduleWidgetProvider.fixedContent(providerClassName)
        ?: savedContent
        ?: ScheduleWidgetConfigureActivity.CONTENT_ALL

internal fun shouldRefreshWidgetProvider(action: String?): Boolean = action in setOf(
    Intent.ACTION_DATE_CHANGED,
    Intent.ACTION_TIME_CHANGED,
    Intent.ACTION_TIMEZONE_CHANGED,
    Intent.ACTION_CONFIGURATION_CHANGED,
    Intent.ACTION_MY_PACKAGE_REPLACED,
)

open class ScheduleWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        appWidgetIds.forEach { ScheduleWidgetViews.update(context, manager, it) }
        ScheduleWidgetRefreshScheduler.reschedule(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, manager, appWidgetId, newOptions)
        ScheduleWidgetViews.update(context, manager, appWidgetId)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val preferences = context.getSharedPreferences(
            ScheduleWidgetConfigureActivity.PREFERENCES,
            Context.MODE_PRIVATE,
        )
        preferences.edit().also { editor ->
            appWidgetIds.forEach { widgetId ->
                editor.remove(ScheduleWidgetConfigureActivity.contentKey(widgetId))
                editor.remove(ScheduleWidgetConfigureActivity.appearanceKey(widgetId))
                editor.remove(ScheduleWidgetConfigureActivity.typeKey(widgetId))
            }
        }.apply()
        ScheduleWidgetRefreshScheduler.reschedule(context)
        super.onDeleted(context, appWidgetIds)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (shouldRefreshWidgetProvider(intent.action)) {
            updateProvider(context, javaClass)
        }
    }

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            widgetProviders.forEach { provider ->
                val component = ComponentName(context, provider)
                manager.getAppWidgetIds(component).forEach {
                    ScheduleWidgetViews.update(context, manager, it)
                }
            }
        }

        private fun updateProvider(context: Context, provider: Class<out ScheduleWidgetProvider>) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, provider)
            manager.getAppWidgetIds(component).forEach {
                ScheduleWidgetViews.update(context, manager, it)
            }
        }

        fun updateOne(context: Context, widgetId: Int) {
            ScheduleWidgetViews.update(context, AppWidgetManager.getInstance(context), widgetId)
        }

        fun defaultType(providerClassName: String): Int = when (providerClassName) {
            TodayWidgetProvider::class.java.name -> ScheduleWidgetConfigureActivity.TYPE_TODAY
            WeekWidgetProvider::class.java.name -> ScheduleWidgetConfigureActivity.TYPE_WEEK
            else -> ScheduleWidgetConfigureActivity.TYPE_NEXT_EVENT
        }

        fun defaultContent(providerClassName: String): Int = when (providerClassName) {
            NextClassWidgetProvider::class.java.name -> ScheduleWidgetConfigureActivity.CONTENT_CLASSES
            DeadlineWidgetProvider::class.java.name -> ScheduleWidgetConfigureActivity.CONTENT_DEADLINES
            else -> ScheduleWidgetConfigureActivity.CONTENT_ALL
        }

        fun fixedContent(providerClassName: String): Int? = when (providerClassName) {
            NextClassWidgetProvider::class.java.name -> ScheduleWidgetConfigureActivity.CONTENT_CLASSES
            DeadlineWidgetProvider::class.java.name -> ScheduleWidgetConfigureActivity.CONTENT_DEADLINES
            else -> null
        }

        /** New launcher entries stay aligned with their advertised family and size. */
        fun fixedConfigurationType(providerClassName: String, hasSavedType: Boolean): Int? =
            if (providerClassName == ScheduleWidgetProvider::class.java.name && hasSavedType) {
                null // Existing generic widgets keep their previously configurable layout.
            } else {
                defaultType(providerClassName)
            }

        val widgetProviders = listOf(
            ScheduleWidgetProvider::class.java,
            TodayWidgetProvider::class.java,
            WeekWidgetProvider::class.java,
            NextClassWidgetProvider::class.java,
            DeadlineWidgetProvider::class.java,
        )
    }
}

class TodayWidgetProvider : ScheduleWidgetProvider()

class WeekWidgetProvider : ScheduleWidgetProvider()

class NextClassWidgetProvider : ScheduleWidgetProvider()

class DeadlineWidgetProvider : ScheduleWidgetProvider()

private object ScheduleWidgetViews {
    private val dateFormatter = DateTimeFormatter.ofPattern("EEE, MMM d")
    private val timeFormatter = DateTimeFormatter.ofPattern("h:mm a")

    fun update(context: Context, manager: AppWidgetManager, widgetId: Int) {
        val options = manager.getAppWidgetOptions(widgetId)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            @Suppress("DEPRECATION")
            val sizes = options.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES)
            if (!sizes.isNullOrEmpty()) {
                val layouts = sizes.associateWith { size ->
                    render(context, widgetId, size.width, size.height)
                }
                manager.updateAppWidget(widgetId, RemoteViews(layouts))
                return
            }
        }

        val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 110).toFloat()
        val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110).toFloat()
        manager.updateAppWidget(widgetId, render(context, widgetId, width, height))
    }

    private fun render(context: Context, widgetId: Int, widthDp: Float, heightDp: Float): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.schedule_widget)
        val instancePreferences = context.getSharedPreferences(
            ScheduleWidgetConfigureActivity.PREFERENCES,
            Context.MODE_PRIVATE,
        )
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val providerClassName = appWidgetManager.getAppWidgetInfo(widgetId)?.provider?.className.orEmpty()
        val contentKey = ScheduleWidgetConfigureActivity.contentKey(widgetId)
        val savedContent = if (instancePreferences.contains(contentKey)) {
            instancePreferences.getInt(contentKey, ScheduleWidgetConfigureActivity.CONTENT_ALL)
        } else {
            null
        }
        val contentFilter = widgetContentForProvider(providerClassName, savedContent)
        val widgetType = instancePreferences.getInt(
            ScheduleWidgetConfigureActivity.typeKey(widgetId),
            ScheduleWidgetProvider.defaultType(providerClassName),
        )
        val appearance = instancePreferences.getInt(
            ScheduleWidgetConfigureActivity.appearanceKey(widgetId),
            ScheduleWidgetConfigureActivity.APPEARANCE_SYSTEM,
        )
        // Use the launcher's measured bounds. Samsung's 4x2 widget is only
        // about 179dp tall; a 220dp cutoff incorrectly made it look compact.
        val layout = scheduleWidgetLayout(widthDp, heightDp)
        val compact = layout == ScheduleWidgetLayout.COMPACT
        val shortWide = layout == ScheduleWidgetLayout.SHORT_WIDE
        val tallNarrow = layout == ScheduleWidgetLayout.TALL_NARROW
        val textScale = scheduleWidgetTextScaleForType(widgetType, layout)
        val shortEmptyCopy = scheduleWidgetUsesCompactEmptyCopy(widthDp, layout)
        val paddingDp = if (scheduleWidgetShowsSecondTodayEvent(widgetType, layout)) 12 else when (layout) {
            ScheduleWidgetLayout.COMPACT, ScheduleWidgetLayout.SHORT_WIDE -> 10
            ScheduleWidgetLayout.TALL_NARROW -> 12
            ScheduleWidgetLayout.EXPANDED -> 16
            ScheduleWidgetLayout.TALL_EXPANDED -> 12
        }
        val paddingPx = (paddingDp * context.resources.displayMetrics.density).toInt()
        views.setViewPadding(R.id.widget_card, paddingPx, paddingPx, paddingPx, paddingPx)

        val systemDark = (context.resources.configuration.uiMode and
            android.content.res.Configuration.UI_MODE_NIGHT_MASK) ==
            android.content.res.Configuration.UI_MODE_NIGHT_YES
        when (appearance) {
            ScheduleWidgetConfigureActivity.APPEARANCE_LIGHT -> {
                views.setInt(R.id.widget_card, "setBackgroundResource", R.drawable.studyshift_widget_light_background)
                setTextColors(views, Color.rgb(15, 23, 42), Color.rgb(71, 85, 105))
            }
            ScheduleWidgetConfigureActivity.APPEARANCE_DARK -> {
                views.setInt(R.id.widget_card, "setBackgroundResource", R.drawable.studyshift_widget_dark_background)
                setTextColors(views, Color.rgb(248, 250, 255), Color.rgb(184, 198, 222))
            }
            ScheduleWidgetConfigureActivity.APPEARANCE_GLASS -> {
                views.setInt(
                    R.id.widget_card,
                    "setBackgroundResource",
                    if (systemDark) R.drawable.studyshift_widget_glass_dark_background
                    else R.drawable.studyshift_widget_glass_light_background,
                )
                if (systemDark) setTextColors(views, Color.WHITE, Color.rgb(226, 232, 240))
                else setTextColors(views, Color.rgb(15, 23, 42), Color.rgb(51, 65, 85))
            }
            ScheduleWidgetConfigureActivity.APPEARANCE_TRANSPARENT -> {
                views.setInt(R.id.widget_card, "setBackgroundColor", Color.TRANSPARENT)
                val savedTheme = context.getSharedPreferences("startup_appearance", Context.MODE_PRIVATE)
                    .getString("theme", "system")
                val darkTextBackground = when (savedTheme) {
                    "dark" -> true
                    "light" -> false
                    else -> systemDark
                }
                if (darkTextBackground) {
                    setTextColors(views, Color.WHITE, Color.rgb(226, 232, 240))
                } else {
                    setTextColors(views, Color.rgb(15, 23, 42), Color.rgb(51, 65, 85))
                }
            }
        }

        val snapshot = context.getSharedPreferences("shift_study_widget", Context.MODE_PRIVATE)
            .getString("schedule_snapshot_v1", null)
        val content = runCatching { snapshot?.let(::JSONObject) }
            .getOrNull()
            ?.takeIf { isSupportedWidgetSnapshotSchema(it.optInt("schemaVersion")) }
        val generatedAt = content?.optString("generatedAtUtc")
            ?.let { runCatching { Instant.parse(it) }.getOrNull() }
        val unavailable = content == null || generatedAt == null
        val today = LocalDate.now()
        val coverageStart = content?.optString("localDate")
            ?.let { runCatching { LocalDate.parse(it) }.getOrNull() }
        val coverageEnd = content?.optString("throughDate")
            ?.let { runCatching { LocalDate.parse(it) }.getOrNull() }
        val schemaVersion = content?.optInt("schemaVersion") ?: 0
        // Version 5 and later carry each occurrence's local date, so a native refresh
        // can move through the saved 30-day projection after midnight without
        // displaying yesterday's count or next event. Older projections only
        // describe today's list and must not be guessed across a date change.
        val stale = coverageStart == null || coverageEnd == null ||
            today.isBefore(coverageStart) || today.isAfter(coverageEnd) ||
            (schemaVersion < 5 && today != coverageStart)
        val nowMillis = Instant.now().toEpochMilli()
        val dayStart = today.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
        val dayEnd = today.plusDays(1).atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
        val upcoming = content?.optJSONArray("upcoming")
        val projectedEvents = buildList {
            listOf("today", "upcoming").forEach { key ->
                val events = content?.optJSONArray(key) ?: return@forEach
                for (index in 0 until events.length()) {
                    events.optJSONObject(index)?.let { add(it) }
                }
            }
        }
        val todayEvents = todayWidgetEvents(
            events = projectedEvents.mapNotNull(::parseWidgetEvent),
            today = today,
            nowMillis = nowMillis,
            dayStartMillis = dayStart,
            dayEndMillis = dayEnd,
            contentFilter = contentFilter,
            limit = if (widgetType == ScheduleWidgetConfigureActivity.TYPE_TODAY) {
                scheduleWidgetTodayEventLimit(layout)
            } else {
                1
            },
        )
        views.setInt(
            R.id.widget_card,
            "setGravity",
            when (scheduleWidgetContentAlignment(widgetType, todayEvents.isNotEmpty(), layout)) {
                ScheduleWidgetContentAlignment.CENTER_VERTICAL -> Gravity.CENTER_VERTICAL
                ScheduleWidgetContentAlignment.TOP -> Gravity.TOP
            },
        )
        fun matchesFilter(event: JSONObject): Boolean =
            matchesWidgetContentFilter(contentFilter, event.optString("kind"))
        var todayCount = (content?.optJSONArray("today")?.let { events ->
            (0 until events.length()).count { index ->
                events.optJSONObject(index)?.let(::matchesFilter) == true
            }
        } ?: 0)
        var next: JSONObject? = null
        var nextStart = Long.MAX_VALUE
        var nextEnd = Long.MAX_VALUE
        var ongoing = false
        if (upcoming != null && !stale) {
            if (schemaVersion >= 5) {
                todayCount = (0 until upcoming.length()).count { index ->
                    upcoming.optJSONObject(index)?.let { event ->
                        event.optString("localDate") == today.toString() && matchesFilter(event)
                    } == true
                }
            }
            for (index in 0 until upcoming.length()) {
                val event = upcoming.optJSONObject(index) ?: continue
                if (!matchesFilter(event)) continue
                // An all-day day off is useful in Today's list, but it is not
                // a timed event that should hide the next upcoming shift.
                if (event.optBoolean("isDayOff")) continue
                val intervals = event.optJSONArray("intervals") ?: continue
                for (intervalIndex in 0 until intervals.length()) {
                    val interval = intervals.optJSONObject(intervalIndex) ?: continue
                    val start = interval.optLong("startEpochMillis", 0L)
                    val end = interval.optLong("endEpochMillis", 0L)
                    if (start <= nowMillis && end > nowMillis && end < nextEnd) {
                        next = event
                        nextStart = start
                        nextEnd = end
                        ongoing = true
                    } else if (!ongoing && start > nowMillis && end > nowMillis && start < nextStart) {
                        next = event
                        nextStart = start
                        nextEnd = end
                    }
                }
            }
        }
        // The visible projection is deliberately bounded to 30 days. Keep a
        // separately queried next event so a sparse schedule beyond that
        // window still appears in the Next Event widget and filtered variants.
        if (next == null && !stale) {
            val fallback = content?.optJSONObject("nextByFilter")
                ?.optJSONObject(nextProjectionKey(contentFilter))
            val interval = fallback?.optJSONArray("intervals")?.optJSONObject(0)
            if (fallback != null && interval != null) {
                next = fallback
                nextStart = interval.optLong("startEpochMillis", Long.MAX_VALUE)
                nextEnd = interval.optLong("endEpochMillis", Long.MAX_VALUE)
            }
        }
        if (next == null && contentFilter == ScheduleWidgetConfigureActivity.CONTENT_DEADLINES &&
            upcoming != null && !stale
        ) {
            val events = (0 until upcoming.length()).mapNotNull { index ->
                upcoming.optJSONObject(index)?.let(::parseWidgetEvent)
            }
            val extendedDeadline = content.optJSONObject("nextAllDayByFilter")
                ?.optJSONObject(nextProjectionKey(contentFilter))
            val extendedEvent = extendedDeadline?.let(::parseWidgetEvent)
            val selected = nextAllDayDeadline(events, today, extendedEvent)
            if (selected != null) {
                val candidates = (0 until upcoming.length()).mapNotNull(upcoming::optJSONObject) +
                    listOfNotNull(extendedDeadline)
                next = candidates.firstOrNull { event ->
                    event.optString("kind") == "deadline" &&
                        event.optString("id") == selected.id &&
                        event.optString("localDate") == selected.localDate.toString() &&
                        event.optJSONArray("intervals")?.length() == 0
                }
                if (next != null) {
                    val dueDate = selected.localDate
                    nextStart = dueDate.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
                    nextEnd = dueDate.plusDays(1).atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
                }
            }
        }

        val monday = today.minusDays((today.dayOfWeek.value - 1).toLong())
        val sunday = monday.plusDays(6)
        val weekCounts = IntArray(7)
        if (upcoming != null && !stale && widgetType == ScheduleWidgetConfigureActivity.TYPE_WEEK) {
            for (index in 0 until upcoming.length()) {
                val event = upcoming.optJSONObject(index) ?: continue
                if (!matchesFilter(event)) continue
                val eventDate = event.optString("localDate").let {
                    runCatching { LocalDate.parse(it) }.getOrNull()
                } ?: continue
                if (!eventDate.isBefore(monday) && !eventDate.isAfter(sunday)) {
                    weekCounts[eventDate.dayOfWeek.value - 1]++
                }
            }
        }

        views.setTextViewText(R.id.widget_date, today.format(dateFormatter))
        views.setViewVisibility(
            R.id.widget_date,
            if (compact || (shortWide && widgetType != ScheduleWidgetConfigureActivity.TYPE_WEEK)) {
                View.GONE
            } else {
                View.VISIBLE
            },
        )
        views.setViewVisibility(R.id.widget_today_count, View.GONE)
        views.setViewVisibility(R.id.widget_category, View.GONE)
        views.setViewVisibility(R.id.widget_second_category, View.GONE)
        views.setViewVisibility(R.id.widget_second_heading, View.GONE)
        views.setViewVisibility(R.id.widget_second_detail, View.GONE)
        views.setViewVisibility(R.id.widget_third_category, View.GONE)
        views.setViewVisibility(R.id.widget_third_heading, View.GONE)
        views.setViewVisibility(R.id.widget_third_detail, View.GONE)
        views.setViewVisibility(R.id.widget_today_more, View.GONE)
        when {
            unavailable || upcoming == null -> {
                views.setTextViewText(R.id.widget_heading, context.getString(R.string.schedule_widget_unavailable))
                views.setTextViewText(R.id.widget_detail, context.getString(R.string.schedule_widget_open_app))
            }
            stale -> {
                views.setTextViewText(R.id.widget_heading, context.getString(R.string.schedule_widget_stale))
                views.setTextViewText(R.id.widget_detail, context.getString(R.string.schedule_widget_open_app))
            }
            widgetType == ScheduleWidgetConfigureActivity.TYPE_WEEK -> {
                val total = weekCounts.sum()
                val eventLimit = weekWidgetEventLimit(layout)
                if (eventLimit == 0) {
                    views.setTextViewText(
                        R.id.widget_date,
                        "${monday.format(dateFormatter)} – ${sunday.format(dateFormatter)}",
                    )
                    views.setTextViewText(
                        R.id.widget_heading,
                        "This week · $total ${if (total == 1) "event" else "events"}",
                    )
                    views.setTextViewText(
                        R.id.widget_detail,
                        weekWidgetSummary(weekCounts, compact || tallNarrow),
                    )
                } else {
                    val selection = weekWidgetSelection(
                        events = projectedEvents.mapNotNull(::parseWidgetEvent)
                            .filter { matchesWidgetContentFilter(contentFilter, it.kind) },
                        today = today,
                        nowMillis = nowMillis,
                        limit = eventLimit,
                    )
                    val selectedDate = selection.date.format(dateFormatter)
                    views.setTextViewText(
                        R.id.widget_date,
                        if (selection.date == today) "Today · $selectedDate" else selectedDate,
                    )
                    views.setTextViewText(
                        R.id.widget_today_count,
                        "This week · $total ${if (total == 1) "event" else "events"}",
                    )
                    views.setViewVisibility(R.id.widget_today_count, View.VISIBLE)
                    if (selection.events.isEmpty()) {
                        views.setTextViewText(
                            R.id.widget_heading,
                            context.getString(R.string.schedule_widget_no_upcoming_compact),
                        )
                        views.setTextViewText(
                            R.id.widget_detail,
                            context.getString(R.string.schedule_widget_open_app),
                        )
                    } else {
                        selection.events.forEachIndexed { index, event ->
                            writeTodayEventLine(context, views, event, index)
                        }
                    }
                }
            }
            widgetType == ScheduleWidgetConfigureActivity.TYPE_TODAY && todayEvents.isNotEmpty() -> {
                views.setTextViewText(
                    R.id.widget_date,
                    "${today.format(dateFormatter)} · ${todayCount} ${if (todayCount == 1) "event" else "events"}",
                )
                views.setTextViewTextSize(
                    R.id.widget_date,
                    android.util.TypedValue.COMPLEX_UNIT_SP,
                    minOf(textScale.dateSp, 12f),
                )
                todayEvents.forEachIndexed { index, event ->
                    writeTodayEventLine(context, views, event, position = index)
                }
                val moreCount = todayWidgetOverflowCount(todayCount, todayEvents.size)
                if (moreCount > 0) {
                    views.setTextViewText(
                        R.id.widget_today_more,
                        context.getString(R.string.schedule_widget_more_events, moreCount),
                    )
                    views.setViewVisibility(R.id.widget_today_more, View.VISIBLE)
                }
            }
            widgetType == ScheduleWidgetConfigureActivity.TYPE_TODAY &&
                next != null && next.optString("localDate") != today.toString() &&
                !(nextStart < dayEnd && nextEnd > nowMillis) -> {
                views.setTextViewText(R.id.widget_heading, context.getString(R.string.schedule_widget_no_events))
                views.setTextViewText(R.id.widget_detail, context.getString(R.string.schedule_widget_no_upcoming))
            }
            next == null -> {
                val emptyCopy = scheduleWidgetEmptyResources(contentFilter, shortEmptyCopy)
                val emptyTitle = if (todayCount > 0) {
                    context.resources.getQuantityString(
                        R.plurals.schedule_widget_today_count,
                        todayCount,
                        todayCount,
                    )
                } else {
                    context.getString(emptyCopy.first)
                }
                views.setTextViewText(R.id.widget_heading, emptyTitle)
                views.setTextViewText(R.id.widget_detail, context.getString(emptyCopy.second))
            }
            else -> {
                if (!compact && !shortWide) {
                    val summary = if (widgetType == ScheduleWidgetConfigureActivity.TYPE_NEXT_EVENT) {
                        if (next.optString("kind") == "deadline" &&
                            next.optJSONArray("intervals")?.length() == 0
                        ) {
                            context.getString(R.string.schedule_widget_all_day_deadline)
                        } else if (ongoing) {
                            context.getString(R.string.schedule_widget_in_progress_short)
                        } else {
                            val minutes = ((nextStart - nowMillis) / 60_000).coerceAtLeast(0)
                            val remaining = if (minutes >= 60) {
                                "${minutes / 60}h ${minutes % 60}m"
                            } else {
                                "${minutes}m"
                            }
                            context.getString(R.string.schedule_widget_next_up_in, remaining)
                        }
                    } else {
                        context.resources.getQuantityString(
                            R.plurals.schedule_widget_today_count,
                            todayCount,
                            todayCount,
                        )
                    }
                    views.setTextViewText(R.id.widget_today_count, summary)
                    views.setViewVisibility(R.id.widget_today_count, View.VISIBLE)
                }
                val title = next.optString("title").ifBlank {
                    context.getString(R.string.schedule_widget_event)
                }
                val (category, categoryColor) = when (next.optString("kind")) {
                    "work" -> context.getString(R.string.schedule_widget_work) to Color.rgb(147, 197, 253)
                    "classSession" -> context.getString(R.string.schedule_widget_study) to Color.rgb(196, 181, 253)
                    "personal" -> context.getString(R.string.schedule_widget_personal) to Color.rgb(203, 213, 225)
                    "deadline" -> context.getString(R.string.schedule_widget_deadline) to Color.rgb(251, 191, 36)
                    else -> context.getString(R.string.schedule_widget_event) to Color.WHITE
                }
                views.setTextViewText(R.id.widget_category, category)
                views.setTextColor(R.id.widget_category, categoryColor)
                views.setViewVisibility(R.id.widget_category, View.VISIBLE)
                val startTime = Instant.ofEpochMilli(nextStart).atZone(ZoneId.systemDefault())
                val endTime = Instant.ofEpochMilli(nextEnd).atZone(ZoneId.systemDefault())
                val formattedTime = startTime.format(timeFormatter)
                if (widgetType == ScheduleWidgetConfigureActivity.TYPE_NEXT_EVENT && !compact && !shortWide) {
                    views.setTextViewText(R.id.widget_date, startTime.format(dateFormatter))
                }
                views.setTextViewText(
                    R.id.widget_heading,
                    scheduleWidgetHeadingText(title, widgetType, layout),
                )
                val detail = if (next.optString("kind") == "deadline" &&
                    next.optJSONArray("intervals")?.length() == 0
                ) {
                    context.getString(R.string.schedule_widget_due_on, startTime.format(dateFormatter))
                } else if (ongoing) {
                    val endsAt = Instant.ofEpochMilli(nextEnd)
                        .atZone(ZoneId.systemDefault())
                        .format(timeFormatter)
                    context.getString(
                        if (widgetType == ScheduleWidgetConfigureActivity.TYPE_NEXT_EVENT) {
                            R.string.schedule_widget_ends_at
                        } else {
                            R.string.schedule_widget_in_progress
                        },
                        endsAt,
                    )
                } else if (startTime.toLocalDate() == endTime.toLocalDate()) {
                    "$formattedTime – ${endTime.format(timeFormatter)}"
                } else {
                    "$formattedTime – ${endTime.format(dateFormatter)} ${endTime.format(timeFormatter)}"
                }
                views.setTextViewText(R.id.widget_detail, detail)
            }
        }

        views.setTextViewTextSize(
            R.id.widget_today_count,
            android.util.TypedValue.COMPLEX_UNIT_SP,
            textScale.countSp,
        )
        views.setTextViewTextSize(
            R.id.widget_category,
            android.util.TypedValue.COMPLEX_UNIT_SP,
            textScale.categorySp,
        )
        views.setTextViewTextSize(
            R.id.widget_heading,
            android.util.TypedValue.COMPLEX_UNIT_SP,
            textScale.headingSp,
        )
        views.setTextViewTextSize(
            R.id.widget_detail,
            android.util.TypedValue.COMPLEX_UNIT_SP,
            textScale.detailSp,
        )
        views.setTextViewTextSize(
            R.id.widget_date,
            android.util.TypedValue.COMPLEX_UNIT_SP,
            textScale.dateSp,
        )
        views.setTextViewTextSize(
            R.id.widget_second_category,
            android.util.TypedValue.COMPLEX_UNIT_SP,
            maxOf(9f, textScale.categorySp - 1f),
        )
        views.setTextViewTextSize(
            R.id.widget_second_heading,
            android.util.TypedValue.COMPLEX_UNIT_SP,
            maxOf(13f, textScale.headingSp - 3f),
        )
        views.setTextViewTextSize(
            R.id.widget_second_detail,
            android.util.TypedValue.COMPLEX_UNIT_SP,
            maxOf(10f, textScale.detailSp - 3f),
        )
        views.setTextViewTextSize(
            R.id.widget_third_category,
            android.util.TypedValue.COMPLEX_UNIT_SP,
            9f,
        )
        views.setTextViewTextSize(
            R.id.widget_third_heading,
            android.util.TypedValue.COMPLEX_UNIT_SP,
            14f,
        )
        views.setTextViewTextSize(
            R.id.widget_third_detail,
            android.util.TypedValue.COMPLEX_UNIT_SP,
            10f,
        )
        views.setInt(R.id.widget_heading, "setMaxLines", textScale.headingMaxLines)
        views.setInt(R.id.widget_detail, "setMaxLines", textScale.detailMaxLines)
        views.setInt(R.id.widget_second_heading, "setMaxLines", 1)
        views.setInt(R.id.widget_second_detail, "setMaxLines", 1)
        views.setInt(R.id.widget_third_heading, "setMaxLines", 1)
        views.setInt(R.id.widget_third_detail, "setMaxLines", 1)
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launch != null) {
            val destination = when {
                contentFilter == ScheduleWidgetConfigureActivity.CONTENT_WORK -> "work"
                contentFilter in setOf(
                    ScheduleWidgetConfigureActivity.CONTENT_STUDY,
                    ScheduleWidgetConfigureActivity.CONTENT_CLASSES,
                    ScheduleWidgetConfigureActivity.CONTENT_DEADLINES,
                ) -> "study"
                widgetType == ScheduleWidgetConfigureActivity.TYPE_WEEK -> "week"
                else -> "today"
            }
            launch.putExtra(MainActivity.EXTRA_SCHEDULE_DESTINATION, destination)
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                PendingIntent.getActivity(
                    context,
                    widgetId,
                    launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
        }
        return views
    }

    private fun setTextColors(views: RemoteViews, primary: Int, secondary: Int) {
        views.setTextColor(R.id.widget_heading, primary)
        views.setTextColor(R.id.widget_date, secondary)
        views.setTextColor(R.id.widget_today_count, secondary)
        views.setTextColor(R.id.widget_detail, secondary)
        views.setTextColor(R.id.widget_second_heading, primary)
        views.setTextColor(R.id.widget_second_detail, secondary)
        views.setTextColor(R.id.widget_third_heading, primary)
        views.setTextColor(R.id.widget_third_detail, secondary)
        views.setTextColor(R.id.widget_today_more, secondary)
    }

    private fun parseWidgetEvent(event: JSONObject): ScheduleWidgetEvent? {
        val localDate = event.optString("localDate").let {
            runCatching { LocalDate.parse(it) }.getOrNull()
        } ?: return null
        val intervals = event.optJSONArray("intervals") ?: JSONArray()
        return ScheduleWidgetEvent(
            id = event.optString("id"),
            kind = event.optString("kind"),
            title = event.optString("title"),
            localDate = localDate,
            isDayOff = event.optBoolean("isDayOff"),
            intervals = (0 until intervals.length()).mapNotNull { index ->
                intervals.optJSONObject(index)?.let { interval ->
                    ScheduleWidgetInterval(
                        interval.optLong("startEpochMillis", Long.MIN_VALUE),
                        interval.optLong("endEpochMillis", Long.MIN_VALUE),
                    )
                }
            },
        )
    }

    private fun writeTodayEventLine(
        context: Context,
        views: RemoteViews,
        line: ScheduleWidgetEventLine,
        position: Int,
    ) {
        val (categoryId, headingId, detailId) = when (position) {
            0 -> Triple(R.id.widget_category, R.id.widget_heading, R.id.widget_detail)
            1 -> Triple(
                R.id.widget_second_category,
                R.id.widget_second_heading,
                R.id.widget_second_detail,
            )
            2 -> Triple(
                R.id.widget_third_category,
                R.id.widget_third_heading,
                R.id.widget_third_detail,
            )
            else -> return
        }
        val (category, color) = when (line.event.kind) {
            "work" -> context.getString(R.string.schedule_widget_work) to Color.rgb(147, 197, 253)
            "classSession" -> context.getString(R.string.schedule_widget_study) to Color.rgb(196, 181, 253)
            "personal" -> context.getString(R.string.schedule_widget_personal) to Color.rgb(203, 213, 225)
            "deadline" -> context.getString(R.string.schedule_widget_deadline) to Color.rgb(251, 191, 36)
            else -> context.getString(R.string.schedule_widget_event) to Color.WHITE
        }
        views.setTextViewText(categoryId, category)
        views.setTextColor(categoryId, color)
        views.setViewVisibility(categoryId, View.VISIBLE)
        views.setTextViewText(
            headingId,
            line.event.title.ifBlank { context.getString(R.string.schedule_widget_event) },
        )
        views.setViewVisibility(headingId, View.VISIBLE)
        val detail = if (line.startMillis == null || line.endMillis == null) {
            context.getString(R.string.schedule_widget_all_day)
        } else if (line.ongoing) {
            context.getString(
                R.string.schedule_widget_in_progress,
                Instant.ofEpochMilli(line.endMillis).atZone(ZoneId.systemDefault()).format(timeFormatter),
            )
        } else {
            val start = Instant.ofEpochMilli(line.startMillis).atZone(ZoneId.systemDefault())
            val end = Instant.ofEpochMilli(line.endMillis).atZone(ZoneId.systemDefault())
            if (start.toLocalDate() == end.toLocalDate()) {
                "${start.format(timeFormatter)} – ${end.format(timeFormatter)}"
            } else {
                "${start.format(timeFormatter)} – ${end.format(dateFormatter)} ${end.format(timeFormatter)}"
            }
        }
        views.setTextViewText(detailId, detail)
        views.setViewVisibility(detailId, View.VISIBLE)
    }
}
