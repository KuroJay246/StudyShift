param(
  [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
  [string[]] $GradleArgs
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$JdkRoot = Join-Path $ProjectRoot '.devtools\jdk-21.0.12.1+1'
$AndroidUserRoot = Join-Path $ProjectRoot '.devtools\android-user'
$GradleWrapper = Join-Path $ProjectRoot 'app\android\gradlew.bat'
if (-not (Test-Path -LiteralPath (Join-Path $JdkRoot 'bin\java.exe'))) { throw "Project-local JDK 21 is missing: $JdkRoot" }
if (-not (Test-Path -LiteralPath $GradleWrapper)) { throw "Gradle Wrapper is missing: $GradleWrapper" }

# Gradle runs on JDK 21. Android CLI user state is isolated from the shared
# %USERPROFILE%\.android directory, whose lock file can be read-only here.
$env:JAVA_HOME = $JdkRoot
$env:ANDROID_USER_HOME = $AndroidUserRoot
$env:PATH = (Join-Path $JdkRoot 'bin') + ';' + $env:PATH
Push-Location (Join-Path $ProjectRoot 'app\android')
try {
  & $GradleWrapper @GradleArgs
  exit $LASTEXITCODE
} finally {
  Pop-Location
}
