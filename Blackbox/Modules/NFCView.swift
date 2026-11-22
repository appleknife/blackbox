import SwiftUI

struct NFCView: View {
    @StateObject private var bench = NFCBench()

    var body: some View {
        ScreenChrome(title: "NFC bench", code: "RAD-02") {
            Panel {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        StatusPill(text: bench.status, tint: Palette.acid)
                        Spacer()
                    }
                    HStack(spacing: 10) {
                        Button {
                            Haptics.tap()
                            bench.readNDEF()
                        } label: {
                            Label("NDEF", systemImage: "doc.text.magnifyingglass")
                        }
                        .buttonStyle(DeckButtonStyle(filled: true))
                        Button("ISO 7816") { bench.openTagSession() }
                            .buttonStyle(DeckButtonStyle())
                    }
                    if let message = bench.message {
                        Text(message).font(.mono(10)).foregroundStyle(Palette.blood)
                    }
                }
            }

            if !bench.tagInfo.isEmpty {
                Panel(tint: Palette.amber.opacity(0.5)) {
                    VStack(alignment: .leading, spacing: 4) {
                        LabelCaps(text: "tag", tint: Palette.amber)
                        ForEach(bench.tagInfo, id: \.self) { line in
                            Text(line)
                                .font(.mono(11))
                                .foregroundStyle(Palette.paper)
                                .textSelection(.enabled)
                        }
                    }
                }

                Panel {
                    VStack(alignment: .leading, spacing: 8) {
                        LabelCaps(text: "apdu")
                        TextField("00A40400…", text: $bench.apdu)
                            .font(.mono(12))
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Palette.void))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.panelEdge))
                        HStack {
                            Button("Send") { bench.sendAPDU() }
                                .buttonStyle(DeckButtonStyle(filled: true))
                            Spacer()
                            if !bench.response.isEmpty {
                                Text(bench.response)
                                    .font(.mono(10))
                                    .foregroundStyle(Palette.acid)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
            }

            ForEach(bench.records) { record in
                Panel {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.type.uppercased())
                            .font(.mono(9, weight: .bold))
                            .tracking(1.1)
                            .foregroundStyle(Palette.amber)
                        if let text = record.text {
                            Text(text)
                                .font(.mono(12))
                                .foregroundStyle(Palette.paper)
                                .textSelection(.enabled)
                        }
                        Text(record.payloadHex)
                            .font(.mono(9))
                            .foregroundStyle(Palette.dim)
                            .textSelection(.enabled)
                    }
                }
            }

            if #available(iOS 17.4, *) {
                EmulationPanel()
            }

            Text("Reading needs the app in front and a tap on the system sheet. NDEF is stickers and labels; ISO 7816 is badges, SIMs and transit chips.")
                .font(.mono(10))
                .foregroundStyle(Palette.dim)
        }
    }
}