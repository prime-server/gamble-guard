# Whole-home blocking through your router

Neither Gamban nor BetBlocker can do this: set your router's DNS to Mullvad's family resolver and
**every device on your Wi-Fi** — phones, TVs, consoles, a friend's laptop — refuses to resolve
gambling domains. No software on any of them.

1. Log in to your router (usually `192.168.0.1` or `192.168.1.1`; the address and password are on
   its label). Find *DNS* under WAN / Internet / DHCP settings.
2. Set primary DNS to `194.242.2.6` and, if there is an IPv6 field, `2a07:e340::6`.
   Leave the secondary empty, or use the same address — a plain secondary resolver becomes a
   bypass the moment the primary is slow.
3. Save and reboot the router. On any device: `bet365.com` should fail to load.

**Make it stick.** Change the router's admin password and have your accountability partner keep it.
That is the only part that makes this a lock rather than a setting.

**Honest limits.** A device with its own DNS hard-set (or a browser with its own DNS-over-HTTPS)
ignores the router — that is exactly what the desktop installer fixes on your computers. Mobile
data, a VPN or a phone hotspot route around the router entirely.
