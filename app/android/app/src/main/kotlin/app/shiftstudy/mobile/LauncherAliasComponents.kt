package app.shiftstudy.mobile

internal fun launcherAliasClassName(mainActivityClassName: String, alias: String): String =
    "${mainActivityClassName.substringBeforeLast('.')}.${alias}"
