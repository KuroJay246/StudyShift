package app.shiftstudy.mobile

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.json.JSONObject

internal object ScheduleWidgetRefreshScheduler {
    const val ACTION_BOUNDARY = "app.shiftstudy.action.WIDGET_BOUNDARY"
    private const val REQUEST_CODE = 7842

    fun reschedule(context: Context) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val operation = pendingIntent(context)
        val widgetManager = android.appwidget.AppWidgetManager.getInstance(context)
        val hasWidgets = ScheduleWidgetProvider.widgetProviders.any { provider ->
            widgetManager.getAppWidgetIds(android.content.ComponentName(context, provider)).isNotEmpty()
        }
        if (!hasWidgets) {
            manager.cancel(operation)
            return
        }
        val snapshot = context.getSharedPreferences("shift_study_widget", Context.MODE_PRIVATE)
            .getString("schedule_snapshot_v1", null)
        val widgetPreferences = context.getSharedPreferences(
            ScheduleWidgetConfigureActivity.PREFERENCES,
            Context.MODE_PRIVATE,
        )
        val nextEventProvider = android.content.ComponentName(context, ScheduleWidgetProvider::class.java)
        val hasCountdownWidget = widgetManager.getAppWidgetIds(nextEventProvider).any { widgetId ->
            val type = widgetPreferences.getInt(
                ScheduleWidgetConfigureActivity.typeKey(widgetId),
                ScheduleWidgetProvider.defaultType(nextEventProvider.className),
            )
            type == ScheduleWidgetConfigureActivity.TYPE_NEXT_EVENT
        }
        val boundary = snapshot
            ?.let(::projectedWidgetIntervals)
            ?.let {
                nextWidgetRefreshAt(
                    intervals = it,
                    nowMillis = System.currentTimeMillis(),
                    refreshCountdown = hasCountdownWidget,
                )
            }

        if (boundary == null) {
            manager.cancel(operation)
            return
        }

        // Request a minute-aligned refresh for visible countdown widgets.
        // Android can defer inexact alarms while idle; the provider's
        // 30-minute update remains the fallback on battery-restricted devices.
        manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, boundary, operation)
    }

    private fun pendingIntent(context: Context) = PendingIntent.getBroadcast(
        context,
        REQUEST_CODE,
        Intent(context, ScheduleWidgetRefreshReceiver::class.java).setAction(ACTION_BOUNDARY),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun projectedWidgetIntervals(snapshot: String): List<Pair<Long, Long>>? =
        runCatching {
            val root = JSONObject(snapshot)
            if (!isSupportedWidgetSnapshotSchema(root.optInt("schemaVersion"))) return null
            val intervals = mutableListOf<Pair<Long, Long>>()
            fun collect(event: JSONObject) {
                val values = event.optJSONArray("intervals") ?: return
                for (index in 0 until values.length()) {
                    val interval = values.optJSONObject(index) ?: continue
                    val start = interval.optLong("startEpochMillis", Long.MIN_VALUE)
                    val end = interval.optLong("endEpochMillis", Long.MIN_VALUE)
                    if (start != Long.MIN_VALUE && end != Long.MIN_VALUE && end > start) {
                        intervals += start to end
                    }
                }
            }
            val upcoming = root.optJSONArray("upcoming")
            if (upcoming != null) {
                for (index in 0 until upcoming.length()) {
                    upcoming.optJSONObject(index)?.let(::collect)
                }
            }
            val nextByFilter = root.optJSONObject("nextByFilter")
            nextByFilter?.keys()?.forEach { key ->
                nextByFilter.optJSONObject(key)?.let(::collect)
            }
            intervals
        }.getOrNull()

    fun refreshAndReschedule(context: Context) {
        ScheduleWidgetProvider.updateAll(context)
        reschedule(context)
    }

    fun cancel(context: Context) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        manager.cancel(pendingIntent(context))
    }
}

class ScheduleWidgetRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ScheduleWidgetRefreshScheduler.ACTION_BOUNDARY,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_CONFIGURATION_CHANGED,
            -> ScheduleWidgetRefreshScheduler.refreshAndReschedule(context)
        }
    }
}
