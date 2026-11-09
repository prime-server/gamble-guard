# gamble-guard for iPhone, iPad and Android

On phones, gamble-guard is **encrypted DNS pointed at a filtering resolver.** Every app and browser
on the device asks this resolver for addresses; gambling domains get no answer and the page fails to
load.

The resolver is [Mullvad's](https://mullvad.net/en/help/dns-over-https-and-dns-over-tls) free
public DNS with the gambling filter enabled. No account, no app, no subscription, no logging of
your lookups (per their policy — read it yourself).

| | |
|---|---|
| DoT hostname | `family.dns.mullvad.net` (port 853) |
| DoH URL | `https://family.dns.mullvad.net/dns-query` |
| IPv4 / IPv6 | `194.242.2.6` / `2a07:e340::6` |

Spot-checked: bet365, stake, roobet, rainbet, lotoquebec, betway, draftkings, rollbit,
duelbits, bc.game all fail; github and google resolve normally. The filter is Mullvad's; on iOS,
add any site it misses to Screen Time's **Never Allow** list (below).

## iPhone and iPad

**Install**

1. Get `gamble-guard.mobileconfig` onto the device: AirDrop it, email it to yourself, or open
   it in Safari from this repo (tap the file, then **Download**).
2. iOS says *Profile Downloaded*. Open **Settings**, tap **Profile Downloaded** near the top
   (or find it under **General → VPN & Device Management**).
3. Tap **Install**, enter the device passcode, confirm.

If a network blocks DNS-over-TLS (some corporate or hotel Wi-Fi does), install
`gamble-guard-doh.mobileconfig` instead, which uses DNS-over-HTTPS on port 443.

**Lock it with Screen Time**, with the passcode held by someone else. The web-content block stays in
force whatever happens to the DNS profile, and only the passcode holder can change it:

1. Settings → **Screen Time** → turn on **Content & Privacy Restrictions**.
2. **Content Restrictions → Web Content → Limit Adult Websites.** Under **Never Allow**, add
   the gambling sites you actually use (bet365.com, stake.com, and so on). This is a browser
   block that holds even if the DNS profile is removed.
3. Back in Content & Privacy Restrictions, set **Passcode Changes** and **Account Changes** to
   **Don't Allow**, so the device passcode and Apple ID cannot be used to reset things.
4. Set a **Screen Time passcode**. Have a partner, friend or family member type it and not tell
   you. If iOS offers to link an Apple ID for passcode recovery, that should be *their* Apple
   ID, not yours.
5. Settings → **[your name] → iCloud → Private Relay** → **Off**, so Safari goes through the
   filter like every other app. Also set Settings → Wi-Fi → your network → **Limit IP Address
   Tracking** to off.

**To make the profile itself undeletable:** a partner's Mac with Apple Configurator can *supervise*
the iPhone (this erases the device during setup). On a supervised device `PayloadRemovalDisallowed`
is enforced and the profile cannot be removed without the supervising Mac.

**Verify:** open <https://prime-server.github.io/gamble-guard/> — it checks live that gambling sites
no longer load. `bet365.com` should fail; `github.com` should work.

## Android

Menu names vary by manufacturer and version; search Settings for "Private DNS" if these do not
match.

**Install**

1. Settings → **Network & internet** → **Private DNS**.
2. Choose **Private DNS provider hostname**, enter `family.dns.mullvad.net`, tap **Save**.

**Lock it.** Have a partner hold the setting, strongest first:

- **A work profile or a device enrolled in a management tool the partner controls** locks
  Private DNS outright.
- **Family Link.** The partner sets up Family Link with themselves as the parent and you as the
  supervised account, then restricts settings changes and app installs. Google aimed this at
  children; it works for adults who both consent — check the current account-type requirements,
  which Google changes.
- **Digital Wellbeing / Focus mode, or an app locker**, with a PIN held by the partner.

**Turn these off too**, so every app goes through Private DNS:

- **Chrome → Settings → Privacy and security → Use secure DNS.** Set it to use your current
  service provider (the system DNS), not a custom provider.
- **Firefox**: disable DNS over HTTPS in its settings, so it uses the system resolver.
- **VPN apps** carry their own DNS. Uninstall them, and have a partner lock app installs.
- Some browsers (Brave, Opera, Samsung Internet) have their own private-DNS or VPN features.
  Turn each one off.

**Verify:** open <https://prime-server.github.io/gamble-guard/> — it checks live that gambling sites
no longer load. `bet365.com` should fail; `github.com` should work.

## Support

Canada 1-866-531-2600 · US 1-800-522-4700 · UK 0808 8020 133 · <https://www.gamblingtherapy.org>
