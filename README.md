# gamble-guard

A free, self-healing gambling blocker for macOS. No account, no subscription, no kernel extension.

It blocks ~340,000 gambling domains system-wide — every browser and every app, not just the one
you remembered to configure — and puts the block back automatically if it is removed.

## Install

```sh
git clone https://github.com/prime-server/gamble-guard.git
cd gamble-guard
sudo ./install.sh
```

Or, in one line:

```sh
curl -fsSL https://raw.githubusercontent.com/prime-server/gamble-guard/main/install.sh | sudo bash
```

(Piping a script into a root shell is a habit worth distrusting in general. Read `install.sh`
first — it is about 50 lines.)

Verify it worked:

```sh
dscacheutil -q host -a name bet365.com     # should return 0.0.0.0, or nothing
```

## How it works

Three pieces, each covering a way the previous one gets defeated:

1. **A hosts-file block.** Gambling domains are pointed at `0.0.0.0` in `/etc/hosts`, so they fail
   to resolve for every application on the machine, not just inside one browser's settings.

2. **A launchd daemon that re-applies it every 120 seconds.** This is the part that matters. A
   blocklist you can delete in a weak moment is not a blocklist. Edit `/etc/hosts` and the entries
   are back before you finish typing a URL. The installed files also carry the system-immutable
   flag (`chflags schg`), so they resist casual deletion.

3. **Chrome's secure DNS is turned off by policy.** A browser doing DNS-over-HTTPS resolves names
   itself and never consults `/etc/hosts` — which silently defeats steps 1 and 2. Most homemade
   blockers miss this and quietly do nothing.

## Updating the list

Re-run `sudo ./install.sh`. It re-downloads the blocklist and reinstalls.

Use a different list with `LIST_URL=https://... sudo ./install.sh`. Any file of
`0.0.0.0 domain` lines works.

## Uninstall

```sh
sudo ./uninstall.sh
```

## Honest limitations

Worth stating plainly, because a tool you trust too much is worse than one you understand:

- **This is a speed bump, not a wall.** If you hold the admin password on the machine, you can
  remove this in under a minute. The goal is to convert a thirty-second impulse into a deliberate,
  multi-step, sober-minded act. That gap is usually the whole fight — but it is a gap, not a lock.
- **A VPN, a phone, or another computer routes around it entirely.** This protects one Mac.
- **Hosts entries have no wildcards.** A brand-new domain is unblocked until the upstream list
  catches up. Re-run the installer periodically.
- **iCloud Private Relay and non-Chrome browsers with DoH enabled can bypass the hosts file.**
  Turn Private Relay off in System Settings → Apple Account → iCloud.

If you want something genuinely harder to undo, have someone you trust set a **Screen Time
passcode** on the machine and not tell it to you. The strongest version of this tool is another
person.

## Credits

Blocklist from [The Blocklist Project](https://github.com/blocklistproject/Lists).

## Support

If gambling is costing you more than money: Canada 1-866-531-2600 · US 1-800-522-4700 ·
UK 0808 8020 133 · or <https://www.gamblingtherapy.org>.

## License

MIT — see [LICENSE](LICENSE).

## Tests

```sh
./tests/selftest.sh
```

No root required; it runs the rewrite logic against a temporary file.
