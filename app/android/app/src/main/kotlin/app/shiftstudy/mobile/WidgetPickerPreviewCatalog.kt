package app.shiftstudy.mobile

import android.appwidget.AppWidgetProvider

internal data class WidgetPickerPreviewSpec(
    val providerClass: Class<out AppWidgetProvider>,
    val layoutResource: Int,
)

internal object WidgetPickerPreviewCatalog {
    // Version 3 installations published only Next Event, Today, and Week.
    const val version = 4

    fun entries(): List<WidgetPickerPreviewSpec> = listOf(
        WidgetPickerPreviewSpec(ScheduleWidgetProvider::class.java, R.layout.schedule_widget_preview),
        WidgetPickerPreviewSpec(TodayWidgetProvider::class.java, R.layout.today_widget_preview),
        WidgetPickerPreviewSpec(WeekWidgetProvider::class.java, R.layout.week_widget_preview),
        WidgetPickerPreviewSpec(NextClassWidgetProvider::class.java, R.layout.next_class_widget_preview),
        WidgetPickerPreviewSpec(DeadlineWidgetProvider::class.java, R.layout.deadline_widget_preview),
    )
}
