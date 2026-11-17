package app.shiftstudy.mobile

/** Copy for the dedicated family widgets whose compact layout cannot be changed. */
internal fun widgetFixedFamilyLayoutMessage(content: Int): String = when (content) {
    ScheduleWidgetConfigureActivity.CONTENT_CLASSES ->
        "Next class layout is fixed for this widget. Resize it on your Home screen."
    ScheduleWidgetConfigureActivity.CONTENT_DEADLINES ->
        "Upcoming deadline layout is fixed for this widget. Resize it on your Home screen."
    else -> "Next event layout is fixed for this widget. Resize it on your Home screen."
}

/** The family name stays accurate even though class/deadline cards share the next-event layout. */
internal fun widgetConfigurationTypeLabel(type: Int, content: Int, fallback: String): String =
    if (type == ScheduleWidgetConfigureActivity.TYPE_NEXT_EVENT) {
        when (content) {
            ScheduleWidgetConfigureActivity.CONTENT_CLASSES -> "Next class · 2 × 2"
            ScheduleWidgetConfigureActivity.CONTENT_DEADLINES -> "Upcoming deadline · 2 × 2"
            else -> fallback
        }
    } else fallback

/** Concise detail copy for the setup preview, including its empty state. */
internal fun widgetFixedFamilyPreviewDetail(content: Int, hasEvent: Boolean): String = when (content) {
    ScheduleWidgetConfigureActivity.CONTENT_CLASSES ->
        if (hasEvent) "Next class" else "Add a class to see the next one here."
    ScheduleWidgetConfigureActivity.CONTENT_DEADLINES ->
        if (hasEvent) "Upcoming deadline" else "Add a deadline to see it here."
    else -> if (hasEvent) "Your next schedule event" else "Nothing scheduled yet"
}
