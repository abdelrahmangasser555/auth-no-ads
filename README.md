# Auth No Ads

Personal authenticator and password vault. **No ads. No VIP. No cloud account.**

Codes are generated on this device (TOTP / HOTP, the same system GitHub, Google, AWS, and Microsoft use). The vault is encrypted with **AES-256-GCM**. Unlock with **fingerprint** (Android) or a **6-digit PIN**. Brand logos for known sites are bundled from [svgl.app](https://svgl.app/) so they work offline.

This is the `starter` branch — the full personal build.

---

## On this PC (Windows)

These paths are already set in the `.bat` files:

| Tool | Location |
| --- | --- |
| Flutter | `C:\Users\PC\dev\flutter` |
| JDK 17 | `C:\Program Files\Microsoft\jdk-17.0.21.21-hotspot` |
| Android SDK | `C:\Users\PC\dev\android-sdk` |

### 1. Run the app in Microsoft Edge (fastest)

Double-click **`START_HERE.bat`**.

Leave that black window open. Edge opens the app at phone width. Create a 6-digit PIN (fingerprint is phone-only). Codes you add here are a preview — the real vault lives on your Galaxy.

### 2. Run every test

Double-click **`RUN_TESTS.bat`**.

Or in PowerShell from this folder:

```powershell
$env:PATH = "C:\Users\PC\dev\flutter\bin;C:\Program Files\Microsoft\jdk-17.0.21.21-hotspot\bin;" + $env:PATH
flutter test
```

That runs unit tests, security tests, layout tests (iPhone SE through Galaxy S22), and the onboarding / lock / tabs e2e flows.

### 3. Install on your Galaxy

Double-click **`BUILD_APK.bat`**. It writes `AuthNoAds-install.apk` in this folder.

1. Copy `AuthNoAds-install.apk` to the phone (USB, Drive, or Telegram to yourself).
2. Open the file. If Android says **Install unknown apps**, allow Files / Drive / Chrome, then Install.
3. Open **Auth No Ads**, create a PIN, allow fingerprint.
4. Tap **+** → **Scan QR code** (or type the setup key).

Keep one encrypted backup: **Backup → Save codes to a file**. On a new phone, **Open a backup file** and enter the same password. There is no cloud database.

---

## What you can do

- **Home** — 2FA codes, categories, search, copy on tap, countdown ring, brand icons when the issuer is known
- **Password** — save logins, generate strong passwords, Have I Been Pwned leak check (k-anonymity)
- **Backup** — one encrypted `.safeauth` file you send and open yourself
- **Migrate** — drop a SafeAuth / authenticator export into the app; on Android you can link that file so new accounts sync when it changes
- **Home screen widget** — pick up to 8 accounts and see live codes on the Android home screen without opening the app
- **Settings** — app lock, hide codes, block screenshots, security score, widget account picker

## Security

- Secrets never leave the phone unless you export an encrypted backup
- PIN is mixed with a device key (a stolen file is not enough)
- Screenshot blocking is on by default (`FLAG_SECURE`)
- Android backup / cloud extraction is disabled
- Five wrong PINs trigger a cooldown
- A stolen backup file is useless without the backup password

## Project layout

```
lib/           app code (crypto, vault, UI)
test/          unit, security, UX layout, e2e
assets/brands/ bundled SVGL logos (offline)
tool/          python tool/sync_brand_icons.py
START_HERE.bat run in Edge
RUN_TESTS.bat  flutter test
BUILD_APK.bat  release APK for the Galaxy
```

## If Flutter is missing on another machine

1. Install [Flutter](https://docs.flutter.dev/get-started/install/windows) and JDK 17.
2. `flutter doctor`
3. `flutter pub get`
4. `flutter test`
5. `flutter run -d edge` or `flutter build apk --release`
