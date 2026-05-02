# 46 — Mobile release signing

Phase 4.14 carry-over, shipped 2026-05-02. The Flutter Android build now picks up an operator-supplied keystore for release builds, with debug-key fallback when none is configured. iOS still uses Xcode's automatic provisioning — out of scope until a customer needs App Store distribution.

## TL;DR

- **Debug builds:** unchanged. `flutter run -d android` and `flutter build apk --debug` work out of the box, no setup needed.
- **Release builds:**
  - Without `android/key.properties` → falls back to debug keys (warning-level: not suitable for distribution, but lets you test `flutter run --release` locally).
  - With `android/key.properties` → uses the keystore the file points at. **Required for Play Store / sideload distribution.**

The properties file and any `*.jks` / `*.keystore` are gitignored (see [`frontend/android/.gitignore`](../frontend/android/.gitignore)).

## Setting up signing

### 1. Generate a keystore (one-time, per-app)

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload \
  -storepass <store-password> \
  -keypass <key-password> \
  -dname "CN=TatbeeqX, OU=Eng, O=YourCompany, L=City, ST=State, C=US"
```

`keytool` ships with the JDK (`C:\Java\jdk-21\bin\keytool.exe` on the dev machine). The keystore is a single `.jks` file — guard it carefully (lose it and you can never publish updates to the same Play Store listing under that signing key).

Move the resulting `upload-keystore.jks` into `frontend/android/` next to `key.properties`.

### 2. Create `key.properties`

Copy [`frontend/android/key.properties.example`](../frontend/android/key.properties.example) to `frontend/android/key.properties` and fill in the four values:

```
storeFile=upload-keystore.jks
storePassword=<store-password>
keyAlias=upload
keyPassword=<key-password>
```

### 3. Build a signed release

```bash
cd frontend
flutter build apk --release          # → build/app/outputs/flutter-apk/app-release.apk
# or for Play Store upload:
flutter build appbundle --release    # → build/app/outputs/bundle/release/app-release.aab
```

The build will print `Storing key in <jks>` style log lines confirming the signing config was picked up.

### 4. Verify the signature

```bash
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
```

Should print the certificate matching the keystore's CN/OU/O fields. If it prints the Android debug certificate (`CN=Android Debug, O=Android, C=US`), `key.properties` was missed — re-check its location and contents.

## Where the wiring lives

[`frontend/android/app/build.gradle.kts`](../frontend/android/app/build.gradle.kts) reads `key.properties` at configure time, registers a `release` `signingConfig` only if all required keys are present, and switches `buildTypes.release.signingConfig` between `release` and `debug` based on that.

The fallback to debug keys (when `key.properties` is absent) is intentional — keeps `flutter run --release` working in dev without forcing every contributor to provision a keystore.

## Distribution paths

### Play Store (Google's recommended)

1. Build with `flutter build appbundle --release`.
2. Upload the `.aab` to the Play Console.
3. Enable Play App Signing — Google holds the actual signing key; your `upload-keystore.jks` is just the **upload** key. (This is why the file/alias is named `upload-keystore` / `upload`.)

### Sideload / direct APK distribution

1. Build with `flutter build apk --release`.
2. Distribute the `.apk` directly. **The same upload key signs every release** — losing it means any future updates can't be installed over the existing app (users would have to uninstall first). Back the keystore up to a password manager **and** offline storage.

## Known gaps / future work

- **No CI signing.** Today the keystore lives on the dev machine. If you wire up GitHub Actions / Gitea Actions for release builds, store the keystore as a base64-encoded secret and decode at build time (standard pattern; not yet documented here because no CI is set up).
- **No iOS release signing.** `frontend/ios/` still relies on Xcode automatic provisioning. Real iOS distribution needs an Apple Developer account, App Store Connect setup, and certificate / provisioning-profile management — separate phase.
- **`AndroidManifest.xml` still allows cleartext HTTP** for LAN dev (Phase 4.14). Tighten before any public-internet release: remove `usesCleartextTraffic="true"`, add a `network-security-config` that pins your prod domain.
- **Manifest's `applicationId` is still `com.TatbeeqX.tatbeeqx`** (Flutter scaffold default). For Play Store, change this to your actual reverse-domain ID **before** the first release — it's permanent once published.

## Recovery: lost keystore

There is no recovery. If you lose the keystore:
- **Play Store:** if Play App Signing was enabled, contact Play support to reset the upload key. If it wasn't, the listing is permanently locked — you'd need to publish a new app with a new package name.
- **Sideload:** all existing installations have to uninstall before they can install a new release. There's no migration path.

Back up the keystore. Twice.
