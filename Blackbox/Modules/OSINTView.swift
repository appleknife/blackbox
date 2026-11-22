import UIKit
import SwiftUI

struct OSINTView: View {
    enum Operation: String, CaseIterable, Identifiable {
        case dns = "DNS"
        case rdap = "RDAP"
        case certs = "Certs"
        case headers = "Headers"

        var id: String { rawValue }
    }

    private let recordTypes = ["A", "AAAA", "MX", "TXT", "NS", "CNAME"]

    @State private var target = "appleknife.github.io"
    @State private var operation: Operation = .dns
    @State private var recordType = "A"
    @State private var result = ""
    @State private var busy = false

    var body: some View {
        ScreenChrome(title: "Open source", code: "OSN-01") {
            Panel {
                VStack(alignment: .leading, spacing: 10) {
                    LabelCaps(text: "target")
                    TextField("domain or URL", text: $target)
                        .font(.mono(12))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Palette.void))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.panelEdge))

                    Picker("Operation", selection: $operation) {
                        ForEach(Operation.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    if operation == .dns {
                        HStack(spacing: 6) {
                            ForEach(recordTypes, id: \.self) { type in
                                Button(type) { recordType = type }
                                    .buttonStyle(DeckButtonStyle(tint: recordType == type ? Palette.acid : Palette.dim))
                            }
                        }
                    }

                    Button {
                        fire()
                    } label: {
                        Label("Look up", systemImage: "arrow.up.right")
                    }
                    .buttonStyle(DeckButtonStyle(filled: true))
                    .disabled(busy || target.isEmpty)
                }
            }

            Text("DoH bypasses the local resolver, so a captive network cannot fake the answer. Anything past a DNS server still sees your traffic, though.")
                .font(.mono(10))
                .foregroundStyle(Palette.dim)

            Panel(tint: Palette.acid.opacity(0.5)) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        LabelCaps(text: "result")
                        Spacer()
                        Button("Copy") {
                            UIPasteboard.general.string = result
                            Haptics.tap()
                        }
                        .buttonStyle(DeckButtonStyle())
                    }
                    Text(busy ? "workingâ€¦" : (result.isEmpty ? "â€”" : result))
                        .font(.mono(11))
                        .foregroundStyle(result.isEmpty ? Palette.dim : Palette.paper)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func fire() {
        Haptics.tap()
        busy = true
        result = ""
        let domain = target
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .split(separator: "/").first.map(String.init) ?? ""

        Task {
            do {
                let text: String
                switch operation {
                case .dns: text = try await Recon.dns(domain, type: recordType)
                case .rdap: text = try await Recon.rdap(domain)
                case .certs: text = try await Recon.certificates(domain)
                case .headers: text = try await Recon.headers(target)
                }
                result = text
                CaseLog.shared.finding("OSN-01", "\(operation.rawValue) \(domain)", fields: ["bytes": "\(text.count)"])
            } catch {
                result = error.localizedDescription
                Haptics.miss()
            }
            busy = false
        }
    }
}