package app.shiftstudy.mobile

import android.Manifest
import android.appwidget.AppWidgetManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.Bundle
import android.os.IBinder
import android.os.Message
import android.os.Messenger
import android.provider.CalendarContract
import android.provider.AlarmClock
import android.provider.OpenableColumns
import android.provider.Settings
import android.os.Build
import java.io.IOException
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.time.ZoneId
import java.time.Instant

class MainActivity : FlutterActivity() {
    private var backupResult: MethodChannel.Result? = null
    private var backupBytes: ByteArray? = null
    private var applyLauncherIconAfterLeaving = false
    private var pendingLocationResult: MethodChannel.Result? = null
    private val locationRequestCode = 7210
    private val locationHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        applySplashScreenTheme()
        super.onCreate(savedInstanceState)
        publishWidgetPickerPreview()
    }

    private fun publishWidgetPickerPreview() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM) return

        val preferences = getSharedPreferences("studyshift_widget_preview", MODE_PRIVATE)
        if (preferences.getInt("published_version", 0) >= WidgetPickerPreviewCatalog.version) return

        val manager = AppWidgetManager.getInstance(this)
        val previews = WidgetPickerPreviewCatalog.entries()
        val publishedResults = previews.map { preview ->
            runCatching {
                manager.setWidgetPreview(
                    ComponentName(this, preview.providerClass),
                    android.appwidget.AppWidgetProviderInfo.WIDGET_CATEGORY_HOME_SCREEN,
                    android.widget.RemoteViews(packageName, preview.layoutResource),
                )
            }.getOrDefault(false)
        }
        if (publishedResults.all { it }) {
            preferences.edit().putInt("published_version", WidgetPickerPreviewCatalog.version).apply()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.shiftstudy/app_version")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAppVersion" -> {
                        val packageInfo = packageManager.getPackageInfo(packageName, 0)
                        result.success(
                            mapOf(
                                "name" to packageInfo.versionName.orEmpty(),
                                "code" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                    packageInfo.longVersionCode
                                } else {
                                    @Suppress("DEPRECATION")
                                    packageInfo.versionCode.toLong()
                                },
                            ),
                        )
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.shiftstudy/time_zone")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "localIanaTimeZone" -> result.success(ZoneId.systemDefault().id)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.shiftstudy/launcher_icon")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "loadStartupAppearance" -> {
                        val preferences = getSharedPreferences("startup_appearance", MODE_PRIVATE)
                        result.success(
                            mapOf(
                                "theme" to preferences.getString("theme", null),
                                "accentTheme" to preferences.getString("accentTheme", null),
                            ),
                        )
                    }
                    "syncStartupAppearance" -> {
                        val preferences = getSharedPreferences("startup_appearance", MODE_PRIVATE)
                        preferences.edit().apply {
                            call.argument<String>("theme")?.let { putString("theme", it) }
                                ?: remove("theme")
                            call.argument<String>("accentTheme")?.let { putString("accentTheme", it) }
                                ?: remove("accentTheme")
                        }.apply()
                        applySplashScreenTheme()
                        applyLauncherIconAfterLeaving = true
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.shiftstudy/settings")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openNotificationSettings" -> {
                        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        }
                        try {
                            startActivity(intent)
                            result.success(true)
                        } catch (_: ActivityNotFoundException) {
                            result.success(false)
                        }
                    }
                    "openExactAlarmSettings" -> {
                        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        try {
                            startActivity(intent)
                            result.success(true)
                        } catch (_: ActivityNotFoundException) {
                            result.success(false)
                        }
                    }
                    "wasNotificationPermissionRequested" -> {
                        result.success(
                            getSharedPreferences("studyshift_permissions", MODE_PRIVATE)
                                .getBoolean("notification_permission_requested", false)
                        )
                    }
                    "recordNotificationPermissionRequest" -> {
                        getSharedPreferences("studyshift_permissions", MODE_PRIVATE)
                            .edit()
                            .putBoolean("notification_permission_requested", true)
                            .apply()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.shiftstudy/location")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getApproximateLocation" -> requestApproximateLocation(result)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.shiftstudy/widget_snapshot")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveSnapshot" -> {
                        val snapshot = call.arguments as? String
                        if (snapshot == null || snapshot.length > 64_000) {
                            result.error("invalid_snapshot", "Snapshot is missing or too large.", null)
                        } else {
                            val saved = getSharedPreferences("shift_study_widget", MODE_PRIVATE)
                                .edit()
                                .putString("schedule_snapshot_v1", snapshot)
                                .commit()
                            if (saved) {
                                ScheduleWidgetProvider.updateAll(this)
                                ScheduleWidgetRefreshScheduler.reschedule(this)
                                result.success(true)
                            }
                            else result.error("snapshot_write_failed", "Could not persist widget data.", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.shiftstudy/widget")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "instanceCount" -> {
                        val manager = AppWidgetManager.getInstance(this)
                        result.success(ScheduleWidgetProvider.widgetProviders.sumOf { provider ->
                            manager.getAppWidgetIds(ComponentName(this, provider)).size
                        })
                    }
                    "requestPin" -> {
                        val providerName = try {
                            WidgetPinProvider.className(call.argument<String>("family").orEmpty())
                        } catch (_: IllegalArgumentException) {
                            result.error("invalid_widget_family", "Choose a supported StudyShift widget layout.", null)
                            return@setMethodCallHandler
                        }
                        val provider = Class.forName(providerName)
                            .asSubclass(ScheduleWidgetProvider::class.java)
                        val manager = AppWidgetManager.getInstance(this)
                        val requested = manager.isRequestPinAppWidgetSupported &&
                            manager.requestPinAppWidget(ComponentName(this, provider), null, null)
                        result.success(requested)
                    }
                    "initialDestination" -> {
                        result.success(intent.getStringExtra(EXTRA_SCHEDULE_DESTINATION))
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.shiftstudy/backup")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveBackup" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes == null || bytes.isEmpty() || bytes.size > MAX_BACKUP_BYTES) {
                            result.error("invalid_backup", "Backup file is empty or too large.", null)
                        } else {
                            openBackupPicker(
                                result = result,
                                requestCode = SAVE_BACKUP_REQUEST,
                                bytes = bytes,
                                fileName = call.argument<String>("fileName") ?: "shift-study.ssbackup",
                            )
                        }
                    }
                    "openBackup" -> openBackupPicker(
                        result = result,
                        requestCode = OPEN_BACKUP_REQUEST,
                    )
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.shiftstudy/import")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openCalendar" -> openDocumentPicker(
                        result = result,
                        requestCode = OPEN_CALENDAR_REQUEST,
                        mimeType = "*/*",
                        mimeTypes = arrayOf(
                            "text/calendar",
                            "text/csv",
                            "text/comma-separated-values",
                            "application/csv",
                            "application/vnd.ms-excel",
                            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                            "text/plain",
                            "application/octet-stream",
                        ),
                    )
                    "openOcrImport" -> openDocumentPicker(
                        result = result,
                        requestCode = if (call.argument<Boolean>("rosterTable") == true) {
                            OPEN_ROSTER_TABLE_REQUEST
                        } else {
                            OPEN_OCR_IMPORT_REQUEST
                        },
                        mimeType = "*/*",
                        mimeTypes = arrayOf("application/pdf", "image/*"),
                    )
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.shiftstudy/export")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveCalendar" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes == null || bytes.isEmpty() || bytes.size > MAX_CALENDAR_BYTES) {
                            result.error("invalid_calendar", "Calendar file is empty or too large.", null)
                        } else {
                            openDocumentPicker(
                                result = result,
                                requestCode = SAVE_CALENDAR_REQUEST,
                                mimeType = "text/calendar",
                                bytes = bytes,
                                fileName = call.argument<String>("fileName") ?: "shift-study.ics",
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.shiftstudy/device_calendar")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openEventDraft" -> {
                        val title = call.argument<String>("title")?.trim()
                        val startMillis = call.argument<Number>("startMillis")?.toLong()
                        val endMillis = call.argument<Number>("endMillis")?.toLong()
                        val allDay = call.argument<Boolean>("allDay") ?: false
                        if (title.isNullOrEmpty() || title.length > 512 ||
                            startMillis == null || endMillis == null || endMillis <= startMillis
                        ) {
                            result.error(
                                "invalid_calendar_event",
                                "Calendar draft details are incomplete or invalid.",
                                null,
                            )
                        } else {
                            val intent = Intent(Intent.ACTION_INSERT).apply {
                                data = CalendarContract.Events.CONTENT_URI
                                putExtra(CalendarContract.Events.TITLE, title)
                                putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, startMillis)
                                putExtra(CalendarContract.EXTRA_EVENT_END_TIME, endMillis)
                                putExtra(CalendarContract.EXTRA_EVENT_ALL_DAY, allDay)
                                call.argument<String>("location")?.trim()?.takeIf(String::isNotEmpty)
                                    ?.let { putExtra(CalendarContract.Events.EVENT_LOCATION, it) }
                                call.argument<String>("description")?.trim()?.takeIf(String::isNotEmpty)
                                    ?.let { putExtra(CalendarContract.Events.DESCRIPTION, it) }
                            }
                            try {
                                startActivity(intent)
                                result.success(true)
                            } catch (_: ActivityNotFoundException) {
                                result.success(false)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.shiftstudy/clock_alarm")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openAlarm" -> {
                        val startMillis = call.argument<Number>("eventStartMillis")?.toLong()
                        val label = call.argument<String>("label")?.trim()
                        if (startMillis == null || label.isNullOrEmpty() || label.length > 512) {
                            result.error(
                                "invalid_alarm_draft",
                                "A clock alarm needs a valid time and label.",
                                null,
                            )
                        } else {
                            val localTime = Instant.ofEpochMilli(startMillis)
                                .atZone(ZoneId.systemDefault())
                            val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
                                putExtra(AlarmClock.EXTRA_HOUR, localTime.hour)
                                putExtra(AlarmClock.EXTRA_MINUTES, localTime.minute)
                                putExtra(AlarmClock.EXTRA_MESSAGE, label)
                            }
                            try {
                                // Keep the receiving Clock app's confirmation UI visible.
                                startActivity(intent)
                                result.success(true)
                            } catch (_: ActivityNotFoundException) {
                                result.success(false)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestApproximateLocation(result: MethodChannel.Result) {
        if (pendingLocationResult != null) {
            result.error("location_request_in_progress", "A location request is already running.", null)
            return
        }
        if (checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            pendingLocationResult = result
            requestPermissions(arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION), locationRequestCode)
            return
        }
        resolveApproximateLocation(result)
    }

    @Deprecated("Use the Android permission result APIs")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != locationRequestCode) return
        val result = pendingLocationResult ?: return
        pendingLocationResult = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            resolveApproximateLocation(result)
        } else {
            result.error("location_permission_denied", "Approximate location permission was denied.", null)
        }
    }

    @Suppress("MissingPermission")
    private fun resolveApproximateLocation(result: MethodChannel.Result) {
        val manager = getSystemService(LOCATION_SERVICE) as LocationManager
        val providers = buildList {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                add(LocationManager.FUSED_PROVIDER)
            }
            add(LocationManager.NETWORK_PROVIDER)
            add(LocationManager.GPS_PROVIDER)
            add(LocationManager.PASSIVE_PROVIDER)
        }
        val provider = providers.firstOrNull(manager::isProviderEnabled)
        if (provider == null) {
            result.error("location_unavailable", "Turn on device location or choose a place manually.", null)
            return
        }

        fun respond(location: Location?) {
            if (location == null) {
                result.error("location_unavailable", "A location fix is unavailable. Choose a place manually.", null)
            } else {
                result.success(
                    mapOf(
                        "latitude" to location.latitude,
                        "longitude" to location.longitude,
                        "capturedAt" to location.time,
                    ),
                )
            }
        }

        val recentLocation = runCatching { manager.getLastKnownLocation(provider) }
            .getOrNull()
            ?.takeIf {
                val age = System.currentTimeMillis() - it.time
                age in 0..(15 * 60 * 1000)
            }
        if (recentLocation != null) {
            respond(recentLocation)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            var completed = false
            val timeout = Runnable {
                if (!completed) {
                    completed = true
                    result.error(
                        "location_timeout",
                        "Could not get a location fix. Choose a place manually.",
                        null,
                    )
                }
            }
            locationHandler.postDelayed(timeout, 12_000)
            manager.getCurrentLocation(provider, null, mainExecutor) { location ->
                if (completed) return@getCurrentLocation
                completed = true
                locationHandler.removeCallbacks(timeout)
                respond(location)
            }
            return
        }

        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                locationHandler.removeCallbacksAndMessages(this)
                manager.removeUpdates(this)
                respond(location)
            }
        }
        manager.requestSingleUpdate(provider, listener, Looper.getMainLooper())
        locationHandler.postAtTime(
            {
                manager.removeUpdates(listener)
                val last = manager.getLastKnownLocation(provider)
                    ?.takeIf { System.currentTimeMillis() - it.time <= 15 * 60 * 1000 }
                respond(last)
            },
            listener,
            android.os.SystemClock.uptimeMillis() + 10_000,
        )
    }

    override fun onUserLeaveHint() {
        applyLauncherIconAfterLeaving = true
        super.onUserLeaveHint()
    }

    override fun onStop() {
        super.onStop()
        if (!applyLauncherIconAfterLeaving && !isFinishing) return
        applyLauncherIconAfterLeaving = false
        Handler(Looper.getMainLooper()).postDelayed({
            if (!hasWindowFocus()) {
                val requested = getSharedPreferences("startup_appearance", MODE_PRIVATE)
                    .getString("accentTheme", "studyShiftBlue") ?: "studyShiftBlue"
                val theme = getSharedPreferences("startup_appearance", MODE_PRIVATE)
                    .getString("theme", "system") ?: "system"
                if (activeLauncherAlias() != launcherAliasFor(requested, theme)) {
                    updateLauncherAlias(requested, theme)
                }
            }
        }, 350)
    }

    private fun launcherAliasFor(accentTheme: String, theme: String): String {
        val color = when (accentTheme) {
            "teal" -> "Teal"
            "violet" -> "Violet"
            "amber" -> "Amber"
            "red" -> "Red"
            else -> "Blue"
        }
        return when (theme) {
            "light" -> "Launcher${color}Light"
            "dark" -> "Launcher${color}Dark"
            else -> "Launcher$color"
        }
    }

    /** Keep Android's pre-Flutter splash in sync with the saved in-app appearance. */
    private fun applySplashScreenTheme() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return

        val preferences = getSharedPreferences("startup_appearance", MODE_PRIVATE)
        val color = when (preferences.getString("accentTheme", "studyShiftBlue")) {
            "teal" -> "Teal"
            "violet" -> "Violet"
            "amber" -> "Amber"
            "red" -> "Red"
            else -> "Blue"
        }
        val suffix = when (preferences.getString("theme", "system")) {
            "light" -> "Light"
            "dark" -> "Dark"
            else -> ""
        }
        val themeId = resources.getIdentifier(
            "LaunchTheme$color$suffix",
            "style",
            packageName,
        )
        if (themeId != 0) splashScreen.setSplashScreenTheme(themeId)
    }

    private val launcherAliases = listOf(
        "LauncherBlue", "LauncherTeal", "LauncherViolet", "LauncherAmber", "LauncherRed",
        "LauncherBlueLight", "LauncherTealLight", "LauncherVioletLight", "LauncherAmberLight", "LauncherRedLight",
        "LauncherBlueDark", "LauncherTealDark", "LauncherVioletDark", "LauncherAmberDark", "LauncherRedDark",
    )

    private fun activeLauncherAlias(): String? {
        return launcherAliases.firstOrNull { alias ->
            val component = ComponentName(
                this,
                launcherAliasClassName(MainActivity::class.java.name, alias),
            )
            val state = packageManager.getComponentEnabledSetting(component)
            state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED ||
                (alias == "LauncherBlue" && state == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT)
        }
    }

    private fun updateLauncherAlias(accentTheme: String, theme: String) {
        val selected = launcherAliasFor(accentTheme, theme)
        val settings = launcherAliases.map { alias ->
            ComponentName(
                this,
                launcherAliasClassName(MainActivity::class.java.name, alias),
            ) to
                if (alias == selected) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                else PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.setComponentEnabledSettings(
                settings.map { (component, state) ->
                    PackageManager.ComponentEnabledSetting(
                        component,
                        state,
                        PackageManager.DONT_KILL_APP,
                    )
                },
            )
        } else {
            settings.forEach { (component, state) ->
                packageManager.setComponentEnabledSetting(
                    component,
                    state,
                    PackageManager.DONT_KILL_APP,
                )
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun openBackupPicker(
        result: MethodChannel.Result,
        requestCode: Int,
        bytes: ByteArray? = null,
        fileName: String? = null,
    ) {
        openDocumentPicker(
            result,
            requestCode,
            if (requestCode == SAVE_BACKUP_REQUEST) "application/octet-stream" else "*/*",
            bytes = bytes,
            fileName = fileName,
        )
    }

    @Suppress("DEPRECATION")
    private fun openDocumentPicker(
        result: MethodChannel.Result,
        requestCode: Int,
        mimeType: String,
        mimeTypes: Array<String>? = null,
        bytes: ByteArray? = null,
        fileName: String? = null,
    ) {
        if (backupResult != null) {
            result.error("document_busy", "A document picker is already open.", null)
            return
        }
        backupResult = result
        backupBytes = bytes
        val intent = Intent(
            if (requestCode == SAVE_BACKUP_REQUEST || requestCode == SAVE_CALENDAR_REQUEST) Intent.ACTION_CREATE_DOCUMENT
            else Intent.ACTION_OPEN_DOCUMENT,
        ).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            if (mimeTypes != null) putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes)
            if (requestCode == SAVE_BACKUP_REQUEST || requestCode == SAVE_CALENDAR_REQUEST) {
                putExtra(
                    Intent.EXTRA_TITLE,
                    fileName ?: if (requestCode == SAVE_CALENDAR_REQUEST) "shift-study.ics" else "shift-study.ssbackup",
                )
            }
        }
        try {
            startActivityForResult(intent, requestCode)
        } catch (error: ActivityNotFoundException) {
            backupResult = null
            backupBytes = null
            result.error("backup_picker_unavailable", "Android could not open a document picker.", null)
        }
    }

    @Deprecated("The Storage Access Framework returns this user-selected document URI")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != SAVE_BACKUP_REQUEST &&
            requestCode != SAVE_CALENDAR_REQUEST &&
            requestCode != OPEN_BACKUP_REQUEST &&
            requestCode != OPEN_CALENDAR_REQUEST &&
            requestCode != OPEN_OCR_IMPORT_REQUEST &&
            requestCode != OPEN_ROSTER_TABLE_REQUEST) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val pending = backupResult
        backupResult = null
        val bytes = backupBytes
        backupBytes = null
        if (pending == null) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        if (resultCode != RESULT_OK) {
            pending.success(
                if (requestCode == SAVE_BACKUP_REQUEST || requestCode == SAVE_CALENDAR_REQUEST) false else null,
            )
            return
        }
        val uri: Uri? = data?.data
        if (uri == null) {
            pending.error("backup_uri_missing", "The selected backup file is unavailable.", null)
            return
        }
        try {
            if (requestCode == SAVE_BACKUP_REQUEST || requestCode == SAVE_CALENDAR_REQUEST) {
                val content = bytes ?: throw IOException("Backup data is unavailable.")
                contentResolver.openOutputStream(uri, "w")?.use { output ->
                    output.write(content)
                    output.flush()
                } ?: throw IOException("Could not write to the selected location.")
                pending.success(true)
            } else if (requestCode == OPEN_OCR_IMPORT_REQUEST || requestCode == OPEN_ROSTER_TABLE_REQUEST) {
                val name = documentName(uri)
                val extension = name.substringAfterLast('.', "").lowercase()
                if (extension !in setOf("pdf", "png", "jpg", "jpeg", "webp", "bmp")) {
                    pending.error("unsupported_ocr_file", "Choose a PDF or a PNG, JPG, WebP or BMP image.", null)
                    return
                }
                val descriptor = contentResolver.openFileDescriptor(uri, "r")
                    ?: throw IOException("Selected document unavailable.")
                descriptor.use {
                    if (it.statSize > MAX_OCR_FILE_BYTES) {
                        throw IOException("Selected document exceeds the 10 MB import limit.")
                    }
                }
                extractScheduleInOcrProcess(
                    uri,
                    name,
                    pending,
                    rosterTable = requestCode == OPEN_ROSTER_TABLE_REQUEST,
                )
            } else if (requestCode == OPEN_CALENDAR_REQUEST) {
                pending.success(
                    mapOf(
                        "name" to documentName(uri),
                        "bytes" to readDocument(uri, MAX_CALENDAR_BYTES),
                    ),
                )
            } else {
                pending.success(readDocument(uri, MAX_BACKUP_BYTES))
            }
        } catch (error: Exception) {
            pending.error("document_file_error", "Could not read or write the selected file.", null)
        }
    }

    private fun extractScheduleInOcrProcess(
        uri: Uri,
        name: String,
        pending: MethodChannel.Result,
        rosterTable: Boolean,
    ) {
        var connection: ServiceConnection? = null
        var finished = false
        fun finish(block: () -> Unit) {
            if (finished) return
            finished = true
            connection?.let { runCatching { unbindService(it) } }
            block()
        }

        val client = Messenger(
            Handler(Looper.getMainLooper()) { response ->
                if (response.what != ScheduleOcrService.MESSAGE_RESULT) return@Handler true
                val text = response.data.getString(ScheduleOcrService.KEY_TEXT)
                val tokens = response.data.getString(ScheduleOcrService.KEY_TOKENS)
                val error = response.data.getString(ScheduleOcrService.KEY_ERROR)
                finish {
                    if (text != null) {
                        pending.success(mapOf("name" to name, "text" to text, "tokens" to tokens))
                    } else {
                        pending.error(
                            "ocr_failed",
                            error ?: "Text could not be read from this file. Try a clearer image or a smaller PDF.",
                            null,
                        )
                    }
                }
                true
            },
        )

        val serviceConnection = object : ServiceConnection {
            override fun onServiceConnected(component: ComponentName, binder: IBinder) {
                try {
                    Messenger(binder).send(
                        Message.obtain(null, ScheduleOcrService.MESSAGE_EXTRACT).apply {
                            data = Bundle().apply {
                                putString(ScheduleOcrService.KEY_URI, uri.toString())
                                putString(ScheduleOcrService.KEY_NAME, name)
                                putBoolean(ScheduleOcrService.KEY_ROSTER_TABLE, rosterTable)
                            }
                            replyTo = client
                        },
                    )
                } catch (_: Exception) {
                    finish {
                        pending.error(
                            "ocr_unavailable",
                            "The document reader stopped before it could finish.",
                            null,
                        )
                    }
                }
            }

            override fun onServiceDisconnected(component: ComponentName) {
                finish {
                    pending.error(
                        "ocr_unavailable",
                        "The document reader stopped before it could finish.",
                        null,
                    )
                }
            }
        }
        connection = serviceConnection

        val serviceIntent = Intent(this, ScheduleOcrService::class.java).apply {
            data = uri
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        try {
            if (!bindService(serviceIntent, serviceConnection, BIND_AUTO_CREATE)) {
                finish {
                    pending.error(
                        "ocr_unavailable",
                        "The document reader could not be started.",
                        null,
                    )
                }
            }
        } catch (_: Exception) {
            finish {
                pending.error(
                    "ocr_unavailable",
                    "The document reader could not be started.",
                    null,
                )
            }
        }
    }

    private fun documentName(uri: Uri): String {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (column >= 0) return cursor.getString(column) ?: "calendar.ics"
                }
            }
        return "calendar.ics"
    }

    private fun readDocument(uri: Uri, maxBytes: Int): ByteArray {
        val input = contentResolver.openInputStream(uri)
            ?: throw IOException("Could not open the selected backup.")
        return DocumentStreamReader.readLimited(input, maxBytes)
    }

    companion object {
        const val EXTRA_SCHEDULE_DESTINATION = "app.shiftstudy.schedule_destination"
        private const val SAVE_BACKUP_REQUEST = 5311
        private const val OPEN_BACKUP_REQUEST = 5312
        private const val OPEN_CALENDAR_REQUEST = 5313
        private const val SAVE_CALENDAR_REQUEST = 5314
        private const val OPEN_OCR_IMPORT_REQUEST = 5315
        private const val OPEN_ROSTER_TABLE_REQUEST = 5316
        private const val MAX_BACKUP_BYTES = 10 * 1024 * 1024
        private const val MAX_CALENDAR_BYTES = 5 * 1024 * 1024
        private const val MAX_OCR_FILE_BYTES = 10 * 1024 * 1024
    }
}
