$ErrorActionPreference = 'Stop'

$appRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $appRoot
$manifestPath = Join-Path $appRoot 'build\app\intermediates\merged_manifest\personalRelease\processPersonalReleaseMainManifest\AndroidManifest.xml'
$guardPath = Join-Path $PSScriptRoot 'verify_merged_release_manifest.ps1'
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Merged personal-release manifest is missing; run :app:processPersonalReleaseMainManifest first: $manifestPath"
}

$powershell = (Get-Command powershell.exe -ErrorAction Stop).Source
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    $baselineOutput = (& $powershell -NoProfile -ExecutionPolicy Bypass -File $guardPath -ManifestPath $manifestPath 2>&1 | Out-String)
    $baselineExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
if ($baselineExitCode -ne 0) {
    throw "The guard rejected the current merged release manifest.`n$baselineOutput"
}
Write-Output 'PASS current merged personal-release manifest matches the allowlist'

$temporaryManifest = Join-Path $env:TEMP ("studyshift-manifest-guard-{0}.xml" -f [Guid]::NewGuid().ToString('N'))
try {
    $xml = [IO.File]::ReadAllText($manifestPath)
    $modified = $xml.Replace('</manifest>', '    <uses-permission android:name="android.permission.READ_CONTACTS" />' + [Environment]::NewLine + '</manifest>')
    if ($modified -eq $xml) { throw 'Could not prepare the unexpected-permission test fixture.' }
    [IO.File]::WriteAllText($temporaryManifest, $modified, [Text.UTF8Encoding]::new($false))

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $rejectedOutput = (& $powershell -NoProfile -ExecutionPolicy Bypass -File $guardPath -ManifestPath $temporaryManifest 2>&1 | Out-String)
        $rejectedExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($rejectedExitCode -eq 0 -or $rejectedOutput -notmatch 'Unexpected or missing uses-permission') {
        throw "The guard did not reject the injected READ_CONTACTS permission as expected.`n$rejectedOutput"
    }
    Write-Output 'PASS injected READ_CONTACTS permission is rejected'
}
finally {
    if (Test-Path -LiteralPath $temporaryManifest) {
        Remove-Item -LiteralPath $temporaryManifest -Force
    }
}
