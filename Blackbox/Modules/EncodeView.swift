import UIKit
import SwiftUI

enum Transforms {
    static func base64(_ text: String) -> String? { Data(text.utf8).base64EncodedString() }

    static func unbase64(_ text: String) -> String? {
        guard let data = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        return String(data: data, encoding: .utf8) ?? data.map { String(format: "%02x", $0) }.joined()
    }

    static func hex(_ text: String) -> String { Data(text.utf8).map { String(format: "%02x", $0) }.joined() }

    static func unhex(_ text: String) -> String? {
        let clean = text.replacingOccurrences(of: " ", with: "")
        guard clean.count % 2 == 0 else { return nil }
        var bytes: [UInt8] = []
        var index = clean.startIndex
        while index < clean.endIndex {
            let next = clean.index(index, offsetBy: 2)
            guard let byte = UInt8(clean[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        return String(data: Data(bytes), encoding: .utf8) ?? Data(bytes).map { String(format: "%02x", $0) }.joined()
    }

    static func rot13(_ text: String) -> String {
        String(text.unicodeScalars.map { scalar -> Character in
            switch scalar.value {
            case 65...90: return Character(UnicodeScalar((scalar.value - 65 + 13) % 26 + 65)!)
            case 97...122: return Character(UnicodeScalar((scalar.value - 97 + 13) % 26 + 97)!)
            default: return Character(scalar)
            }
        })
    }

    static func xor(_ text: String, key: String) -> String {
        guard !key.isEmpty else { return text }
        let keyBytes = Array(key.utf8)
        let out = Array(text.utf8).enumerated().map { $0.element ^ keyBytes[$0.offset % keyBytes.count] }
        return String(data: Data(out), encoding: .utf8) ?? Data(out).map { String(format: "%02x", $0) }.joined()
    }

    static func decodeJWT(_ token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var report = ""
        for (label, part) in zip(["HEADER", "PAYLOAD"], parts.prefix(2)) {
            guard let data = base64url(String(part)),
                  let object = try? JSONSerialization.jsonObject(with: data),
                  let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
                  let text = String(data: pretty, encoding: .utf8) else { continue }
            report += "\(label)\n\(text)\n\n"
        }
        if parts.count == 3 {
            let signature = String(parts[2])
            report += signature.isEmpty
                ? "SIGNATURE (none)"
                : "SIGNATURE \(signature.count) b64url chars - verify separately"
        }
        return report.isEmpty ? nil : report.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func stripJWT(_ token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        return "\(parts[0]).\(parts[1])."
    }

    static func base64url(_ text: String) -> Data? {
        var clean = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        clean += String(repeating: "=", count: (4 - clean.count % 4) % 4)
        return Data(base64Encoded: clean)
    }
}

struct EncodeView: View {
    @State private var input = "user=analyst&role=guest"
    @State private var key = "blackbox"
    @State private var output = ""

    var body: some View {
        ScreenChrome(title: "Encode deck", code: "TRD-01") {
            Panel {
                VStack(alignment: .leading, spacing: 8) {
                    LabelCaps(text: "input")
                    TextEditor(text: $input)
                        .font(.mono(12))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 70)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Palette.void))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.panelEdge))
                    LabelCaps(text: "xor key")
                    TextField("key", text: $key)
                        .font(.mono(12))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Palette.void))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.panelEdge))
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button("B64") { run(Transforms.base64) }
                    Button("Unb64") { run(Transforms.unbase64) }
                    Button("Hex") { run { Transforms.hex($0) } }
                    Button("Unhex") { run(Transforms.unhex) }
                }
                HStack(spacing: 8) {
                    Button("rot13") { run { Transforms.rot13($0) } }
                    Button("xor") { run { Transforms.xor($0, key: key) } }
                    Button("JWT") { run(Transforms.decodeJWT) }
                    Button("Strip sig") { run(Transforms.stripJWT) }
                }
            }
            .buttonStyle(DeckButtonStyle())

            Panel(tint: Palette.acid.opacity(0.5)) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        LabelCaps(text: "output")
                        Spacer()
                        Button("Copy") {
                            UIPasteboard.general.string = output
                            Haptics.tap()
                        }
                        .buttonStyle(DeckButtonStyle())
                    }
                    Text(output.isEmpty ? "-" : output)
                        .font(.mono(12))
                        .foregroundStyle(output.isEmpty ? Palette.dim : Palette.paper)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Text("JWT mode decodes the two claims blocks. Strip sig turns a signed token into alg=none bait; testing hosts only.")
                .font(.mono(10))
                .foregroundStyle(Palette.dim)
        }
    }

    private func run(_ transform: (String) -> String?) {
        Haptics.tap()
        if let value = transform(input) {
            output = value
            CaseLog.shared.record("TRD-01", "Transform applied to \(input.count) chars")
        } else {
            output = "transform failed"
            Haptics.miss()
        }
    }
}