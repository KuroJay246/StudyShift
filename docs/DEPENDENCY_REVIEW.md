# Dependency review

**Reviewed:** 2026-11-17

## Gradle Wrapper distribution integrity — 2026-11-17

`app/android/gradle/wrapper/gradle-wrapper.properties` now pins the SHA-256 of the configured Gradle 9.3.1 complete (`-all`) distribution with `distributionSha256Sum=17f277867f6914d61b1aa02efab1ba7bb439ad652ca485cd8ca6842fccec6e43`. The digest was checked against Gradle's [official distribution checksum reference](https://gradle.org/release-checksums/). This enables Gradle Wrapper to reject a downloaded archive whose digest differs from the pinned value; it does not add dependency verification for Maven plugins or libraries.

The project wrapper launches Gradle 9.3.1 successfully under the pinned local Temurin JDK 21. The cached extracted distribution was used, so this run verifies wrapper configuration/build startup but does not exercise a fresh archive download and checksum rejection path.

## ML Kit OCR privacy and telemetry review — 2026-11-17

The pinned bundled dependency is `com.google.mlkit:text-recognition:16.0.1`. Its resolved Maven metadata includes `play-services-mlkit-text-recognition` and `play-services-mlkit-text-recognition-common:19.1.0`, which declares Android DataTransport/CCT components (`transport-api:2.2.1`, `transport-backend-cct:2.3.3`, and `transport-runtime:2.2.6`). The merged personal-release manifest consequently includes `android.permission.ACCESS_NETWORK_STATE`; this is a permission/dependency observation, not packet-capture proof of a request.

Google's current [ML Kit terms](https://developers.google.com/ml-kit/terms) state that input images/text and recognition output remain on-device, while ML Kit APIs may contact Google services and send performance/utilization metrics. The [Android data disclosure](https://developers.google.com/ml-kit/android-data-disclosure) describes general metrics such as device/app metadata, per-installation identifiers, API configuration, input/output sizes, feature versions, performance, event types, and error codes. That disclosure covers the latest SDK versions and does not establish every exact metric for pinned 16.0.1. The [bundled Text Recognition guide](https://developers.google.com/ml-kit/vision/text-recognition/v2/android) documents immediate/offline model availability; it does not document a telemetry opt-out for bundled OCR. No supported developer opt-out was found in these official sources.

**Policy result: OPEN RELEASE GATE.** StudyShift's `AGENTS.md` requires no telemetry, tracking, external AI calls, or network access by default. Bundled ML Kit protects OCR content from upload and supports offline recognition, but its documented service/metrics behavior does not establish compliance with the stricter no-telemetry rule. Do not claim that the OCR integration meets that policy or ship a release on this evidence. Before release, either identify and verify an official supported control that meets the policy or replace the OCR SDK with an implementation whose network behavior is acceptable. This review was documentation and local dependency inspection only; it did not inspect traffic or alter the dependency.

### Offline replacement candidate check — 2026-11-17

The current [Tesseract4Android 4.9.0 release](https://github.com/adaptech-cz/Tesseract4Android/releases/tag/4.9.0) bundles Tesseract 5.5.1, while upstream [Tesseract 5.5.4](https://github.com/tesseract-ocr/tesseract/releases/tag/5.5.4) is newer and its release notes report fixing 17 security advisories. Tesseract4Android's [build and usage instructions](https://github.com/adaptech-cz/Tesseract4Android/blob/master/README.md) also require a separately supplied v4 trained-data file and obtain the compiled Android artifact from JitPack. That wrapper/version pair is not a suitable drop-in replacement for the current OCR path without an updated, audited native build and model/license/size review. No replacement dependency or code was added. This narrows the next step to either verifying a supported ML Kit telemetry control or qualifying an updated, offline OCR build; the privacy gate remains open.

**Scope:** Direct Flutter runtime dependencies, the resolved hosted Pub graph, selected Android runtime/test/build pins, and the resolved Android release/debug runtime graphs. This is a bounded inventory, not a complete software-composition or security audit.

## Flutter runtime dependencies

Versions below are the resolved versions in `app/pubspec.lock`; the declared constraints are in `app/pubspec.yaml`. Each listed hosted package has a top-level `LICENSE` file in the corresponding versioned Pub cache directory. The license labels below were read from those local license texts because the cached package manifests do not declare a `license:` field. Package release/maintenance observations were checked against the linked Pub.dev package pages on the review date.

| Package | Locked version | License in local package `LICENSE` | Pub.dev maintenance observation on review date |
| --- | ---: | --- | --- |
| [`archive`](https://pub.dev/packages/archive) | 3.6.1 | MIT | Pub.dev listed 4.7.1; lock is behind. |
| [`crypto`](https://pub.dev/packages/crypto) | 3.0.8 | BSD-3-Clause | Lock matched the listed current version. |
| [`cryptography`](https://pub.dev/packages/cryptography) | 2.9.0 | Apache-2.0 | Lock matched the listed current version. |
| [`cryptography_flutter`](https://pub.dev/packages/cryptography_flutter) | 2.3.4 | Apache-2.0 | Lock matched the listed current version. |
| [`drift`](https://pub.dev/packages/drift) | 2.35.3 | MIT | Pub.dev listed 2.35.4; lock is one patch behind. |
| [`drift_flutter`](https://pub.dev/packages/drift_flutter) | 0.3.1 | MIT | Lock matched the listed current version. |
| [`firstfloor_calendar`](https://pub.dev/packages/firstfloor_calendar) | 1.0.14 | MIT | Lock matched the listed current version. |
| [`flutter_svg`](https://pub.dev/packages/flutter_svg) | 2.3.2 | MIT | Pub.dev listed 2.4.0; lock is behind. |
| [`flutter_local_notifications`](https://pub.dev/packages/flutter_local_notifications) | 21.0.0 | BSD-3-Clause | Pub.dev listed 23.0.2; lock is behind. |
| [`flutter_riverpod`](https://pub.dev/packages/flutter_riverpod) | 3.4.3 | MIT | Pub.dev listed 3.5.0; lock is behind. |
| [`go_router`](https://pub.dev/packages/go_router) | 18.1.3 | BSD-3-Clause | Pub.dev listed 18.1.4; lock is one patch behind. Its package page describes the project as feature-complete, with bug fixes and stability as the main focus. |
| [`spreadsheet_decoder`](https://pub.dev/packages/spreadsheet_decoder) | 2.3.0 | MIT | Pub.dev showed no newer version and a last publication about two years earlier; its uploader is marked unverified. Treat this as a maintenance-review signal, not proof of abandonment. |
| [`timezone`](https://pub.dev/packages/timezone) | 0.11.2 | BSD-3-Clause | Lock matched the listed current version. Package page reports bundled TZ database 2025c; this review did not independently validate that data against the current IANA release. |
| [`xml`](https://pub.dev/packages/xml) | 6.6.1 | MIT | Pub.dev listed 7.1.0; lock is behind. |

The Flutter SDK dependencies (`flutter`, `flutter_test`, and `integration_test`) are SDK-provided rather than separately versioned Pub packages here. `app/pubspec.yaml` sets the Dart SDK constraint to `^3.13.7`; the resolved Flutter SDK revision and its bundled dependency licenses were not audited in this document.

## Android and Gradle coordinates

These values come from `app/android/app/build.gradle.kts`, `app/android/settings.gradle.kts`, `app/android/gradle/wrapper/gradle-wrapper.properties`, and locally cached Maven POM metadata. Maven coordinates are not protected by a checked-in Gradle dependency lockfile in the inspected project paths, so transitive Gradle resolution is not represented as a complete locked graph here.

| Coordinate / component | Pin and role | License evidence | Review note |
| --- | --- | --- | --- |
| `com.google.mlkit:text-recognition` | 16.0.1, Android runtime OCR | Cached POM names ML Kit Terms of Service; this is a vendor service/license condition, not an OSI license label. | App build comment identifies the bundled Latin OCR model and offline use. Check the applicable ML Kit terms before distribution. |
| `com.android.tools:desugar_jdk_libs` | 2.1.4, Android runtime core-library desugaring | Cached POM: GPL-2.0 with Classpath Exception. | Google’s changelog lists 2.1.5 after this pin. No upgrade was made. |
| `junit:junit` | 4.13.2, Android test scope | Cached POM: EPL-1.0. | Updated from 4.12 after the advisory review; native unit suite passed on this pin. |
| `com.android.tools.build:gradle` | 9.1.0, Android Gradle Plugin | Cached POM: Apache-2.0. | Version comes from `settings.gradle.kts`; this was not treated as app runtime code. |
| `org.jetbrains.kotlin:kotlin-gradle-plugin` | 2.4.21, Kotlin Android build plugin | Cached POM: Apache-2.0. | Updated from 2.4.0 after the advisory review; native unit suite and personal debug build passed on this pin. |
| Gradle Wrapper | 9.3.1 distribution | Gradle distribution uses Apache-2.0; wrapper version is pinned by the distribution URL. | Official release notes document fixes in this release; that is not a complete security assessment. |
| Flutter Gradle plugins | Loader 1.0.0; app plugin supplied through the selected Flutter SDK included build | SDK-supplied; no separately cached Maven POM/license coordinate was declared here. | Flutter SDK version/revision was outside this dependency inventory. |

## Advisory and maintenance checks

On 2026-11-17, exact-version queries were sent to the OSV API for the 14 direct Pub runtime coordinates above and selected Maven coordinates. The initial query covered ML Kit text recognition 16.0.1, desugar_jdk_libs 2.1.4, JUnit 4.12, Android Gradle Plugin 9.1.0, and Kotlin Gradle plugin 2.4.0. OSV returned no records for the queried Pub runtime coordinates, ML Kit, desugar_jdk_libs, or AGP. The two exact-coordinate findings below were remediated by updating JUnit to 4.13.2 and Kotlin Gradle plugin to 2.4.21. Those replacement coordinates were not separately queried against OSV during this pass. This result is limited to the checked coordinates and queried database state; it does not establish that the packages are vulnerability-free.

OSV returned these findings:

- **Remediated JUnit 4.12 test dependency:** [GHSA-269g-pwp5-87pp](https://osv.dev/vulnerability/GHSA-269g-pwp5-87pp) concerns `TemporaryFolder` permissions on Unix-like systems; the advisory lists 4.13.1 as fixed. The project now pins 4.13.2 in `testImplementation`.
- **Remediated Kotlin Gradle plugin 2.4.0 build dependency:** [GHSA-r937-wjx7-w2jp](https://osv.dev/vulnerability/GHSA-r937-wjx7-w2jp) concerns unsafe deserialization in the Kotlin build cache; the advisory identifies 2.4.20-Beta1 as the first fixed prerelease. The project now pins stable 2.4.21. Official [Kotlin compatibility guidance](https://kotlinlang.org/docs/gradle-configure-project.html) and [Android Gradle Plugin compatibility guidance](https://developer.android.com/build/releases/about-agp) were checked against the current Gradle 9.3.1 and AGP 9.1.0 pins before the change.

The review also observed older direct pins relative to the Pub.dev package pages: `archive`, `drift`, `flutter_svg`, `flutter_local_notifications`, `flutter_riverpod`, `go_router`, and `xml`. This is version-awareness only, not an upgrade recommendation; compatibility, changelog, and regression review are required before changing pins. The `spreadsheet_decoder` publication age and unverified uploader warrant a focused maintenance/alternatives review before release.

## Resolved graph follow-up — 2026-11-17

The dependency graph was extended from direct declarations to the resolved package graph using project-pinned tools and the current lockfile:

| Graph | Scope and result | Advisory result |
| --- | --- | --- |
| Pub | `dart pub deps --json`: 129 nodes total, including 120 hosted Pub packages. All 120 exact package-version cache directories were present and each had a top-level `LICENSE` file. | OSV `POST /v1/querybatch` exact package/version queries for all 120 hosted packages returned **0 advisory matches**. |
| Android release runtime | Gradle `personalReleaseRuntimeClasspath`: 361 dependency edges, 132 distinct Maven group/artifact/version coordinates, and 0 resolution failure lines. | OSV batch query of all 132 coordinates returned **0 advisory matches**. |
| Android personal debug runtime | Gradle `personalDebugRuntimeClasspath`: 388 dependency edges and 153 distinct Maven coordinates. | Four advisory records matched: Guava `28.1-android` (`GHSA-5mg8-w23w-74h3`, `GHSA-7g45-4rm6-3mm3`, `GHSA-xxph-c9ww-hj94`) and JUnit `4.12` (`GHSA-269g-pwp5-87pp`). Gradle `dependencyInsight` traces both to `project :integration_test`; this project is a Flutter dev dependency. They were absent from the resolved personal release runtime graph. The checked-in direct Android test pin remains JUnit `4.13.2`. |
| Current direct Android pins | Queried exact versions for ML Kit text recognition `16.0.1`, desugar_jdk_libs `2.1.4`, JUnit `4.13.2`, Android Gradle Plugin `9.1.0`, and Kotlin Gradle plugin `2.4.21`. | **0 advisory matches** for these five coordinates. |

OSV's documented querybatch endpoint accepts multiple package/version queries and returns results in query order ([API documentation](https://google.github.io/osv.dev/post-v1-querybatch/)). The zero-match results describe only the exact coordinates and database state at query time; they are not proof that a package is vulnerability-free. The debug-only Guava/JUnit findings are retained in this record rather than forcing an app-runtime version override for a development integration-test dependency.

## Evidence and limits

- Local version and declaration evidence: `app/pubspec.yaml`, `app/pubspec.lock`, `app/android/app/build.gradle.kts`, `app/android/settings.gradle.kts`, and `app/android/gradle/wrapper/gradle-wrapper.properties`.
- Local Pub licenses: `%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\<package>-<locked-version>\LICENSE` for each of the 120 hosted packages in the resolved graph, including all 14 direct runtime dependencies.
- Local Maven license evidence: cached POMs under the Gradle module cache for the Maven coordinates in the Android table.
- Upstream package records: [Pub.dev](https://pub.dev/) package pages linked by package name above; [Google desugar_jdk_libs changelog](https://github.com/google/desugar_jdk_libs/blob/master/CHANGELOG.md); [Gradle 9.3.1 release notes](https://docs.gradle.org/9.3.1/release-notes.html); Kotlin release and Gradle compatibility documentation; and the linked OSV advisory records.
- OSV coverage now includes the locked hosted Pub graph and the resolved Android personal release/debug runtime graphs, plus the explicitly listed direct Android pins. It does not cover Gradle plugin/build-tool transitive graphs, every Android test configuration, all SDK/NDK components, license compatibility, source-code review, or a general security audit.
- The project does not contain a checked-in Gradle dependency lockfile in the inspected paths. The queried Gradle runtime graphs are resolved snapshots from 2026-11-17 and may change with repository metadata. After the direct JUnit/Kotlin pin updates, the Android `testReviewDebugUnitTest` suite passed (52 tests, 0 failures, 0 errors, 0 skipped), and a personal debug APK built successfully. This is wider than a direct-coordinate review but remains a bounded graph and advisory review.
