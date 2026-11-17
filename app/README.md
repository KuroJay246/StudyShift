# Shift & Study Android client

This is the Android-only Flutter client for the standalone Shift & Study project. Project-local Flutter, Dart and JDK 21 live in the ignored root `.devtools/` directory.

From this folder, use `..\tool\dev.ps1` for Flutter commands, `..\tool\dart.ps1` for Dart/build_runner commands, and `..\tool\gradle.ps1 assembleDebug` from the repository root to run Gradle explicitly on the project JDK 21.

The package ID is `app.shiftstudy.mobile`. Keep generated builds, emulator data, local SDKs, imports, preferences and signing material out of Git.
