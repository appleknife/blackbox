import SwiftUI

struct ScopeView: View {
    private let limits = [
        ("No monitor mode", "Wi-Fi is promiscuous-blind. Sweeps connect normally and infer."),
        ("No raw sockets", "Sockets open per connection, so no half-open SYN scan."),
        ("Tunnel shows a pill", "iOS paints a VPN badge while the packet tap runs."),
        ("Foreground only", "Sensors and radios sleep when the app leaves the screen."),
        ("No card cloning", "Only ISO 7816 emulation; payment cards stay opaque."),
        ("Hotspot Helper is a permit", "Listing nearby SSIDs needs an entitlement Apple can refuse.")
    ]

    var body: some View {
        ScreenChrome(title: "Scope", code: "SCOPE") {
            Panel {
                VStack(alignment: .leading, spacing: 8) {
                    Text("An iPhone is a radio with a camera, not a laptop with an antenna.")
                        .font(.mono(14, weight: .bold))
                        .foregroundStyle(Palette.paper)
                    Text("Blackbox sticks to what the sandbox actually permits and labels the rest instead of pretending.")
                        .font(.mono(11))
                        .foregroundStyle(Palette.dim)
                }
            }

            ForEach(limits, id: \.0) { limit in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "nosign")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.blood)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(limit.0)
                            .font(.mono(12, weight: .bold))
                            .foregroundStyle(Palette.paper)
                        Text(limit.1)
                            .font(.mono(10))
                            .foregroundStyle(Palette.dim)
                    }
                }
                .padding(.horizontal, 2)
            }

            Panel(tint: Palette.amber.opacity(0.5)) {
                VStack(alignment: .leading, spacing: 6) {
                    LabelCaps(text: "Rules", tint: Palette.amber)
                    Text("Poke your own gear. Captive portals, hotel Wi-Fi and a neighbour's printer are fair game. Port scans are read-only; nothing here writes to a host.")
                        .font(.mono(11))
                        .foregroundStyle(Palette.dim)
                }
            }

            Panel {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Blackbox 0.1.0")
                            .font(.mono(12, weight: .bold))
                            .foregroundStyle(Palette.paper)
                        Text("MIT licensed. Source and roadmap on GitHub.")
                            .font(.mono(10))
                            .foregroundStyle(Palette.dim)
                    }
                    Spacer()
                    Link(destination: URL(string: "https://github.com/appleknife/blackbox")!) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 18))
                            .foregroundStyle(Palette.acid)
                    }
                }
            }
        }
    }
}