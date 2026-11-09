# gamble-guard for iPhone, iPad and Android

Phones cannot run the daemon or edit the hosts file that the macOS version relies on, so the
mobile version uses a different mechanism: **encrypted DNS pointed at a filtering resolver.**

The resolver is [Mullvad's](https://mullvad.net/en/help/dns-over-https-and-dns-over-tls) free
public DNS with the gambling filter enabled. No account, no app, no subscription, no logging of
your lookups (per their policy — read it yourself). Every app and browser on the device asks
this resolver for addresses; gambling domains get no answer and the page fails to load.

| | |
|---|---|
| DoT hostname | `family.dns.mullvad.net` (port 853) |
| DoH URL | `https://family.dns.mullvad.net/dns-query` |
| IPv4 / IPv6 | `194.242.2.6` / `2a07:e340::6` |

Spot-checked: bet365, stake, roobet, rainbet, lotoquebec, betway, draftkings, rollbit,
duelbits, bc.game all fail; github and google resolve normally. The filter is Mullvad's, not
ours, so coverage follows their list and we cannot add domains to it.

## iPhone and iPad

**Install**

1. Get `gamble-guard.mobileconfig` onto the device: AirDrop it, email it to yourself, or open
   it in Safari from this repo (tap the file, then **Download**).
2. iOS says *Profile Downloaded*. Open **Settings**, tap **Profile Downloaded** near the top
   (or find it under **General → VPN & Device Management**).
3. Tap **Install**, enter the device passcode, confirm.

If a network blocks DNS-over-TLS (some corporate or hotel Wi-Fi does), remove it and install
`gamble-guard-doh.mobileconfig` instead, which uses DNS-over-HTTPS on port 443.

**Verify:** open Safari and go to `bet365.com`. It should fail to load. `github.com` should work.

**The truth about removal.** The profile sets `PayloadRemovalDisallowed`, but iOS only honours
that on *supervised* devices. On a normal iPhone you can go to Settings → VPN & Device Management
and delete it in about ten seconds. The profile alone is a speed bump.

**The real lock is Screen Time**, with the passcode held by someone else:

1. Settings → **Screen Time** → turn on **Content & Privacy Restrictions**.
2. **Content Restrictions → Web Content → Limit Adult Websites.** Under **Never Allow**, add
   the gambling sites you actually use (bet365.com, stake.com, and so on). This is a browser
   block that works even if the DNS profile is removed.
3. Back in Content & Privacy Restrictions, set **Passcode Changes** and **Account Changes** to
   **Don't Allow**, so the device passcode and Apple ID cannot be used to reset things.
4. Set a **Screen Time passcode**. Have a partner, friend or family member type it and not tell
   you. If iOS offers to link an Apple ID for passcode recovery, that should be *their* Apple
   ID, not yours.
5. Settings → **[your name] → iCloud → Private Relay** → **Off**. Private Relay sends Safari's
   DNS through Apple, bypassing the filter. Also check Settings → Wi-Fi → your network → that
   **Limit IP Address Tracking** has not re-routed DNS; turn it off if gambling sites load.

Screen Time does not stop you deleting the DNS profile, but with the web-content block and
the passcode in someone else's head, deleting the profile gets you nothing.

**If a partner is willing to do more:** a Mac with Apple Configurator can *supervise* the
iPhone (this erases the device during setup). On a supervised device `PayloadRemovalDisallowed`
is enforced and the profile cannot be removed without the supervising Mac. That is the
strongest configuration iOS offers without an MDM.

## Android

Menu names vary by manufacturer and version; search Settings for "Private DNS" if these do not
match.

**Install**

1. Settings → **Network & internet** → **Private DNS**.
2. Choose **Private DNS provider hostname**, enter `family.dns.mullvad.net`, tap **Save**.

**Verify:** open Chrome and go to `bet365.com`. It should fail. `github.com` should work.

**The truth about removal.** You can change this setting back in five seconds. Nothing stops
you unless the device is managed by someone else. Options, strongest first:

- **A work profile or a device enrolled in a management tool controlled by another person** can
  lock Private DNS. Most people do not have this.
- **Family Link.** If a partner sets up Family Link with themselves as the parent and you as the
  supervised account, they can restrict settings changes and app installs. Google aimed this at
  children; it works for adults who both consent, but check the current account-type
  requirements, which Google changes.
- **Digital Wellbeing / Focus mode, or a third-party app locker**, with a PIN held by a partner.
  Weaker; a determined person can uninstall them.

**Things that bypass Private DNS**, which you should turn off:

- **Chrome → Settings → Privacy and security → Use secure DNS.** Set it to use your current
  service provider (the system DNS), not a custom provider.
- **Firefox**: disable DNS over HTTPS in its settings, or it resolves names itself.
- **VPN apps** carry their own DNS. A VPN defeats this entirely. Uninstall them, or have a
  partner lock app installs.
- Some browsers (Brave, Opera, Samsung Internet) have their own private-DNS or VPN features.
  Check each one.

## What this does and does not do

Same honesty as the [main README](../README.md):

- **It is a speed bump unless another person holds the lock.** DNS filtering turns a
  thirty-second impulse into a deliberate act of undoing settings. That is often the whole
  fight. But on an unsupervised phone, you can undo it.
- **A VPN, a different phone, or a laptop routes around it entirely.** This protects one device.
- **We do not control the list.** Mullvad does. If a site is missing, it stays missing until
  they add it. Add it to Screen Time's **Never Allow** list on iOS instead.
- **A paid blocker with a lapsed subscription can be worse than nothing.** Same warning as
  the main README: check that whatever you rely on is actually still blocking.
- **It only works while Mullvad keeps running the service.** They have run it free for years;
  that is not a guarantee.

The strongest version of this tool is another person.

## Support

If gambling is costing you more than money: Canada 1-866-531-2600 · US 1-800-522-4700 ·
UK 0808 8020 133 · or <https://www.gamblingtherapy.org>.
