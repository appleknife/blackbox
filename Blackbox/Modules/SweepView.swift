import UIKit
import SwiftUI

struct SweepView: View {
    @StateObject private var sweeper = HostSweeper()

    var body: some View {
        ScreenChrome(title: "LAN sweep", code: "NET-01") {
            Panel {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        LabelCaps(text: "target")
                        Spacer()
                        Text(sweeper.address.map { "\($0)/24" } ?? "not joined")
                            .font(.mono(12, weight: .bold))
                            .foregroundStyle(sweeper.address == nil ? Palette.blood : Palette.acid)
                    }
                    ProgressView(value: sweeper.progress)
                        .tint(Palette.acid)
                        .background(Palette.panelEdge)
                    HStack(spacing: 10) {
                        if sweeper.isRunning {
                            Button("Abort") { sweeper.stop() }
                                .buttonStyle(DeckButtonStyle(tint: Palette.blood))
                        } else {
                            Button {
                                Haptics.tap()
                                Task { await sweeper.start() }
                            } label: {
                                Label("Sweep", systemImage: "play.fill")
                            }
                            .buttonStyle(DeckButtonStyle(filled: true))
                        }
                        Text("\(sweeper.hits.count) open")
                            .font(.mono(11))
                            .foregroundStyle(Palette.dim)
                        Spacer()
                    }
                    if let message = sweeper.message {
                        Text(message)
                            .font(.mono(10))
                            .foregroundStyle(Palette.amber)
                    }
                }
            }

            Text("TCP connect probe, 14 ports, 254 addresses. Banner grabbed where the service volunteers one. Read-only.")
                .font(.mono(10))
                .foregroundStyle(Palette.dim)

            ForEach(sweeper.hits) { hit in
                Panel(tint: Palette.acid.opacity(0.4)) {
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(hit.port)")
                            .font(.mono(16, weight: .heavy))
                            .foregroundStyle(Palette.acid)
                            .frame(width: 52, alignment: .leading)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(hit.host)
                                .font(.mono(13, weight: .bold))
                                .foregroundStyle(Palette.paper)
                                .textSelection(.enabled)
                            Text(hit.service.uppercased())
                                .font(.mono(9, weight: .bold))
                                .tracking(1.2)
                                .foregroundStyle(Palette.amber)
                            if let banner = hit.banner {
                                Text(banner)
                                    .font(.mono(10))
                                    .foregroundStyle(Palette.dim)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                        Button {
                            UIPasteboard.general.string = "\(hit.host):\(hit.port)"
                            Haptics.tap()
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .foregroundStyle(Palette.dim)
                        }
                    }
                }
            }
        }
        .onDisappear { sweeper.stop() }
    }
}