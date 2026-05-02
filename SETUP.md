# TatbeeqX — Setup Guide

Everything you need to install on a fresh machine to **open the code, modify it, and run it**. Companion to [README.md](README.md) (project intro) and [docs/03-getting-started.md](docs/03-getting-started.md) (first-run walkthrough).

The project targets **Windows desktop primarily**, with web, Android, iOS, and (containerized) Linux as secondary targets. Pick the platform sections you actually need — you don't have to install everything.

---

## TL;DR — minimum viable install

For "I just want to clone, open, and run the desktop app":

| # | Tool | Why |
|---|---|---|
| 1 | **Git** | Clone the repo |
| 2 | **Node.js 20+** | Backend runtime (Express + Prisma) |
| 3 | **Flutter SDK 3.27+** (3.41 verified) | Frontend |
| 4 | **Visual Studio 2022** with *Desktop development with C++* workload | Required for `flutter build windows` |
| 5 | **VS Code** (recommended) with the Flutter + Dart extensions | Editor |

That's it for desktop. Add platform sections below as needed.

---

## 1. Required for any platform

### 1.1 Git

| OS | Install |
|---|---|
| Windows | `winget install Git.Git` or [git-scm.com](https://git-scm.com/download/win) |
| macOS | `brew install git` (or Xcode Command Line Tools) |
| Linux | `apt install git` / `dnf install git` |

### 1.2 Node.js (backend)

- **Required: 20.x or newer.** The backend uses native `fetch()` and 20.x APIs.
- Windows: `winget install OpenJS.NodeJS.LTS` or [nodejs.org](https://nodejs.org)
- macOS: `brew install node@20`
- Linux: use [NodeSource](https://github.com/nodesource/distributions) or `nvm`

Verify: `node -v` (must print `v20.x.x` or higher).

### 1.3 Flutter SDK (frontend)

- **Required: stable channel, 3.27+.** Verified on 3.41.6.
- Install: [docs.flutter.dev/get-started/install](https://docs.flutter.dev/get-started/install)
- Recommended location on Windows: `C:\flutter`. Add `C:\flutter\bin` to PATH.
- Run `flutter doctor -v` after install to see what platform-specific extras you need.

Enable desktop targets explicitly (one-time):

```
flutter config --enable-windows-desktop
flutter config --enable-macos-desktop      # macOS only
flutter config --enable-linux-desktop      # Linux only
```

### 1.4 Code editor

- **VS Code** (team standard). Install the **Flutter** and **Dart** extensions.
- Or **Android Studio** if you prefer a heavier IDE (also bundles the Android SDK manager GUI).

---

## 2. Required to run **Windows desktop**

### 2.1 Visual Studio 2022

- Edition: Community is fine.
- **Workload required: "Desktop development with C++"** (this is what `flutter build windows --release` shells out to).
- Install: [visualstudio.microsoft.com](https://visualstudio.microsoft.com/)

After install, `flutter doctor` should show ✓ for Visual Studio.

---

## 3. Required to run **on Android**

> ⚠ **JDK gotcha:** AGP 8.11.x (this project's Android Gradle Plugin) **does not support JDK 26**. Use **JDK 17 or 21**. JDK 21 LTS is recommended.

### 3.1 JDK 21 (Eclipse Temurin LTS)

- **Download Windows x64:** [api.adoptium.net/v3/binary/latest/21/ga/windows/x64/jdk/hotspot/normal/eclipse](https://api.adoptium.net/v3/binary/latest/21/ga/windows/x64/jdk/hotspot/normal/eclipse)
- Or `winget install EclipseAdoptium.Temurin.21.JDK`
- Extract / install to e.g. `C:\Java\jdk-21` (the rest of this guide assumes this path).

Wire it up to Flutter:

```
flutter config --jdk-dir "C:\Java\jdk-21"
```

> Tip: keeping the JDK on `C:\` (rather than under your project on `F:\` or any other drive) avoids the Node `EXDEV: cross-device link not permitted` error from the Oracle Java VS Code extension's downloader.

### 3.2 Android SDK (command-line tools — no Android Studio needed)

1. Download `commandlinetools-win-{version}_latest.zip` from [developer.android.com/studio](https://developer.android.com/studio) (scroll to "Command line tools only").
2. Extract so you end up with `C:\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat`. The `latest` directory name is mandatory — `sdkmanager` will refuse to run without it.
3. Set `ANDROID_HOME` (User-level env var) to `C:\Android\Sdk`.
4. Open a fresh terminal and run:

```
sdkmanager --licenses
   (accept all)
sdkmanager "platform-tools" "platforms;android-35" "platforms;android-36" "build-tools;35.0.0" "build-tools;36.0.0"
```

5. Wire to Flutter:

```
flutter config --android-sdk "C:\Android\Sdk"
```

### 3.3 Windows Developer Mode

- **Settings → Privacy & security → For developers → Developer Mode = On.**
- Required for Flutter symlink support during plugin builds. Without it, `flutter pub get` / Android builds can fail with *"Building with plugins requires symlink support."*
- Keep it on while you're actively doing mobile work; you can flip it off afterward.

After all the Android pieces, `flutter doctor` should show ✓ for Android toolchain.

### 3.4 Release signing (only when you actually ship to a store / sideload)

- Debug builds work without any signing setup. Skip this section unless you're about to distribute APKs / AABs.
- See [docs/46-mobile-release-signing.md](docs/46-mobile-release-signing.md) for: generating a keystore with `keytool`, the `key.properties` file format, and how Play App Signing fits in.
- The build is set up to fall back to debug keys when `frontend/android/key.properties` is absent, so `flutter run --release` still works locally without a keystore.

---

## 4. Required to run **on iOS** (macOS only — Apple's rules, not ours)

- **Xcode** (latest, from the Mac App Store).
- **CocoaPods**: `sudo gem install cocoapods` (or `brew install cocoapods` on Apple Silicon).
- An **Apple Developer account** if you want to run on a physical device or distribute via TestFlight / App Store.

`flutter doctor` should then show ✓ for Xcode.

---

## 5. Required to run **on the web**

Web has no extra installs beyond Flutter itself. A modern Chrome or Edge is enough — `flutter run -d chrome` or `flutter build web` just works.

---

## 6. Optional — Postgres / MySQL dev loop

The default DB is **SQLite** (file under `backend/prisma/`). The backend's `lib/backup.js` also supports Postgres (via `pg_dump`) and MySQL (via `mysqldump`), per Phase 4.7.

If you want to test the cloud-DB path locally:

### 6.1 Docker Desktop

- Install: [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/)
- Brings up a Postgres container via the (commented) `postgres` service in [docker-compose.yml](docker-compose.yml).

### 6.2 PostgreSQL client tools

- The native-backups path spawns `pg_dump`. It must be on PATH.
- Windows: install via the Postgres Windows installer ([postgresql.org/download/windows](https://www.postgresql.org/download/windows/)) and add `C:\Program Files\PostgreSQL\16\bin` to PATH.
- macOS: `brew install libpq` then `brew link --force libpq`.

(Mirror with `mysql-client` / `mysqldump` if you target MySQL.)

---

## 7. Optional — outbound email (SMTP)

Email is **off by default**. The system stays fully functional without it — emails just stub out (printed to console in dev, silent no-op in prod). Wire it up when you want any of:

- Self-serve "Forgot password?" flow ([POST /api/auth/forgot-password](backend/src/routes/auth.js)).
- Email notifications when an approval request is approved or rejected (in-app notifications still fire either way).
- The workflow engine's `send_email` action ([docs/48-workflow-engine.md](docs/48-workflow-engine.md)).

It's vendor-neutral SMTP — pick any provider:

- **Transactional API with an SMTP relay** — Resend, Postmark, SendGrid, Mailgun, AWS SES (use their SMTP endpoint, not their HTTP API).
- **Self-hosted Postfix** on the same LAN.
- **Gmail / Workspace** with an [App Password](https://support.google.com/accounts/answer/185833).

In `backend/.env`:

```ini
SMTP_HOST=smtp.your-provider.com
SMTP_PORT=587
SMTP_SECURE=false           # true for port 465 (implicit TLS), false for 587 (STARTTLS)
SMTP_USER=apikey-or-username
SMTP_PASS=your-secret
SMTP_FROM="TatbeeqX <no-reply@your-domain.com>"

# Public app URL — used inside email links (password reset, etc.)
APP_URL=https://your-public-url
```

Restart the backend. To verify, hit `POST /api/auth/forgot-password` with `{"identifier":"superadmin"}` — you should see the email arrive, and the audit log records `password_reset.requested`.

To make the workflow `send_email` action **fail loudly** when SMTP isn't configured (default is "step succeeds with `stubbed:true`" so chains compose on dev boxes), set `BAIL_ON_NO_SMTP=1`.

---

## 8. Optional — webhook receiver / off-site backup tools

If you also want to run [tools/backup-sync/](tools/backup-sync/) for cross-host backup replication (Phase 4.10):

- Same Node 20+ as above.
- Optional: `restic` on PATH if using `UPLOADER=restic`.
- Optional: an S3 endpoint (any provider — AWS, B2, Wasabi, MinIO, R2) if using `UPLOADER=s3` (no SDK needed; the receiver hand-rolls SigV4).

---

## 9. First-time setup commands

After all the install steps for your chosen platforms, from the project root:

### 9.1 Backend

```
cd backend
cp .env.example .env          # edit secrets if you want
npm install
npm run db:reset              # creates SQLite, applies migrations, runs seed
npm run dev                   # API on http://localhost:4000
```

`npm run db:reset` is idempotent — re-run it anytime to start clean.

### 9.2 Frontend

```
cd frontend
flutter pub get
flutter run -d windows        # or: chrome / android / ios / linux / macos
```

Login with the seeded super-admin:

```
username: superadmin
password: ChangeMe!2026
```

(overridable via `SEED_SUPERADMIN_USERNAME` / `SEED_SUPERADMIN_PASSWORD` env vars in `backend/.env`.)

### 9.3 LAN dev with mobile

Physical Android / iOS devices can't reach `localhost` — use the host machine's LAN IP:

```
flutter run -d android --dart-define=API_BASE_URL=http://<host-lan-ip>:4000/api
flutter run -d ios     --dart-define=API_BASE_URL=http://<host-lan-ip>:4000/api
```

Android emulators can use `http://10.0.2.2:4000/api` (the emulator's loopback to host).

---

## 10. Verifying the install

From `frontend/`:

```
flutter doctor -v
```

Expect ✓ for the platforms you set up. `[X]` is fine for platforms you skipped.

From `backend/`:

```
npm test
```

Expect a passing vitest run (340 tests / 28 files as of Phase 4.19, plus 8 cross-language webhook tests that auto-skip on machines without Python/Go/PHP/Bash on PATH).

CI runs the same suite plus `flutter analyze` on every push to `main` and every pull request — see [.github/workflows/ci.yml](.github/workflows/ci.yml).

---

## 11. Common gotchas

- **JDK version mismatch.** `flutter build apk` failing with a terse `What went wrong: 26.0.1` (or any single number) means the JDK is too new for AGP. Re-point Flutter at JDK 17 or 21: `flutter config --jdk-dir "<path>"`.
- **Missing Windows Developer Mode.** Symptom: *"Building with plugins requires symlink support."* Fix: turn Developer Mode on.
- **EXDEV cross-device link.** When the Oracle Java VS Code extension tries to install a JDK to a different drive than its download cache. Fix: install the JDK to the same drive as your `%LOCALAPPDATA%` (typically `C:\`).
- **`flutter gen-l10n` after editing ARBs.** After modifying any `frontend/lib/l10n/app_*.arb`, regenerate via `flutter gen-l10n` (or just `flutter run` — it does it for you). The generated class lives at `frontend/lib/l10n/gen/app_localizations.dart`.
- **ARB format drift.** `flutter gen-l10n` reformats ARBs to multi-line placeholder blocks. After the first generation, subsequent edits must match the new format, not the original compact one.
- **Mobile + LAN HTTP.** Android cleartext + iOS ATS exception are pre-configured for LAN dev (Phase 4.14). Tighten before App Store / Play submission — don't ship those defaults.
- **`Forgot password?` returns 503.** That's the correct response when SMTP isn't configured — see section 7. Either wire up SMTP, or use the admin-token reset path: `POST /api/users/:id/password-reset` (Super Admin or `users.edit`) and share the returned token out of band.
- **`prisma migrate dev` is non-interactive in this shell.** Local schema changes use `npx prisma db push --accept-data-loss --skip-generate` for speed. When the schema is stable, generate a real migration with `npx prisma migrate diff --from-migrations prisma/migrations --to-schema-datamodel prisma/schema.prisma --script` to avoid CI drift.
- **Workflow `notify_user` action says "could not resolve user".** The action takes `userId` OR `username` OR `email`. First match wins; the resolver returns null for a user that's been deleted/disabled, which surfaces as a step failure. Use a stable username for cross-install workflows (templates re-create users with new ids).

---

## 12. Reference summary — every install in one table

| Tool | Required for | Where to get it |
|---|---|---|
| Git | All work | [git-scm.com](https://git-scm.com/) / `winget install Git.Git` |
| Node.js 20+ | Backend | [nodejs.org](https://nodejs.org/) / `winget install OpenJS.NodeJS.LTS` |
| Flutter 3.27+ | Frontend (any platform) | [docs.flutter.dev/get-started/install](https://docs.flutter.dev/get-started/install) |
| VS Code (or Android Studio) | Editor | [code.visualstudio.com](https://code.visualstudio.com/) |
| Visual Studio 2022 + C++ workload | Windows desktop builds | [visualstudio.microsoft.com](https://visualstudio.microsoft.com/) |
| JDK 21 (Temurin) | Android builds | [adoptium.net](https://adoptium.net/) / `winget install EclipseAdoptium.Temurin.21.JDK` |
| Android SDK cmdline-tools + platform-tools + platforms 35/36 + build-tools 35/36 | Android builds | [developer.android.com/studio](https://developer.android.com/studio) (cmdline-tools only) |
| Windows Developer Mode | Android plugin builds on Windows | Settings → Privacy & security → For developers |
| Xcode + CocoaPods | iOS builds (macOS only) | App Store / `brew install cocoapods` |
| Docker Desktop | Postgres dev loop (optional) | [docker.com](https://www.docker.com/products/docker-desktop/) |
| `pg_dump` / `mysqldump` | Native cloud-DB backups (optional) | Postgres / MySQL official installers |
| `restic` | restic-mode backup-sync receiver (optional) | [restic.net](https://restic.net/) |
| SMTP server / relay | Outbound email (optional, Phase 4.19) | Any provider — Resend, Postmark, SendGrid, SES, Postfix, Gmail App Password |
