package app.shiftstudy.mobile

/** Returns the earliest future start or end across projected timed events. */
internal fun nextWidgetRefreshAt(
    intervals: Iterable<Pair<Long, Long>>,
    nowMillis: Long,
    refreshCountdown: Boolean = false,
): Long? {
    val futureEdges = intervals
    .flatMap { (start, end) -> listOf(start, end) }
    .filter { it > nowMillis }
    val boundary = futureEdges.minOrNull() ?: return null
    if (!refreshCountdown) return boundary

    val nextMinute = ((nowMillis / 60_000L) + 1) * 60_000L
    return minOf(boundary, nextMinute)
}
