param([string]$ManifestPath)

$ErrorActionPreference = 'Stop'
$androidNamespace = 'http://schemas.android.com/apk/res/android'
$expectedApplicationId = 'app.shiftstudy.mobile'

if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $appRoot = Split-Path -Parent $PSScriptRoot
    $ManifestPath = Join-Path $appRoot 'build\app\intermediates\merged_manifest\personalRelease\processPersonalReleaseMainManifest\AndroidManifest.xml'
}
if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Merged release manifest not found. Run :app:processPersonalReleaseMainManifest first: $ManifestPath"
}

[xml]$manifest = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $ManifestPath).Path)
$root = $manifest.DocumentElement
$application = $manifest.SelectSingleNode('/manifest/application')
if ($root.GetAttribute('package') -cne $expectedApplicationId) {
    throw "Expected personal applicationId '$expectedApplicationId'; got '$($root.GetAttribute('package'))'."
}

function Get-AndroidAttribute($Node, [string]$Name) {
    return $Node.GetAttribute($Name, $androidNamespace)
}

function Assert-ExactSet([string]$Label, [string[]]$Expected, [string[]]$Actual) {
    $duplicates = @($Actual | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name)
    if ($duplicates.Count -gt 0) {
        throw "Duplicate $Label entries: $($duplicates -join ', ')"
    }
    $differences = @(Compare-Object -ReferenceObject @($Expected | Sort-Object) -DifferenceObject @($Actual | Sort-Object) -CaseSensitive)
    if ($differences.Count -gt 0) {
        $details = $differences | ForEach-Object { '{0} {1}' -f $_.SideIndicator,$_.InputObject }
        throw "Unexpected or missing $Label entries:`n$($details -join [Environment]::NewLine)"
    }
}

$expectedPermissions = @(
    'android.permission.INTERNET',
    'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.RECEIVE_BOOT_COMPLETED',
    'android.permission.SCHEDULE_EXACT_ALARM',
    'com.android.alarm.permission.SET_ALARM',
    'android.permission.VIBRATE',
    'android.permission.POST_NOTIFICATIONS',
    "$expectedApplicationId.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION",
    'android.permission.ACCESS_NETWORK_STATE'
)
$permissionNodes = @($manifest.SelectNodes('/manifest/*[starts-with(local-name(), "uses-permission")]'))
$actualPermissions = @($permissionNodes | ForEach-Object { Get-AndroidAttribute $_ 'name' })
Assert-ExactSet 'uses-permission' $expectedPermissions $actualPermissions
Write-Output "PASS merged permission allowlist ($($actualPermissions.Count) entries)"

$expectedExported = @()
foreach ($theme in @('Blue','Teal','Violet','Amber','Red')) {
    foreach ($mode in @('','Light','Dark')) {
        $expectedExported += "$expectedApplicationId.Launcher$theme$mode"
    }
}
$expectedExported += @(
    "$expectedApplicationId.ScheduleWidgetProvider",
    "$expectedApplicationId.TodayWidgetProvider",
    "$expectedApplicationId.WeekWidgetProvider",
    "$expectedApplicationId.NextClassWidgetProvider",
    "$expectedApplicationId.DeadlineWidgetProvider",
    "$expectedApplicationId.ScheduleWidgetConfigureActivity",
    'androidx.profileinstaller.ProfileInstallReceiver'
)

$componentNodes = @($application.SelectNodes('*') | Where-Object { $_.LocalName -in @('activity','activity-alias','receiver','service','provider') })
$implicitExported = @($componentNodes | Where-Object { [string]::IsNullOrWhiteSpace((Get-AndroidAttribute $_ 'exported')) })
if ($implicitExported.Count -gt 0) {
    $names = $implicitExported | ForEach-Object { Get-AndroidAttribute $_ 'name' }
    throw "Components must declare android:exported explicitly: $($names -join ', ')"
}
$actualExported = @($componentNodes | Where-Object { (Get-AndroidAttribute $_ 'exported') -ceq 'true' } | ForEach-Object { Get-AndroidAttribute $_ 'name' })
Assert-ExactSet 'exported component' $expectedExported $actualExported
Write-Output "PASS exported-component allowlist ($($actualExported.Count) components)"

$componentsByName = @{}
foreach ($component in $componentNodes) {
    $name = Get-AndroidAttribute $component 'name'
    if ($name) { $componentsByName[$name] = $component }
}

$mainActivityName = "$expectedApplicationId.MainActivity"
if (-not $componentsByName.ContainsKey($mainActivityName) -or (Get-AndroidAttribute $componentsByName[$mainActivityName] 'exported') -cne 'false') {
    throw 'MainActivity must exist and remain non-exported.'
}

foreach ($theme in @('Blue','Teal','Violet','Amber','Red')) {
    foreach ($mode in @('','Light','Dark')) {
        $aliasName = "$expectedApplicationId.Launcher$theme$mode"
        $alias = $componentsByName[$aliasName]
        if (-not $alias -or $alias.LocalName -cne 'activity-alias' -or (Get-AndroidAttribute $alias 'targetActivity') -cne $mainActivityName) {
            throw "Launcher alias '$aliasName' must target the private MainActivity."
        }
        $actions = @($alias.SelectNodes('.//action') | ForEach-Object { Get-AndroidAttribute $_ 'name' })
        $categories = @($alias.SelectNodes('.//category') | ForEach-Object { Get-AndroidAttribute $_ 'name' })
        if ('android.intent.action.MAIN' -notin $actions -or 'android.intent.category.LAUNCHER' -notin $categories) {
            throw "Launcher alias '$aliasName' is missing its MAIN/LAUNCHER filter."
        }
    }
}

foreach ($widget in @('ScheduleWidgetProvider','TodayWidgetProvider','WeekWidgetProvider','NextClassWidgetProvider','DeadlineWidgetProvider')) {
    $name = "$expectedApplicationId.$widget"
    $component = $componentsByName[$name]
    $actions = @($component.SelectNodes('.//action') | ForEach-Object { Get-AndroidAttribute $_ 'name' })
    if (-not $component -or $component.LocalName -cne 'receiver' -or 'android.appwidget.action.APPWIDGET_UPDATE' -notin $actions) {
        throw "Exported widget receiver '$name' must declare APPWIDGET_UPDATE."
    }
}

$configureName = "$expectedApplicationId.ScheduleWidgetConfigureActivity"
$configure = $componentsByName[$configureName]
$configureActions = @($configure.SelectNodes('.//action') | ForEach-Object { Get-AndroidAttribute $_ 'name' })
if (-not $configure -or $configure.LocalName -cne 'activity' -or 'android.appwidget.action.APPWIDGET_CONFIGURE' -notin $configureActions) {
    throw 'The exported widget configuration activity must be restricted to the documented launcher configure action.'
}

$profileInstaller = $componentsByName['androidx.profileinstaller.ProfileInstallReceiver']
if (-not $profileInstaller -or (Get-AndroidAttribute $profileInstaller 'permission') -cne 'android.permission.DUMP') {
    throw 'The exported ProfileInstallReceiver must remain protected by android.permission.DUMP.'
}

foreach ($privateName in @(
    "$expectedApplicationId.ScheduleWidgetRefreshReceiver",
    "$expectedApplicationId.ScheduleOcrService",
    'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver',
    'com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver'
)) {
    if (-not $componentsByName.ContainsKey($privateName) -or (Get-AndroidAttribute $componentsByName[$privateName] 'exported') -cne 'false') {
        throw "Sensitive integration component '$privateName' must exist and remain non-exported."
    }
}

$dynamicPermissionName = "$expectedApplicationId.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION"
$dynamicPermission = @($manifest.SelectNodes('/manifest/permission') | Where-Object { (Get-AndroidAttribute $_ 'name') -ceq $dynamicPermissionName }) | Select-Object -First 1
if (-not $dynamicPermission -or (Get-AndroidAttribute $dynamicPermission 'protectionLevel') -cne 'signature') {
    throw 'The AndroidX dynamic-receiver permission must remain signature-protected.'
}
Write-Output 'PASS launcher, widget, reminder, OCR and receiver exposure checks'

if ((Get-AndroidAttribute $application 'allowBackup') -cne 'false' -or (Get-AndroidAttribute $application 'fullBackupContent') -cne 'false') {
    throw 'Personal schedule backup must remain disabled in the Android app manifest.'
}
$cleartext = Get-AndroidAttribute $application 'usesCleartextTraffic'
if ($cleartext -ceq 'true') {
    throw 'Cleartext network traffic must remain disabled.'
}
Write-Output 'PASS app backup and cleartext restrictions'
