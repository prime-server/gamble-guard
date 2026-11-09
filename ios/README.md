# Gamble Guard for iPhone and iPad

A free native app that makes an iPhone stop gambling. Three taps, and the phone stays that way.
Phones cannot run the daemon or edit the hosts file the desktop versions use, so the app uses the
two things iOS gives an app, and locks them with the one thing iOS lets a person lock.

| Step | What happens | Which API |
|---|---|---|
| 1. Authorize Screen Time | Every browser on the phone blocks ~3,000 bundled gambling domains, 155 core brands from every region, and Apple's adult-content filter. Pick gambling apps and they are shielded. | FamilyControls `AuthorizationCenter.shared.requestAuthorization(for: .individual)`, ManagedSettings `webContent.blockedByFilter = .auto(domains, except: [])`, `shield.applications`, `FamilyActivityPicker` |
| 2. Turn on DNS protection | Mullvad's free `family` resolver becomes the system DNS over DNS-over-TLS (`family.dns.mullvad.net`, `194.242.2.6` / `2a07:e340::6`). Gambling domains get no answer, in every app. | NetworkExtension `NEDNSSettingsManager`, `NEDNSOverTLSSettings` |
| 3. Lock it | Deleting Apps is switched off for the whole phone, this app included. The Screen Time passcode then holds everything in place. | ManagedSettings `application.denyAppRemoval = true` |

Step 1 and step 3 live in the system's Screen Time store: they survive relaunches and reboots, and
are protected by the Screen Time passcode. Step 2 is a system DNS configuration; it reaches every
app, not only browsers, and it is what the Screen Time layer cannot do.

The app collects nothing, sends nothing anywhere, has no account and no purchases.

## Build

Requirements: Xcode 16 or newer, an iPhone or iPad on iOS 17 or newer, an Apple Developer Program
membership (needed for the entitlements and for TestFlight; the app itself is free).

1. Open `ios/GambleGuard/GambleGuard.xcodeproj`. The project is hand-written; `project.yml` is the
   same project as an XcodeGen spec if you prefer `xcodegen generate`.
2. Target **GambleGuard → Signing & Capabilities**: pick your **Team**. `DEVELOPMENT_TEAM` in the
   project is the placeholder `YOUR_TEAM_ID`. Keep **Automatically manage signing** on.
3. Bundle identifier is `org.gambleguard.app`. If App Store Connect says it is taken, change it here
   and use the same one for the App ID below.
4. Drop a 1024×1024 PNG into `GambleGuard/Assets.xcassets/AppIcon.appiconset` (Xcode: select
   AppIcon, drag the image in). The App Store refuses an upload without it.
5. Run on a real device. Screen Time authorization only works on hardware; the simulator build is
   for compiling. Unsigned simulator check from the repo root:

   ```sh
   xcodebuild -project ios/GambleGuard/GambleGuard.xcodeproj -scheme GambleGuard \
     -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
   ```

## Ship it for free

1. **App ID.** developer.apple.com → Certificates, Identifiers & Profiles → Identifiers → **+** →
   App IDs → App → explicit bundle ID `org.gambleguard.app`. Under Capabilities tick
   **Family Controls** and **Network Extensions**. Save.
2. **Family Controls for distribution.** Development builds work as soon as the capability is on.
   To ship, fill in Apple's request form: <https://developer.apple.com/contact/request/family-controls-distribution>.
   Say what the app is: a self-exclusion tool that blocks gambling websites and apps on the person's
   own device, using individual (not child) authorization, with no data collection. Apple answers
   by email, usually within a couple of weeks; the App ID then shows *Family Controls (Distribution)*.
   Xcode's automatic signing picks up the new provisioning profile on the next build.
3. **Network Extensions** needs no request. The `dns-settings` value in
   `GambleGuard.entitlements` is the one Apple documents for "a system-wide DNS configuration".
4. **Archive.** Xcode → Product → Archive → Distribute App → App Store Connect → Upload. Export
   compliance is already answered in `Info.plist` (`ITSAppUsesNonExemptEncryption = false`; the
   app only uses Apple's TLS).
5. **TestFlight.** App Store Connect → the app → TestFlight. Internal testers (your team, up to 100)
   get the build with no review. External testers need a short beta review and a public link if you
   want one.
6. **App Store listing.** App Store Connect → My Apps → **+** → New App → iOS, the name
   (**Gamble Guard**, or another if that name is taken), bundle ID from step 1.
   - **Pricing:** Free. **In-App Purchases:** none.
   - **Category:** Health & Fitness (primary), Lifestyle (secondary).
   - **Age rating:** answer No to every gambling and contest question; the app contains none and
     blocks it. No unrestricted web access.
   - **App Privacy:** "Data Not Collected". `PrivacyInfo.xcprivacy` in the bundle says the same
     and declares the one required-reason API the app uses (UserDefaults, reason `CA92.1`, to keep
     the person's own app selection). A **privacy policy URL** is still mandatory for every app:
     a page in this repo saying "Gamble Guard collects no data" is enough.
   - **Screenshots:** the three-step screen on a 6.9" and a 6.5" iPhone, and an iPad if you keep
     iPad in `TARGETED_DEVICE_FAMILY`.
7. **App Review notes.** Reviewers ask the same things for every Screen Time app; put the answers
   in the notes box up front:
   - Why Family Controls: the person blocks gambling on their own device, through
     `FamilyControlsMember.individual`. No child accounts, no family sharing, no remote management.
   - What the DNS configuration is: Mullvad's public `family.dns.mullvad.net` resolver, a third
     party, named in the app. Nothing is sent to you.
   - What **Lock** does: exactly Screen Time's *Deleting Apps: Don't Allow*, applied with the
     person's Screen Time authorization, and described in the app before the tap.
   - A screen recording of all three steps on a device. Reviewers often cannot grant Screen Time
     access on their test hardware; the video gets you through.
   - That the app is free with no monetization and no account.

## What it locks, and how to make it hold

Written as instructions, because that is what they are.

- **Set the Screen Time passcode, typed by another person.** Settings → Screen Time → **Lock Screen
  Time Settings** (older iOS: *Use Screen Time Passcode*). Someone you trust types it twice and keeps
  it. If iOS offers Apple Account recovery for the passcode, that is their account, not yours. With
  the passcode set, the web filter, the app shields, Deleting Apps and the app's own Screen Time
  access can only be changed by whoever holds it.
- **Deleting Apps: Don't Allow** is what **Lock** sets. Delete any VPN app before you tap it, because
  afterwards nothing on the phone can be deleted. A VPN carries its own DNS and would route around
  step 2.
- **Keep the DNS configuration on.** iOS lets a person turn a DNS configuration off in Settings at any
  time; the Screen Time layer does not need it and stays either way. Turn it back on if it is off.
- **iCloud Private Relay off.** Settings → Apple Account → iCloud → Private Relay → Off, or Safari
  sends its DNS through Apple and skips the filter. Also Settings → Wi-Fi → your network → **Limit IP
  Address Tracking** off.
- **Pick the apps.** Step 1's *Choose gambling apps to block* opens Apple's picker; shielded apps show
  a Screen Time cover instead of opening. Add new ones whenever you install something.
- **Installing Apps: Don't Allow** is the stronger version, set by hand in Settings → Screen Time →
  Content & Privacy Restrictions → iTunes & App Store Purchases. It closes the route of installing a
  new VPN or casino app.

Two facts about the blocklist. Apple does not publish a cap on the number of domains a web filter
accepts; the app applies the bundled list plus the core brands, reads the policy back, and if it did
not round-trip applies the 155 core brands alone, so the block is never silently empty. The bundled
list is a slice of `lists/compact.txt` (every 9th line, 2,930 domains, every brand stem represented);
regenerate it with the command at the top of `Resources/blocklist.txt` when the weekly list changes,
and ship the update: the app re-applies the filter on every launch.

## Files

| Path | Purpose |
|---|---|
| `GambleGuard/project.yml` | XcodeGen spec |
| `GambleGuard/GambleGuard.xcodeproj` | Hand-written Xcode project (file-system-synchronized group, objectVersion 77) |
| `GambleGuard/GambleGuard/GambleGuardApp.swift` | App entry |
| `GambleGuard/GambleGuard/ContentView.swift` | The three steps |
| `GambleGuard/GambleGuard/GuardModel.swift` | Screen Time authorization, web filter, shields, lock; bundled and core blocklists |
| `GambleGuard/GambleGuard/DNSManager.swift` | Mullvad DNS-over-TLS via `NEDNSSettingsManager` |
| `GambleGuard/GambleGuard/Info.plist` | Bundle metadata, export-compliance answer |
| `GambleGuard/GambleGuard/GambleGuard.entitlements` | `com.apple.developer.family-controls`, `com.apple.developer.networking.networkextension: [dns-settings]` |
| `GambleGuard/GambleGuard/PrivacyInfo.xcprivacy` | No tracking, no data collected, UserDefaults reason `CA92.1` |
| `GambleGuard/GambleGuard/Resources/blocklist.txt` | 2,930 domains sampled from `lists/compact.txt` |
| `GambleGuard/GambleGuard/Assets.xcassets` | App icon slot (add the 1024 px PNG) |

## Support

Canada 1-866-531-2600 · US 1-800-522-4700 · UK 0808 8020 133 · <https://www.gamblingtherapy.org>
