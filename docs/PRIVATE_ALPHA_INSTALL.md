# StudyShift private alpha install and recovery

**Status: preparation only.** This guide is a checklist for a future owner-approved, privately signed Android APK. The current local personal debug QA build is `0.1.0+24366` (`app/build/app/outputs/flutter-apk/app-personal-debug.apk`, 205,605,555 bytes, SHA-256 `2512549C9D0F6D7340AB148A7F4A8A19899F78F5E8B53C6AD1C1D953A89D657B`). It is debug-signed, not a release, and must not be shared as a private release. Release key, certificate and signed-release fields below remain blank until an owner-controlled release is approved.

## Release record

- Artifact: `[OWNER-APPROVED SIGNED APK PATH]`
- Package: `app.shiftstudy.mobile`
- Version name / Android version code: `[VERSION NAME]` / `[VERSION CODE]`
- Signing certificate SHA-256: `[CERTIFICATE SHA-256]`
- APK SHA-256: `[APK SHA-256]`
- Build date and Android target: `[BUILD DATE]` / `[TARGET API]`

Do not put a keystore, passwords, private certificate material or real schedule data in this document, the repository, a chat or an issue. The project requires the release keystore to remain outside the repository with two owner-controlled encrypted offline backups. Only the owner should provide or enter the signing values through a secure local process.

## Before installing or updating

1. Confirm that the artifact is the approved **release-signed APK**, not a debug or review APK. Direct APK installation is the project’s private Android route; Google Play publishing and AAB distribution are outside this scope.
2. Compare the APK SHA-256 with the release record. On Windows PowerShell:

   ```powershell
   Get-FileHash -Algorithm SHA256 "[APK PATH]"
   ```

3. Verify the APK signature and compare its certificate SHA-256 with the owner-approved release record:

   ```powershell
   apksigner verify --verbose --print-certs "[APK PATH]"
   ```

4. Confirm the package is `app.shiftstudy.mobile` and that the Android version code is the approved value. The package ID and signing identity must match the installed app for an in-place update; the version code must advance.
5. Export an encrypted `.ssbackup` from StudyShift’s **More → Your data → Backup & restore** flow before updating. Keep the backup and its passphrase private and separate. Confirm the backup file and passphrase are available before continuing.

If the hash, signature, package ID or version does not match the release record, stop. Do not install the file or uninstall the working app to work around a mismatch.

## Install or update

- **First install:** open the verified APK on the owner’s Android device and review Android’s package-installer screen. Confirm only if the displayed app is StudyShift and the release record matches. Review the app’s permission prompts when they appear; decline any permission that does not match the expected feature and report the mismatch.
- **Update:** install over the existing StudyShift app using Android’s package installer. Confirm the update only if Android accepts it as the same app and does not report a signature conflict. Do not uninstall the existing app, clear its storage, or use downgrade/bypass options to force an update.
- Open StudyShift and confirm the expected version in **More → About StudyShift**. Check that saved schedule data is present, then verify the release’s stated change and reminder/widget behavior. Keep the encrypted backup until the owner confirms the update is sound.

For an explicitly authorized development acceptance run only, `adb install -r "[APK PATH]"` performs an in-place package replacement when Android accepts the package identity, signature and version. This command is not a substitute for signing-certificate checks or owner-device acceptance.

## Recovery

- If Android rejects the update for a signature or package mismatch, cancel. Leave the installed app and its data untouched; obtain the correctly signed artifact from the owner.
- If Android rejects it as a downgrade, do not uninstall or force the downgrade. Keep the current app installed and obtain a properly incremented compatible update.
- If the app opens but data is missing or incorrect, stop making schedule changes. Preserve the current installation, verify the pre-update `.ssbackup`, then use StudyShift’s restore flow only after confirming the intended backup and reviewing the proposed restore. Never overwrite or replace data without the app’s confirmation step.
- Do not clear app storage or uninstall as a troubleshooting step: that can remove the local schedule. If recovery is uncertain, stop and ask the owner before changing app data.

## Current readiness boundary

No owner-controlled release keystore, signed release APK, release certificate fingerprint or approved release checksum is currently recorded. The fail-closed release guard is tested, but that does not prove a release can be signed or safely updated. Complete key custody and recovery, signed artifact verification, a signed update over retained data, and Galaxy One UI acceptance before marking private release acceptance complete. Do not distribute the current debug APK.
