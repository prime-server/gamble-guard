# gamble-guard

A free, self-healing gambling blocker for macOS. No account, no subscription, no kernel extension.

It blocks ~340,000 gambling domains system-wide — every browser and every app, not just the one
you remembered to configure — and puts the block back automatically if it is removed.

## Install

One command. Nothing to clone, nothing to configure:

```sh
curl -fsSL https://raw.githubusercontent.com/prime-server/gamble-guard/main/install.sh | sudo bash
```

That is it — you are blocked in Chrome, Firefox and Safari when it finishes.

Prefer to read it first? `curl -fsSL .../install.sh | less`, or clone and run `sudo ./install.sh`.
Or open the folder in [Claude Code](https://claude.com/claude-code) and say *"install this"* — the
repo ships a `CLAUDE.md` telling the agent how, and telling it never to help you undo it.

### Make it stick

```sh
PARTNER=1 sudo ./install.sh                  # partner sets a passphrase you never see
sudo ./harden.sh partneradmin "Their Name"   # partner holds admin; you cannot sudo at all
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

3. **Chrome and Firefox have DNS-over-HTTPS forced off by policy.** A browser doing DoH resolves
   names itself and never consults `/etc/hosts` — which silently defeats steps 1 and 2. Firefox in
   particular ships `network.trr.mode` settings that can make it DoH-only, ignoring the hosts file
   completely. Both are locked off by enterprise policy, and re-applied on every run so a browser
   update cannot quietly restore them. Safari uses the system resolver, so it is covered by step 1.

   **All three browsers are covered: Chrome, Firefox, Safari.**

4. **Crypto-casino mirrors are pre-blocked.** `extra-domains.txt` carries ~2,200 brand-and-TLD
   permutations (rainbet, roobet, betway, rollbit, duelbits, gamdom, bc.game, stake and friends),
   because these brands reappear on a new TLD within days of being blocked and a hosts file has no
   wildcards.

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

- **With the admin password, you can remove this.** Plain install is a speed bump: two daemons
  that restore each other, files flagged immutable, and a 7-day cooling-off on `uninstall.sh`.
  That turns a thirty-second impulse into a week-long deliberate act, which is usually the whole
  fight — but anyone with `sudo` can shortcut it.
- **`harden.sh` is the only unremovable configuration.** Without admin rights there is no `sudo`,
  so there is nothing to shortcut. Everything else is friction, honestly described.
  Do not believe any blocker that claims otherwise while leaving you as an admin.
- **A VPN, a phone, or another computer routes around it entirely.** This protects one Mac.
- **Hosts entries have no wildcards.** A brand-new domain is unblocked until the upstream list
  catches up. Re-run the installer periodically.
- **iCloud Private Relay can bypass the hosts file in Safari.** Turn it off in
  System Settings → Apple Account → iCloud → Private Relay.
- **A paid blocker whose subscription lapses can be worse than nothing.** If it pins your browser
  to its own DNS resolver and that resolver stops filtering, the browser skips your hosts file and
  gets unfiltered answers. Check that any such tool is actually still blocking.

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
