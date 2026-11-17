package app.shiftstudy.mobile

internal object WidgetPinProvider {
    fun className(family: String): String = when (family) {
        "nextEvent" -> "app.shiftstudy.mobile.ScheduleWidgetProvider"
        "today" -> "app.shiftstudy.mobile.TodayWidgetProvider"
        "week" -> "app.shiftstudy.mobile.WeekWidgetProvider"
        "nextClass" -> "app.shiftstudy.mobile.NextClassWidgetProvider"
        "upcomingDeadline" -> "app.shiftstudy.mobile.DeadlineWidgetProvider"
        else -> throw IllegalArgumentException("Unknown widget family")
    }
}
