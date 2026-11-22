import NetworkExtension
import SwiftUI

struct WiFiReading {
    var ssid: String = "—"
    var bssid: String = "—"
    var strength: Double = 0
    var secure: Bool = false
    var address: String?
}

@MainActor
final class WiFiProbe: ObservableObject {
    @Published var reading = WiFiReading()
    @Published var note: String?
    @Published private(set) var walk: [(Date, Double)] = []

    func refresh() {
        NEHotspotNetwork.fetchCurrent { [weak self] network in
            Task { @MainActor in
                guard let self else { return }
                guard let network else {
                    self.note = "No Wi-Fi details. Needs the Wi-Fi Info entitlement and a joined network."
                    self.reading.address = HostSweeper.wifiAddress()
                    return
                }
                self.note = nil
                self.reading = WiFiReading(
                    ssid: network.ssid,
                    bssid: network.bssid,
                    strength: network.signalStrength,
                    secure: network.isSecure,
                    address: HostSweeper.wifiAddress()
                )
                CaseLog.shared.record("NET-03", "Readout \(network.ssid)", fields: [
                    "bssid": network.bssid,
                    "rssi": String(format: "%.2f", network.signalStrength)
                ])
            }
        }
    }

    func logSignal() {
        walk.append((Date(), reading.strength))
        Haptics.tap()
        CaseLog.shared.finding("NET-03", "Signal sample", fields: [
            "rssi": String(format: "%.2f", reading.strength),
            "bssid": reading.bssid
        ])
    }

    var bars: Int {
        let level = reading.strength
        if level >= 0.75 { return 4 }
        if level >= 0.5 { return 3 }
        if level >= 0.25 { return 2 }
        if level > 0 { return 1 }
        return 0
    }
}

struct WiFiView: View {
    @StateObject private var probe = WiFiProbe()

    var body: some View {
        ScreenChrome(title: "Wi-Fi readout", code: "NET-03") {
            Panel {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            LabelCaps(text: "network")
                            Text(probe.reading.ssid)
                                .font(.mono(20, weight: .heavy))
                                .foregroundStyle(Palette.paper)
                                .textSelection(.enabled)
                        }
                        Spacer()
                        HStack(spacing: 3) {
                            ForEach(0..<4) { index in
                                Rectangle()
                                    .fill(index < probe.bars ? Palette.acid : Palette.panelEdge)
                                    .frame(width: 5, height: CGFloat(8 + index * 5))
                            }
                        }
                    }

                    gridRow("bssid", probe.reading.bssid)
                    gridRow("local", probe.reading.address ?? "—")
                    gridRow("security", probe.reading.secure ? "WPA / secured" : "open")
                    gridRow("rssi", String(format: "%.2f", probe.reading.strength))

                    HStack(spacing: 10) {
                        Button("Refresh") { probe.refresh() }
                            .buttonStyle(DeckButtonStyle())
                        Button("Log sample") { probe.logSignal() }
                            .buttonStyle(DeckButtonStyle(tint: Palette.amber))
                    }

                    if let note = probe.note {
                        Text(note).font(.mono(10)).foregroundStyle(Palette.blood)
                    }
                }
            }

            Panel {
                VStack(alignment: .leading, spacing: 6) {
                    LabelCaps(text: "walk")
                    if probe.walk.isEmpty {
                        Text("No samples yet. Walk the room and tap log.")
                            .font(.mono(10))
                            .foregroundStyle(Palette.dim)
                    } else {
                        ForEach(Array(probe.walk.enumerated()), id: \.offset) { _, sample in
                            HStack {
                                Text(sample.0.formatted(date: .omitted, time: .standard))
                                    .font(.mono(10))
                                    .foregroundStyle(Palette.dim)
                                Spacer()
                                Text(String(format: "%.2f", sample.1))
                                    .font(.mono(11, weight: .bold))
                                    .foregroundStyle(sample.1 > 0.4 ? Palette.acid : Palette.blood)
                            }
                        }
                    }
                }
            }

            Text("BSSID and signal come from NEHotspotNetwork. iOS hides other SSIDs until the Hotspot Helper entitlement is granted.")
                .font(.mono(10))
                .foregroundStyle(Palette.dim)
        }
        .onAppear { probe.refresh() }
    }

    private func gridRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            LabelCaps(text: key)
                .frame(width: 78, alignment: .leading)
            Text(value)
                .font(.mono(12))
                .foregroundStyle(Palette.paper)
                .textSelection(.enabled)
            Spacer()
        }
    }
}