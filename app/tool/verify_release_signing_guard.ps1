$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$gradleRoot = Join-Path $repoRoot 'app\android'
$gradle = Join-Path $gradleRoot 'gradlew.bat'
$insideRepoKey = Join-Path $repoRoot '.devtools\never-created-release-guard-test.jks'
$outsideRepoKey = Join-Path $env:TEMP 'never-created-studyshift-release-guard-test.jks'
$names = @(
    'SHIFT_STUDY_KEYSTORE',
    'SHIFT_STUDY_KEYSTORE_PASSWORD',
    'SHIFT_STUDY_KEY_ALIAS',
    'SHIFT_STUDY_KEY_PASSWORD'
)
$original = @{}
foreach ($name in $names) { $original[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }

function Invoke-GradleDryRun([string[]] $arguments, [hashtable] $environment) {
    foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $null, 'Process') }
    foreach ($name in $environment.Keys) { [Environment]::SetEnvironmentVariable($name, $environment[$name], 'Process') }
    $previousErrorActionPreference = $ErrorActionPreference
    Push-Location $gradleRoot
    try {
        # Gradle emits normal Kotlin-plugin diagnostics on stderr. PowerShell's
        # Stop preference can promote that stream to a terminating error before
        # this guard test captures the process exit code.
        $ErrorActionPreference = 'Continue'
        $output = (& $gradle @arguments --dry-run --no-daemon --console=plain 2>&1 | Out-String)
        return @{ ExitCode = $LASTEXITCODE; Output = $output }
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
        Pop-Location
    }
}

function Assert-FailureContains($result, [string] $expected, [string] $caseName) {
    if ($result.ExitCode -eq 0 -or $result.Output -notmatch [regex]::Escape($expected)) {
        throw "$caseName did not fail with expected guard '$expected' (exit $($result.ExitCode)).`n$($result.Output)"
    }
    Write-Output "PASS $caseName"
}

try {
    $debug = Invoke-GradleDryRun @(':app:assemblePersonalDebug') @{}
    if ($debug.ExitCode -ne 0) { throw "Debug dry-run unexpectedly failed.`n$($debug.Output)" }
    Write-Output 'PASS unsigned debug dry-run remains available'

    $missing = Invoke-GradleDryRun @(':app:packagePersonalRelease') @{}
    Assert-FailureContains $missing 'Private release signing is not configured' 'missing signing values block release packaging'

    $partial = Invoke-GradleDryRun @(':app:packagePersonalRelease') @{
        SHIFT_STUDY_KEYSTORE = $outsideRepoKey
    }
    Assert-FailureContains $partial 'Private release signing requires all' 'partial signing values are rejected'

    $inside = Invoke-GradleDryRun @(':app:packagePersonalRelease') @{
        SHIFT_STUDY_KEYSTORE = $insideRepoKey
        SHIFT_STUDY_KEYSTORE_PASSWORD = 'test-only-dummy'
        SHIFT_STUDY_KEY_ALIAS = 'test-only-dummy'
        SHIFT_STUDY_KEY_PASSWORD = 'test-only-dummy'
    }
    Assert-FailureContains $inside 'Keep the private release keystore outside the project repository' 'repository-local keystore path is rejected'

    $outside = Invoke-GradleDryRun @(':app:packagePersonalRelease') @{
        SHIFT_STUDY_KEYSTORE = $outsideRepoKey
        SHIFT_STUDY_KEYSTORE_PASSWORD = 'test-only-dummy'
        SHIFT_STUDY_KEY_ALIAS = 'test-only-dummy'
        SHIFT_STUDY_KEY_PASSWORD = 'test-only-dummy'
    }
    if ($outside.ExitCode -ne 0) { throw "External dummy path should pass the non-signing dry-run without reading a keystore.`n$($outside.Output)" }
    if ((Test-Path $insideRepoKey) -or (Test-Path $outsideRepoKey)) { throw 'The guard check unexpectedly created a keystore file.' }
    Write-Output 'PASS complete values with an external path pass graph preflight without a keystore file'
}
finally {
    foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $original[$name], 'Process') }
}
