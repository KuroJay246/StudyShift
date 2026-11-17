param(
  [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
  [string[]] $FlutterArgs
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$FlutterRoot = Join-Path $ProjectRoot '.devtools\flutter'
$JdkRoot = Join-Path $ProjectRoot '.devtools\jdk-21.0.12.1+1'
$AndroidUserRoot = Join-Path $ProjectRoot '.devtools\android-user'
$FlutterConfigRoot = Join-Path $ProjectRoot '.devtools\flutter-config'
$FlutterExe = Join-Path $FlutterRoot 'bin\flutter.bat'
$JavaExe = Join-Path $JdkRoot 'bin\java.exe'

if (-not (Test-Path -LiteralPath $FlutterExe)) { throw "Project-local Flutter is missing: $FlutterExe" }
if (-not (Test-Path -LiteralPath $JavaExe)) { throw "Project-local JDK 21 is missing: $JavaExe" }

# Process-scoped environment only: system JAVA_HOME and PATH are untouched.
$env:JAVA_HOME = $JdkRoot
$env:ANDROID_USER_HOME = $AndroidUserRoot
$env:APPDATA = $FlutterConfigRoot
$env:PATH = (Join-Path $JdkRoot 'bin') + ';' + $env:PATH
New-Item -ItemType Directory -Force -Path $FlutterConfigRoot | Out-Null
# Flutter otherwise prefers Android Studio's bundled JDK. Keep its JDK setting
# in this project's isolated Flutter config directory, not the user's profile.
& $FlutterExe config --jdk-dir $JdkRoot | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not select the project-local JDK 21 for Flutter.' }
& $FlutterExe @FlutterArgs
exit $LASTEXITCODE
