import CryptoKit
import SwiftUI

enum HashTool {
    static let words = [
        "password", "admin", "letmein", "123456", "12345678", "qwerty", "dragon", "monkey",
        "iloveyou", "sunshine", "princess", "welcome", "shadow", "master", "football",
        "baseball", "superman", "trustno1", "blackbox", "analyst", "hunter2", "correcthorse",
        "battery", "staple", "changeme", "root", "toor", "guest", "test", "secret",
        "summer", "winter", "spring", "autumn", "january", "monday", "starwars",
        "pokemon", "nintendo", "coffee", "pizza", "banana", "orange", "mushroom"
    ]

    static func identify(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("$2") { return "bcrypt" }
        if trimmed.hasPrefix("$6$") { return "sha512crypt" }
        if trimmed.hasPrefix("$argon2") { return "argon2" }
        if trimmed.hasPrefix("$1$") { return "md5crypt" }
        let hex = trimmed.allSatisfy { $0.isHexDigit }
        guard hex else { return "not a hex digest" }
        switch trimmed.count {
        case 32: return "32 hex — MD5 or NTLM"
        case 40: return "40 hex — SHA-1"
        case 56: return "56 hex — SHA-224"
        case 64: return "64 hex — SHA-256"
        case 96: return "96 hex — SHA-384"
        case 128: return "128 hex — SHA-512"
        default: return "\(trimmed.count) hex chars — unknown width"
        }
    }

    static func digests(_ text: String) -> [(String, String)] {
        let data = Data(text.utf8)
        return [
            ("md5", Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()),
            ("sha1", Insecure.SHA1.hash(data: data).map { String(format: "%02x", $0) }.joined()),
            ("sha256", SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()),
            ("sha512", SHA512.hash(data: data).map { String(format: "%02x", $0) }.joined())
        ]
    }

    static func crack(_ target: String, progress: @escaping (Int) -> Void) -> String? {
        let needle = target.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for (index, word) in words.enumerated() {
            for (name, digest) in digests(word) where digest == needle {
                progress(index)
                return "\(word)  (\(name))"
            }
            if index % 8 == 0 { progress(index) }
        }
        return nil
    }
}

struct HashView: View {
    @State private var input = ""
    @State private var verdict = "Awaiting a digest."
    @State private var cracked: String?
    @State private var busy = false

    var body: some View {
        ScreenChrome(title: "Hash bench", code: "TRD-02") {
            Panel {
                VStack(alignment: .leading, spacing: 8) {
                    LabelCaps(text: "digest or plaintext")
                    TextEditor(text: $input)
                        .font(.mono(12))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 64)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Palette.void))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.panelEdge))
                    HStack(spacing: 10) {
                        Button {
                            Haptics.tap()
                            verdict = HashTool.identify(input)
                        } label: {
                            Label("Identify", systemImage: "questionmark.circle")
                        }
                        .buttonStyle(DeckButtonStyle(filled: true))
                        Button {
                            crack()
                        } label: {
                            Label("Crack", systemImage: "hammer")
                        }
                        .buttonStyle(DeckButtonStyle(tint: Palette.amber))
                        .disabled(busy)
                    }
                }
            }

            Panel {
                VStack(alignment: .leading, spacing: 6) {
                    LabelCaps(text: "verdict")
                    Text(verdict)
                        .font(.mono(12))
                        .foregroundStyle(Palette.paper)
                        .textSelection(.enabled)
                    if let cracked {
                        Text("CRACKED: \(cracked)")
                            .font(.mono(13, weight: .bold))
                            .foregroundStyle(Palette.acid)
                    }
                }
            }

            Panel {
                VStack(alignment: .leading, spacing: 4) {
                    LabelCaps(text: "digest this text")
                    ForEach(HashTool.digests(input), id: \.0) { name, value in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(name.uppercased())
                                .font(.mono(8, weight: .bold))
                                .foregroundStyle(Palette.dim)
                            Text(value)
                                .font(.mono(9))
                                .foregroundStyle(Palette.acid.opacity(0.85))
                                .textSelection(.enabled)
                        }
                    }
                }
            }

            Text("The wordlist is 45 common passwords plus dates and mascots. Enough to catch homework, not a real audit.")
                .font(.mono(10))
                .foregroundStyle(Palette.dim)
        }
    }

    private func crack() {
        Haptics.tap()
        busy = true
        cracked = nil
        verdict = "Running 45 candidates…"
        let target = input
        Task {
            let found = await Task.detached(priority: .userInitiated) {
                HashTool.crack(target) { _ in }
            }.value
            cracked = found
            verdict = found == nil ? "No match in the built-in list." : "Match found."
            busy = false
            if found != nil {
                Haptics.hit()
                CaseLog.shared.finding("TRD-02", "Cracked \(found!)", fields: ["digest": target.prefix(16) + "…"])
            } else {
                Haptics.miss()
            }
        }
    }
}