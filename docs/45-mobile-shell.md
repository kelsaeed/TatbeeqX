# 45 — Mobile shell (Phase 4.14)

The Flutter app now runs on iOS and Android in addition to Windows desktop and web. This was the last item carried over from Phase 4.11; it slipped to 4.14 because mobile is a new platform target with its own scaffolding, signing, and verification surface.

## What changed

- **iOS + Android scaffolds.** [frontend/ios/](../frontend/ios/) and [frontend/android/](../frontend/android/) are present and buildable. No native plugins were added — the app still uses plain `dart:io` for storage, just behind a directory resolver that knows about each platform.
- **`path_provider: ^2.1.5`** added to [frontend/pubspec.yaml](../frontend/pubspec.yaml). It is the single concession to platform APIs — used only to locate a writable app-support directory on iOS/Android. Windows/macOS/Linux still use `APPDATA` / `HOME` directly.
- **`TokenStorage._resolveDir()`** in [frontend/lib/core/storage/secure_storage.dart](../frontend/lib/core/storage/secure_storage.dart) now branches: `getApplicationSupportDirectory()` on iOS/Android, environment-variable lookup on desktop, `Directory.systemTemp` as last resort. The on-disk format is unchanged — same `auth.json` blob, same `accessToken` / `refreshToken` / extras keys — so the existing token-storage tests cover both paths.
- **Android manifest.** [frontend/android/app/src/main/AndroidManifest.xml](../frontend/android/app/src/main/AndroidManifest.xml) declares `android.permission.INTERNET` and sets `android:usesCleartextTraffic="true"` on the application. Cleartext is required because the LAN deployment model points the app at `http://<host-ip>:4000/api`. Tighten this for a public-internet rollout (HTTPS-only + a network-security-config XML).
- **iOS Info.plist.** [frontend/ios/Runner/Info.plist](../frontend/ios/Runner/Info.plist) sets `NSAppTransportSecurity.NSAllowsArbitraryLoads = true` for the same reason. Same caveat — restrict to specific hosts before App Store submission.
- **No router or shell changes.** The responsive sidebar→drawer swap below 800 px width has been in `dashboard_shell.dart` since Phase 4.6. On a phone the sidebar opens via the topbar hamburger (`isMobile ? Drawer(child: sidebar) : null` at [dashboard_shell.dart:112](../frontend/lib/features/dashboard/presentation/dashboard_shell.dart#L112); the menu button at [dashboard_shell.dart:343](../frontend/lib/features/dashboard/presentation/dashboard_shell.dart#L343)) and tapping a menu item dismisses it.

## How to run

**Android** (device or emulator on the dev machine):

```
cd frontend
flutter run -d android --dart-define=API_BASE_URL=http://<lan-ip>:4000/api
```

`<lan-ip>` is the host running the backend. `localhost` resolves to the phone, not your dev machine — use the LAN IP. The Android emulator can also use `10.0.2.2` to reach the host's loopback.

**iOS** (simulator or device, requires macOS):

```
cd frontend
flutter run -d ios --dart-define=API_BASE_URL=http://<lan-ip>:4000/api
```

The simulator can hit `localhost` directly. A physical device needs the LAN IP.

**Release builds.** Both platforms build with `flutter build apk` / `flutter build ios`, but neither is configured with production signing yet:

- Android `release` block in [frontend/android/app/build.gradle.kts](../frontend/android/app/build.gradle.kts) still falls back to the debug signing config. Wire a real `signingConfig` + keystore before publishing.
- iOS uses the default `automatic` provisioning; no explicit team is set. Configure code signing in Xcode (Runner.xcodeproj → Signing & Capabilities) before archiving for TestFlight or the App Store.

## What did not change

- **No native plugins** beyond `path_provider`. The "no Flutter plugins" rule in [MEMORY.md](../MEMORY.md) was about avoiding the Windows symlink requirement; on mobile that constraint doesn't apply, but adding plugins still costs maintenance, so we are keeping the surface as small as possible.
- **No platform-specific UI**. The desktop shell + drawer behavior already covered narrow widths.
- **No new tests.** Mobile builds are verified via `flutter analyze` (clean) plus operator smoke-tests on a device. The frontend has no widget-test suite — same gap declared in Phase 4.11.

## Verification

- `flutter pub get` → resolves cleanly. 8 transitive packages have newer majors available; none are blockers.
- `flutter analyze` → "No issues found! (ran in 2.9s)".
- Manual smoke-test on Android emulator + iOS simulator: login → dashboard → drawer navigation → audit log paginated table → company switcher → logout. RTL flips correctly when Arabic is selected.

## Open follow-ups (not blocking)

- Production code signing for both platforms.
- Network-security-config XML to drop `usesCleartextTraffic` once an HTTPS proxy is the documented deployment.
- Restrict iOS ATS exception to specific hosts (`NSExceptionDomains`) before App Store submission.
- Store pipelines (Play Console + App Store Connect). Out of scope until a customer needs distribution.
