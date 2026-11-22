import SwiftUI

struct BLEView: View {
    @StateObject private var explorer = BLEExplorer()
    @State private var writeText = "01"
    @State private var selected: BLEField?

    var body: some View {
        ScreenChrome(title: "BLE explorer", code: "RAD-01") {
            Panel {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        StatusPill(text: explorer.state, tint: explorer.state == "connected" ? Palette.acid : Palette.amber)
                        Spacer()
                        Text("\(explorer.devices.count) seen")
                            .font(.mono(10))
                            .foregroundStyle(Palette.dim)
                    }
                    HStack(spacing: 10) {
                        Button {
                            Haptics.tap()
                            explorer.begin()
                        } label: {
                            Label("Scan", systemImage: "magnifyingglass")
                        }
                        .buttonStyle(DeckButtonStyle(filled: true))
                        Button("Stop") { explorer.stop() }
                            .buttonStyle(DeckButtonStyle())
                        if explorer.connected != nil {
                            Button("Drop") { explorer.disconnect() }
                                .buttonStyle(DeckButtonStyle(tint: Palette.blood))
                        }
                    }
                    if let message = explorer.message {
                        Text(message).font(.mono(10)).foregroundStyle(Palette.blood)
                    }
                }
            }

            if explorer.connected != nil {
                Panel(tint: Palette.amber.opacity(0.5)) {
                    VStack(alignment: .leading, spacing: 8) {
                        LabelCaps(text: "gatt table", tint: Palette.amber)
                        if explorer.fields.isEmpty {
                            Text("Reading services…")
                                .font(.mono(10))
                                .foregroundStyle(Palette.dim)
                        }
                        ForEach(explorer.fields) { field in
                            HStack(spacing: 8) {
                                Text(field.uuid)
                                    .font(.mono(10))
                                    .foregroundStyle(selected == field ? Palette.acid : Palette.paper)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .onTapGesture { selected = field }
                                Spacer()
                                Text(field.properties)
                                    .font(.mono(8, weight: .bold))
                                    .foregroundStyle(Palette.dim)
                                if field.properties.contains("read") {
                                    Button("R") { explorer.read(field) }
                                        .buttonStyle(DeckButtonStyle())
                                }
                                if field.properties.contains("notify") {
                                    Button("N") { explorer.toggleNotify(field) }
                                        .buttonStyle(DeckButtonStyle(tint: Palette.amber))
                                }
                            }
                        }
                    }
                }

                Panel {
                    VStack(alignment: .leading, spacing: 8) {
                        LabelCaps(text: "write (utf-8)")
                        HStack {
                            TextField("payload", text: $writeText)
                                .font(.mono(12))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Palette.void))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.panelEdge))
                            Button("Send") {
                                if let selected { explorer.write(writeText, to: selected) }
                                else { explorer.message = "Tap a characteristic first." }
                            }
                            .buttonStyle(DeckButtonStyle(tint: Palette.acid))
                        }
                    }
                }
            }

            if !explorer.output.isEmpty {
                Panel(tint: Palette.acid.opacity(0.5)) {
                    Text(explorer.output)
                        .font(.mono(11))
                        .foregroundStyle(Palette.acid)
                        .textSelection(.enabled)
                }
            }

            ForEach(explorer.devices) { device in
                Button {
                    Haptics.tap()
                    explorer.connect(device)
                } label: {
                    Panel {
                        HStack {
                            Image(systemName: "wave.3.right")
                                .foregroundStyle(Palette.acid)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.name)
                                    .font(.mono(12, weight: .bold))
                                    .foregroundStyle(Palette.paper)
                                Text(device.id.uuidString.prefix(8))
                                    .font(.mono(9))
                                    .foregroundStyle(Palette.dim)
                            }
                            Spacer()
                            Text("\(device.rssi)")
                                .font(.mono(11, weight: .bold))
                                .foregroundStyle(device.rssi > -70 ? Palette.acid : Palette.dim)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            Text("Scanning needs the app in front. Values show as hex. Unnamed entries are still worth a look; trackers hide their names.")
                .font(.mono(10))
                .foregroundStyle(Palette.dim)
        }
    }
}