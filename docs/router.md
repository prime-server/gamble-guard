# Whole-home blocking through your router

Neither Gamban nor BetBlocker can do this: set your router's DNS to Mullvad's family resolver and
**every device on your Wi-Fi** — phones, TVs, consoles, a friend's laptop — refuses to resolve
gambling domains. No software on any of them.

1. Log in to your router (the address and password are on
   its label). Find *DNS* under WAN / Internet / DHCP settings.
2. Set primary DNS to `194.242.2.6` and, if there is an IPv6 field, `2a07:e340::6`.
   Leave the secondary empty, or use the same address — a plain secondary resolver becomes a
   bypass the moment the primary is slow.
3. Save and reboot the router. On any device: `bet365.com` should fail to load, and
   <https://prime-server.github.io/gamble-guard/> confirms it live.

**Make it stick.** Change the router's admin password and have your accountability partner keep it.

**Cover devices that leave the house or set their own DNS.** Run the desktop installer on each
computer — it pins the system resolver and the browsers, which would otherwise do their own
DNS-over-HTTPS — and set up phones from [`../mobile/QUICKSTART.md`](../mobile/QUICKSTART.md) so they
stay covered on mobile data.
