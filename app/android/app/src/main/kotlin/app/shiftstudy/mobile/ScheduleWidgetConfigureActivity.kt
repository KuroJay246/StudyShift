package app.shiftstudy.mobile

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import org.json.JSONObject

/** StudyShift-owned configuration UI; the launcher still owns placement/resizing. */
class ScheduleWidgetConfigureActivity : Activity() {
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private var selectedType = TYPE_NEXT_EVENT
    private var fixedType: Int? = null
    private var selectedContent = CONTENT_ALL
    private var fixedContent: Int? = null
    private var selectedAppearance = APPEARANCE_SYSTEM
    private lateinit var palette: Palette
    private lateinit var previewHeading: TextView
    private lateinit var previewDetail: TextView
    private lateinit var previewCard: LinearLayout
    private lateinit var styleChoices: List<View>
    private lateinit var contentChoices: List<View>
    private lateinit var appearanceChoices: List<View>

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(Activity.RESULT_CANCELED)
        widgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        )
        if (intent.action != AppWidgetManager.ACTION_APPWIDGET_CONFIGURE ||
            widgetId == AppWidgetManager.INVALID_APPWIDGET_ID
        ) {
            finish()
            return
        }

        val manager = AppWidgetManager.getInstance(this)
        val providerInfo = manager.getAppWidgetInfo(widgetId)
        if (providerInfo == null || widgetId !in manager.getAppWidgetIds(providerInfo.provider)) {
            finish()
            return
        }

        val prefs = getSharedPreferences(PREFERENCES, MODE_PRIVATE)
        val hasSavedType = prefs.contains(typeKey(widgetId))
        fixedType = ScheduleWidgetProvider.fixedConfigurationType(
            providerInfo.provider.className,
            hasSavedType,
        )
        fixedContent = ScheduleWidgetProvider.fixedContent(providerInfo.provider.className)
        selectedType = fixedType ?: prefs.getInt(
            typeKey(widgetId), ScheduleWidgetProvider.defaultType(providerInfo.provider.className),
        ).coerceIn(TYPE_NEXT_EVENT..TYPE_WEEK)
        selectedContent = fixedContent ?: prefs.getInt(contentKey(widgetId), CONTENT_ALL)
            .coerceIn(CONTENT_ALL..CONTENT_DEADLINES)
        selectedAppearance = prefs.getInt(appearanceKey(widgetId), APPEARANCE_SYSTEM).coerceIn(APPEARANCE_SYSTEM..APPEARANCE_TRANSPARENT)
        palette = loadPalette()
        window.statusBarColor = palette.surface
        window.navigationBarColor = palette.surface
        window.decorView.systemUiVisibility = if (palette.dark) 0 else
            (View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(palette.surface)
            setOnApplyWindowInsetsListener { view, insets ->
                val left: Int
                val top: Int
                val right: Int
                val bottom: Int
                if (android.os.Build.VERSION.SDK_INT >= 30) {
                    val bars = insets.getInsets(WindowInsets.Type.systemBars())
                    left = bars.left
                    top = bars.top
                    right = bars.right
                    bottom = bars.bottom
                } else {
                    @Suppress("DEPRECATION")
                    run {
                        left = insets.systemWindowInsetLeft
                        top = insets.systemWindowInsetTop
                        right = insets.systemWindowInsetRight
                        bottom = insets.systemWindowInsetBottom
                    }
                }
                view.setPadding(left, top, right, bottom)
                insets
            }
        }
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(22), dp(20), dp(22), dp(20))
        }
        content.addView(buildHeader())
        content.addView(sectionTitle("Widget layout"), topMargin(dp(24)))
        styleChoices = buildStyleChoices().also { choices -> choices.forEach(content::addView) }
        fixedType?.let { type ->
            val title = widgetConfigurationTypeLabel(
                type,
                selectedContent,
                resources.getStringArray(R.array.schedule_widget_type_options)[type],
            )
            val layoutMessage = if (fixedContent != null) {
                widgetFixedFamilyLayoutMessage(selectedContent)
            } else {
                "$title is set for this launcher widget. Resize it on your Home screen."
            }
            content.addView(
                label(layoutMessage, 13f, palette.secondary),
                topMargin(dp(6)),
            )
        }
        contentChoices = buildChipChoices(resources.getStringArray(R.array.schedule_widget_content_options)) { selectedContent = it }
        if (fixedContent == null) {
            content.addView(sectionTitle("Show"), topMargin(dp(18)))
            content.addView(chipRow(contentChoices), topMargin(dp(10)))
        } else {
            contentChoices.forEach { it.visibility = View.GONE }
            val contentId = fixedContent!!
            content.addView(
                label(
                    if (contentId == CONTENT_CLASSES) "This widget always shows the next class."
                    else "This widget always shows the next deadline.",
                    13f,
                    palette.secondary,
                ),
                topMargin(dp(6)),
            )
        }
        content.addView(sectionTitle("Appearance"), topMargin(dp(20)))
        appearanceChoices = buildChipChoices(resources.getStringArray(R.array.schedule_widget_appearance_options)) { selectedAppearance = it }
        content.addView(chipRow(appearanceChoices), topMargin(dp(10)))
        content.addView(
            label("Each widget keeps its own choices. You can resize it on your home screen at any time.", 13f, palette.secondary),
            topMargin(dp(16)),
        )

        val scroll = ScrollView(this).apply {
            isFillViewport = true
            clipToPadding = false
            addView(content, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        }
        root.addView(scroll, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))
        root.addView(buildActions(), LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        setContentView(root)
        updateSelectionStyles()
        updatePreview()
    }

    private fun buildHeader(): View {
        val header = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }
        header.addView(label("StudyShift  ·  WIDGETS", 13f, palette.accent, Typeface.BOLD))
        header.addView(label("Make it yours", 27f, palette.text, Typeface.BOLD), topMargin(dp(8)))
        header.addView(
            label("Choose what your home-screen schedule shows.", 15f, palette.secondary),
            topMargin(dp(4)),
        )

        previewCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(16), dp(18), dp(16))
            background = roundedGradient(palette.featuredStart, palette.featuredEnd, dp(20))
        }
        previewCard.addView(label("LIVE PREVIEW", 11f, Color.WHITE, Typeface.BOLD))
        previewHeading = label("", 19f, Color.WHITE, Typeface.BOLD)
        previewDetail = label("", 14f, 0xFFE8EEFF.toInt())
        previewCard.addView(previewHeading, topMargin(dp(8)))
        previewCard.addView(previewDetail, topMargin(dp(3)))
        header.addView(previewCard, topMargin(dp(18)))
        return header
    }

    private fun buildStyleChoices(): List<View> {
        val labels = resources.getStringArray(R.array.schedule_widget_type_options).mapIndexed { index, fallback ->
            widgetConfigurationTypeLabel(index, selectedContent, fallback)
        }
        val explanations = arrayOf(
            "One clear look at the next event",
            "A quick summary of today's schedule",
            "A compact glance across the week",
        )
        return labels.mapIndexed { index, value ->
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(14), dp(10), dp(14), dp(10))
                isClickable = true
                isFocusable = true
                minimumHeight = dp(60)
                setOnClickListener {
                    selectedType = index
                    updateSelectionStyles()
                    updatePreview()
                }
            }
            val texts = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
            texts.addView(label(value, 15f, palette.text, Typeface.BOLD))
            texts.addView(label(explanations[index], 12f, palette.secondary), topMargin(dp(2)))
            row.addView(texts, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
            row.addView(selectionMark(index == selectedType))
            row.tag = "style:$index"
            row.contentDescription = "$value. ${explanations[index]}"
            row.setOnClickListener {
                selectedType = index
                updateSelectionStyles()
                updatePreview()
            }
            row
        }
    }

    private fun buildChipChoices(labels: Array<String>, onSelect: (Int) -> Unit): List<View> =
        labels.mapIndexed { index, value ->
            val chip = TextView(this).apply {
                text = value
                textSize = 13f
                typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
                gravity = Gravity.CENTER
                setPadding(dp(14), dp(9), dp(14), dp(9))
                minHeight = dp(48)
                isClickable = true
                isFocusable = true
                tag = "chip:$index"
                setOnClickListener {
                    onSelect(index)
                    updateSelectionStyles()
                    updatePreview()
                }
            }
            chip
        }

    private fun chipRow(chips: List<View>) = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        chips.chunked(2).forEach { choices ->
            val row = LinearLayout(this@ScheduleWidgetConfigureActivity).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
            }
            choices.forEachIndexed { index, chip ->
                row.addView(
                    chip,
                    LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
                        .apply { if (index > 0) leftMargin = dp(8) },
                )
            }
            if (choices.size == 1) {
                row.addView(View(this@ScheduleWidgetConfigureActivity), weightWrap())
            }
            addView(
                row,
                LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                ).apply { if (childCount > 0) topMargin = dp(8) },
            )
        }
    }

    private fun weightWrap() =
        LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)

    private fun buildActions(): View {
        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END or Gravity.CENTER_VERTICAL
            setPadding(dp(18), dp(10), dp(18), dp(14))
            setBackgroundColor(palette.surface)
        }
        val cancel = action("Cancel", primary = false).apply { setOnClickListener { finish() } }
        val save = action("Save widget", primary = true).apply {
            setOnClickListener {
                getSharedPreferences(PREFERENCES, MODE_PRIVATE).edit()
                    .putInt(typeKey(widgetId), selectedType)
                    .putInt(contentKey(widgetId), selectedContent)
                    .putInt(appearanceKey(widgetId), selectedAppearance)
                    .apply()
                ScheduleWidgetProvider.updateOne(this@ScheduleWidgetConfigureActivity, widgetId)
                setResult(Activity.RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
                finish()
            }
        }
        actions.addView(cancel, LinearLayout.LayoutParams(0, dp(48), 1f).apply { rightMargin = dp(10) })
        actions.addView(save, LinearLayout.LayoutParams(0, dp(48), 1f))
        return actions
    }

    private fun action(text: String, primary: Boolean) = TextView(this).apply {
        this.text = text
        textSize = 15f
        gravity = Gravity.CENTER
        typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        setTextColor(if (primary) Color.WHITE else palette.accent)
        background = rounded(
            if (primary) palette.accent else palette.surfaceAlt,
            dp(16),
            if (primary) palette.accent else palette.border,
        )
        isClickable = true
        isFocusable = true
    }

    private fun updateSelectionStyles() {
        styleChoices.forEachIndexed { index, view ->
            val selected = index == selectedType
            view.visibility = if (fixedType != null && !selected) View.GONE else View.VISIBLE
            view.isSelected = selected
            view.background = rounded(
                if (selected) palette.accentContainer else palette.surfaceAlt,
                dp(16),
                if (selected) palette.accent else palette.border,
            )
            val fallback = resources.getStringArray(R.array.schedule_widget_type_options)[index]
            val label = widgetConfigurationTypeLabel(index, selectedContent, fallback)
            view.contentDescription = "$label" +
                if (selected) ", selected" else ""
            // The row is reusable, so keep its visible and accessible selection
            // indicator synchronized with the highlighted row and live preview.
            val mark = (view as? ViewGroup)?.getChildAt(1) as? TextView
            mark?.let { updateSelectionMark(it, selected) }
        }
        contentChoices.forEachIndexed { index, view ->
            styleChip(view as TextView, index == selectedContent)
            if (fixedContent != null) view.visibility = View.GONE
        }
        appearanceChoices.forEachIndexed { index, view -> styleChip(view as TextView, index == selectedAppearance) }
    }

    private fun styleChip(view: TextView, selected: Boolean) {
        view.isSelected = selected
        view.setTextColor(if (selected) palette.onAccent else palette.text)
        view.background = rounded(
            if (selected) palette.accent else palette.surfaceAlt,
            dp(24),
            if (selected) palette.accent else palette.border,
        )
        view.contentDescription = "${view.text}" + if (selected) ", selected" else ""
    }

    private fun updatePreview() {
        val snapshot = getSharedPreferences("shift_study_widget", MODE_PRIVATE)
            .getString("schedule_snapshot_v1", null)
            ?.let { runCatching { JSONObject(it) }.getOrNull() }
        val events = when (selectedType) {
            TYPE_TODAY -> snapshot?.optJSONArray("today")
            else -> snapshot?.optJSONArray("upcoming")
        }
        val fromProjection = if (selectedType == TYPE_NEXT_EVENT) {
            if (selectedContent == CONTENT_ALL) snapshot?.optJSONObject("next")
            else snapshot?.optJSONObject("nextByFilter")?.optJSONObject(nextProjectionKey(selectedContent))
        } else null
        val event = fromProjection ?: events?.let { items ->
                (0 until items.length()).asSequence()
                    .mapNotNull(items::optJSONObject)
                    .firstOrNull { candidate ->
                        !candidate.optBoolean("isDayOff") &&
                            matchesWidgetContentFilter(selectedContent, candidate.optString("kind"))
                    }
            }
        val title = event?.optString("title")?.takeIf { it.isNotBlank() }
        val heading = when (selectedType) {
            TYPE_TODAY -> todayWidgetEventCountLabel(snapshot?.optJSONArray("today")?.length() ?: 0)
            TYPE_WEEK -> "This week · Monday to Sunday"
            else -> "Next event"
        }
        val appearance = when (selectedAppearance) {
            APPEARANCE_LIGHT -> false
            APPEARANCE_DARK -> true
            else -> palette.dark
        }
        val useGlass = selectedAppearance == APPEARANCE_GLASS
        previewCard.background = when {
            useGlass -> roundedGradient(palette.featuredStart, palette.featuredEnd, dp(20))
            selectedAppearance == APPEARANCE_TRANSPARENT ->
                rounded(Color.TRANSPARENT, dp(20), palette.border)
            else -> rounded(
                if (appearance) 0xFF151A24.toInt() else Color.WHITE,
                dp(20),
                if (appearance) 0xFF334155.toInt() else palette.border,
            )
        }
        val foreground = if (useGlass || appearance) Color.WHITE else palette.text
        previewHeading.setTextColor(foreground)
        previewDetail.setTextColor(
            when {
                useGlass -> 0xFFE8EEFF.toInt()
                appearance -> 0xFFB8C6DE.toInt()
                else -> palette.secondary
            },
        )
        previewHeading.text = when {
            title != null -> title
            selectedContent == CONTENT_WORK -> "No upcoming work shifts"
            selectedContent == CONTENT_STUDY -> "No upcoming classes or deadlines"
            selectedContent == CONTENT_CLASSES -> "No upcoming classes"
            selectedContent == CONTENT_DEADLINES -> "No upcoming deadlines"
            else -> "Nothing scheduled yet"
        }
        previewDetail.text = when {
            selectedType == TYPE_TODAY -> todayWidgetEventCountLabel(snapshot?.optJSONArray("today")?.length() ?: 0)
            selectedType == TYPE_WEEK -> "This week · Monday to Sunday"
            selectedContent == CONTENT_CLASSES || selectedContent == CONTENT_DEADLINES ->
                widgetFixedFamilyPreviewDetail(selectedContent, hasEvent = title != null)
            title != null -> "Your next schedule event"
            else -> heading
        }
    }

    private fun sectionTitle(text: String) = label(text, 17f, palette.text, Typeface.BOLD)

    private fun label(text: String, size: Float, color: Int, weight: Int = Typeface.NORMAL) =
        TextView(this).apply {
            this.text = text
            textSize = size
            setTextColor(color)
            typeface = Typeface.create("sans-serif", weight)
            setLineSpacing(dp(2).toFloat(), 1f)
        }

    private fun selectionMark(selected: Boolean) = TextView(this).apply {
        textSize = 16f
        gravity = Gravity.CENTER
        setTextColor(Color.WHITE)
        layoutParams = LinearLayout.LayoutParams(dp(26), dp(26))
        updateSelectionMark(this, selected)
    }

    private fun updateSelectionMark(mark: TextView, selected: Boolean) {
        mark.text = if (selected) "✓" else ""
        mark.background = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(if (selected) palette.accent else Color.TRANSPARENT)
            setStroke(dp(1), if (selected) palette.accent else palette.border)
        }
        mark.contentDescription = if (selected) "Selected" else "Not selected"
        mark.isSelected = selected
    }

    private fun loadPalette(): Palette {
        val appearance = getSharedPreferences("startup_appearance", MODE_PRIVATE)
        val explicitTheme = appearance.getString("theme", null)
        val systemDark = resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK ==
            Configuration.UI_MODE_NIGHT_YES
        val dark = when (explicitTheme) {
            "dark" -> true
            "light" -> false
            else -> systemDark
        }
        val accentTheme = appearance.getString("accentTheme", "studyShiftBlue")
        val colors = when (accentTheme) {
            "teal" -> intArrayOf(0xFF063B37.toInt(), 0xFF00796B.toInt(), 0xFF30D6C2.toInt())
            "violet" -> intArrayOf(0xFF251052.toInt(), 0xFF6D28D9.toInt(), 0xFFB69CFF.toInt())
            "amber" -> intArrayOf(0xFF472900.toInt(), 0xFF9A5B00.toInt(), 0xFFFFC45C.toInt())
            "red" -> intArrayOf(0xFF54121D.toInt(), 0xFFE11D2E.toInt(), 0xFFFF5364.toInt())
            else -> intArrayOf(0xFF0B1F5B.toInt(), 0xFF0D47E1.toInt(), 0xFF1FB6FF.toInt())
        }
        return if (dark) Palette(
            dark = true,
            surface = Color.BLACK,
            surfaceAlt = 0xFF151515.toInt(),
            border = 0xFF353535.toInt(),
            text = 0xFFF5F5F5.toInt(),
            secondary = 0xFFB3B3B3.toInt(),
            accentContainer = blend(0xFF151A24.toInt(), colors[2], .20f),
            onAccent = Color.WHITE,
            accent = colors[2],
            featuredStart = colors[0],
            featuredEnd = colors[1],
        ) else Palette(
            dark = false,
            surface = 0xFFF7F9FE.toInt(),
            surfaceAlt = Color.WHITE,
            border = 0xFFDCE5F3.toInt(),
            text = 0xFF0F172A.toInt(),
            secondary = 0xFF475569.toInt(),
            accentContainer = blend(Color.WHITE, colors[1], .09f),
            onAccent = Color.WHITE,
            accent = colors[1],
            featuredStart = colors[0],
            featuredEnd = colors[1],
        )
    }

    private fun rounded(color: Int, radius: Int, stroke: Int? = null) = GradientDrawable().apply {
        shape = GradientDrawable.RECTANGLE
        setColor(color)
        cornerRadius = radius.toFloat()
        stroke?.let { setStroke(dp(1), it) }
    }

    private fun roundedGradient(start: Int, end: Int, radius: Int) = GradientDrawable(
        GradientDrawable.Orientation.TL_BR,
        intArrayOf(start, end),
    ).apply {
        shape = GradientDrawable.RECTANGLE
        cornerRadius = radius.toFloat()
    }

    private fun blend(base: Int, tint: Int, amount: Float): Int {
        fun channel(shift: Int): Int {
            val a = base ushr shift and 0xFF
            val b = tint ushr shift and 0xFF
            return (a + (b - a) * amount).toInt().coerceIn(0, 255)
        }
        return (channel(24) shl 24) or (channel(16) shl 16) or
            (channel(8) shl 8) or channel(0)
    }

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
    private fun wrap() = LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT)
    private fun topMargin(value: Int) = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = value }

    private data class Palette(
        val dark: Boolean,
        val surface: Int,
        val surfaceAlt: Int,
        val border: Int,
        val text: Int,
        val secondary: Int,
        val accentContainer: Int,
        val onAccent: Int,
        val accent: Int,
        val featuredStart: Int,
        val featuredEnd: Int,
    )

    companion object {
        const val PREFERENCES = "shift_study_widget_instances"
        const val CONTENT_ALL = 0
        const val CONTENT_WORK = 1
        const val CONTENT_STUDY = 2
        const val CONTENT_CLASSES = 3
        const val CONTENT_DEADLINES = 4
        const val APPEARANCE_SYSTEM = 0
        const val APPEARANCE_LIGHT = 1
        const val APPEARANCE_DARK = 2
        const val APPEARANCE_GLASS = 3
        const val APPEARANCE_TRANSPARENT = 4
        const val TYPE_NEXT_EVENT = 0
        const val TYPE_TODAY = 1
        const val TYPE_WEEK = 2
        const val TYPE_LAST = TYPE_WEEK

        fun typeKey(widgetId: Int) = "type_$widgetId"
        fun contentKey(widgetId: Int) = "content_$widgetId"
        fun appearanceKey(widgetId: Int) = "appearance_$widgetId"
    }
}
