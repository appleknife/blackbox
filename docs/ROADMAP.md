# Roadmap

## Now (0.1)

Shipped skeleton: deck, case file, LAN sweep, Bonjour, Wi-Fi readout, BLE
explorer, NFC bench, encode deck, hash bench, open-source lookups, packet tap.

## Next

- Icon set, launch screen, and a proper empty-state pass.
- App Intents so every module has a Shortcut action.
- Sweep: editable port list, subnet range, saved targets, CSV export.
- Signal heatmap from walk samples using CoreLocation.
- BLE beacons: iBeacon clone and broadcast, RSSI proximity sort.
- NFC: TLV parser for NDEF, MIFARE key dictionary, SELECT-aware emulation.
- TLS grading: protocol versions, cipher order, certificate chain, expiry.
- Case attachments: screenshots and captures referenced from case entries.

## Later

- Hotspot Helper application and a neighbourhood SSID list, if Apple grants it.
- Live Activities HUD for long sweeps, Watch remote.
- HTTPS inspection proxy with an in-app CA and HAR export.
- IPA and Mach-O inspection via the share sheet.
- RoomPlan floorplans and ARKit mesh capture.
- Secure Enclave signing keys for SSH and file signatures.
- Shortcut and geofence triggers for unattended passes.

## Not planned

Monitor mode, injection, deauth, cellular, payment-card cloning, USB SDR
support. The platform does not hand any of those to a sandboxed app.
