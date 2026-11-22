import SwiftUI

struct CaptureView: View {
    @StateObject private var tunnel = TunnelManager()
    @State private var sharing: CaptureFile?

    var body: some View {
        ScreenChrome(title: "Packet tap", code: "NET-04") {
            Panel(tint: tunnel.isRunning ? Palette.acid.opacity(0.6) : Palette.panelEdge) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        StatusPill(text: tunnel.statusText, tint: tunnel.isRunning ? Palette.acid : Palette.dim)
                        Spacer()
                        Image(systemName: "square.stack.3d.up")
                            .foregroundStyle(Palette.dim)
                    }
                    Text("Traffic is read from a packet tunnel, written to a pcap and relayed onward. DNS, TCP and UDP are forwarded; the rest is captured and dropped.")
                        .font(.mono(11))
                        .foregroundStyle(Palette.dim)
                    Button {
                        Haptics.tap()
                        tunnel.toggle()
                    } label: {
                        Label(tunnel.isRunning ? "Stop tap" : "Start tap", systemImage: tunnel.isRunning ? "stop.fill" : "record.circle")
                    }
                    .buttonStyle(DeckButtonStyle(tint: tunnel.isRunning ? Palette.blood : Palette.acid, filled: !tunnel.isRunning))
                    if let message = tunnel.message {
                        Text(message).font(.mono(10)).foregroundStyle(Palette.blood)
                    }
                }
            }

            HStack {
                LabelCaps(text: "captures")
                Spacer()
                Button("Refresh") { tunnel.refreshFiles() }
                    .buttonStyle(DeckButtonStyle())
            }

            if tunnel.files.isEmpty {
                Text("No captures yet. Start the tap, browse for a minute, stop it, then export the file to Wireshark.")
                    .font(.mono(10))
                    .foregroundStyle(Palette.dim)
            }

            ForEach(tunnel.files) { file in
                Panel {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.url.lastPathComponent)
                                    .font(.mono(11, weight: .bold))
                                    .foregroundStyle(Palette.paper)
                                Text("\(file.size / 1024) KB · \(file.date.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.mono(9))
                                    .foregroundStyle(Palette.dim)
                            }
                            Spacer()
                            Button {
                                sharing = file
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(Palette.acid)
                            }
                            Button {
                                tunnel.delete(file)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(Palette.blood)
                            }
                        }
                    }
                }
            }

            Panel(tint: Palette.amber.opacity(0.5)) {
                VStack(alignment: .leading, spacing: 5) {
                    LabelCaps(text: "tell", tint: Palette.amber)
                    Text("iOS paints a VPN badge while this runs. The relay is young; if a site stalls, stop the tap and reload. Captures are LINKTYPE_RAW pcaps.")
                        .font(.mono(10))
                        .foregroundStyle(Palette.dim)
                }
            }
        }
        .task {
            await tunnel.prepare()
            tunnel.beginPolling()
        }
        .onDisappear { tunnel.stopPolling() }
        .sheet(item: $sharing) { file in
            ShareSheet(items: [file.url])
        }
    }
}
