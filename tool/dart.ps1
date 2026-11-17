param(
  [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
  [string[]] $DartArgs
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$JdkRoot = Join-Path $ProjectRoot '.devtools\jdk-21.0.12.1+1'
$AndroidUserRoot = Join-Path $ProjectRoot '.devtools\android-user'
$DartExe = Join-Path $ProjectRoot '.devtools\flutter\bin\dart.bat'
if (-not (Test-Path -LiteralPath $DartExe)) { throw "Project-local Dart is missing: $DartExe" }
$env:JAVA_HOME = $JdkRoot
$env:ANDROID_USER_HOME = $AndroidUserRoot
$env:PATH = (Join-Path $JdkRoot 'bin') + ';' + $env:PATH
& $DartExe @DartArgs
exit $LASTEXITCODE
