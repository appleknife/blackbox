# Blackbox

**UI preview, right now on your phone: <https://appleknife.github.io/blackbox/>**

An iPhone field deck for networks, radios and paperwork. Hold the phone like a
tool, not a screen.

Blackbox scans the subnet you are on, listens to devices announcing themselves,
maps Bluetooth gadgets, reads NFC tags, taps packets through a VPN tunnel, and
writes every observation into a timestamped case file you can export. The rest
of the deck is encoding, hashing and open-source lookup.

It is deliberately honest about the platform. iOS has no monitor mode and no
raw sockets, so nothing here pretends to be `aircrack-ng`. What remains is
still a surprising amount of useful work you can do from a pocket.

> Status: 0.1.0. Simulator builds are green in CI. Device behaviour is untested
> against real hardware and real entitlements; expect rough edges.

---

## What it does

| Code | Module | Working now |
| --- | --- | --- |
| NET-01 | LAN sweep | TCP connect probe across the /24, 14 ports, banner grab, live results |
| NET-02 | Announcements | Bonjour/mDNS browsing for 10 service types |
| NET-03 | Wi-Fi readout | SSID, BSSID, RSSI, local address, signal walk samples |
| NET-04 | Packet tap | VPN-based pcap capture with a TCP/UDP relay to keep browsing alive |
| RAD-01 | BLE explorer | Scan, link, enumerate GATT, read, write, subscribe, hex console |
| RAD-02 | NFC bench | NDEF dump, ISO 7816 APDU shell, ISO 7816 emulation |
| TRD-01 | Encode deck | Base64, hex, URL-safe work, rot13, XOR, JWT decode and sig strip |
| TRD-02 | Hash bench | Digest identification, MD5/SHA generation, 45-word crack list |
| OSN-01 | Open source | DoH lookups, RDAP, certificate-transparency pulls, header fetch |

Everything hits the case file. Export is JSON; captures export as pcap.

## What is deliberately missing

- Wi-Fi monitor mode, injection and deauthentication. iOS does not expose them.
- Half-open SYN scans. The sandbox only gives whole connections.
- Nearby SSID lists without the Hotspot Helper permit, which Apple can refuse.
- Payment-card cloning, USB host drivers, background scanning.
- The VPN badge during capture. It cannot be hidden.

The full exit list is in the app under **Scope**.

## Building

There is no checked-in `.xcodeproj`. It is generated so the project file never
turns into a merge conflict.

```sh
brew install xcodegen
xcodegen generate
open Blackbox.xcodeproj
```

Then pick a team under *Signing & Capabilities* and run on an iPhone. Simulator
builds need no signing:

```sh
xcodebuild -project Blackbox.xcodeproj -scheme Blackbox \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

CI does the same on every push (`.github/workflows/build.yml`).

### Entitlements, and why a free account will fight you

The target requests:

- Network Extension, `packet-tunnel-provider` — the packet tap
- Wi-Fi information — SSID/BSSID reads
- NFC tag reading and HCE — the tag bench and emulation
- App Group `group.com.appleknife.blackbox` — shared capture folder

A free Apple account cannot provision Network Extension or App Groups at all.
Use a paid team, or strip `Blackbox.entitlements` and `BlackboxTunnel` down to
what your account allows. HCE is separately managed by Apple; if signing fails
on `com.apple.developer.nfc.hce`, delete those two keys and the emulation panel
will report `unsupported`.

## Layout

```
Blackbox/            app target
  App/               entry point, tab shell
  Core/              theme, module catalog, case log, export
  Modules/           one engine + screen per feature
  Screens/           deck, case file, scope
BlackboxTunnel/      NEPacketTunnelProvider, pcap writer, relay
Shared/              pcap writer and IP parser used by both targets
Entitlements/        capability plists
preview/             browser stand-in for the deck
docs/                architecture and roadmap
```

## Rules

Poke your own gear. A hotel portal, a café printer and the neighbour's smart
bulb are fair game. Port sweeps are read-only; nothing here writes to a host.

## License

MIT.