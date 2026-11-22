import SwiftUI

struct BonjourView: View {
    @StateObject private var browser = AnnouncementBrowser()

    var body: some View {
        ScreenChrome(title: "Announcements", code: "NET-02") {
            Panel {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Devices shout their job into the room. A printer, a TV, a speaker, a laptop with file sharing. Blackbox writes down every shout.")
                        .font(.mono(11))
                        .foregroundStyle(Palette.dim)
                    HStack(spacing: 10) {
                        if browser.isBrowsing {
                            Button("Stop") { browser.stop() }
                                .buttonStyle(DeckButtonStyle(tint: Palette.blood))
                        } else {
                            Button {
                                Haptics.tap()
                                browser.start()
                            } label: {
                                Label("Listen", systemImage: "ear")
                            }
                            .buttonStyle(DeckButtonStyle(filled: true))
                        }
                        Text("\(browser.found.count) heard")
                            .font(.mono(11))
                            .foregroundStyle(Palette.dim)
                    }
                    if let message = browser.message {
                        Text(message).font(.mono(10)).foregroundStyle(Palette.blood)
                    }
                }
            }

            ForEach(browser.found) { item in
                Panel {
                    HStack(spacing: 10) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .foregroundStyle(Palette.acid)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.mono(13, weight: .bold))
                                .foregroundStyle(Palette.paper)
                                .textSelection(.enabled)
                            Text(item.type.replacingOccurrences(of: "._tcp", with: "").uppercased())
                                .font(.mono(9, weight: .bold))
                                .tracking(1.1)
                                .foregroundStyle(Palette.amber)

                        }
                        Spacer()
                    }
                }
            }
        }
        .onDisappear { browser.stop() }
    }
}