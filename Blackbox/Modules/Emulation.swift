import CoreNFC
import SwiftUI

@available(iOS 17.4, *)
@MainActor
final class CardEmulator: ObservableObject {
    @Published private(set) var status = "idle"
    @Published private(set) var traffic: [String] = []
    @Published var message: String?

    private var task: Task<Void, Never>?
    private var session: CardSession?

    var isRunning: Bool { task != nil }

    func start() {
        guard task == nil else { return }
        guard NFCReaderSession.readingAvailable, CardSession.isSupported else {
            status = "unsupported here"
            return
        }

        task = Task { [weak self] in
            guard let self else { return }
            guard await CardSession.isEligible else {
                self.status = "ineligible system"
                self.message = "Card emulation is limited to supported regions and devices."
                self.task = nil
                return
            }

            var intent: NFCPresentmentIntentAssertion?
            do {
                intent = try await NFCPresentmentIntentAssertion.acquire()
                let session = try await CardSession()
                self.session = session
                self.status = "waiting for reader"
                session.alertMessage = "Hold the phone to the reader."

                for try await event in session.eventStream {
                    switch event {
                    case .sessionStarted:
                        self.status = "session up"
                    case .readerDetected:
                        self.status = "reader found"
                        try await session.startEmulation()
                    case .readerDeselected:
                        self.status = "reader gone"
                        await session.stopEmulation(status: .success)
                    case .received(let apdu):
                        let hex = apdu.payload.map { String(format: "%02X", $0) }.joined(separator: " ")
                        self.traffic.append("← \(hex)")
                        if self.traffic.count > 40 { self.traffic.removeFirst() }
                        CaseLog.shared.record("RAD-02", "Emulated APDU \(hex)")
                        try? await apdu.respond(response: Data([0x90, 0x00]))
                    case .sessionInvalidated:
                        self.status = "closed"
                    @unknown default:
                        break
                    }
                }
            } catch {
                self.message = error.localizedDescription
                self.status = "failed"
            }
            intent = nil
            self.session = nil
            self.task = nil
        }
    }

    func stop() {
        session?.invalidate()
        task?.cancel()
        task = nil
        status = "idle"
    }
}

@available(iOS 17.4, *)
struct EmulationPanel: View {
    @StateObject private var emulator = CardEmulator()

    var body: some View {
        Panel(tint: Palette.amber.opacity(0.55)) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    LabelCaps(text: "emulate iso 7816", tint: Palette.amber)
                    Spacer()
                    StatusPill(text: emulator.status, tint: Palette.amber)
                }
                Text("The phone becomes the badge. Every APDU is logged and answered 90 00. AIDs: Visa, Mastercard, NDEF, test RID.")
                    .font(.mono(10))
                    .foregroundStyle(Palette.dim)
                HStack(spacing: 10) {
                    if emulator.isRunning {
                        Button("Stop") { emulator.stop() }
                            .buttonStyle(DeckButtonStyle(tint: Palette.blood))
                    } else {
                        Button("Present") { emulator.start() }
                            .buttonStyle(DeckButtonStyle(tint: Palette.amber))
                    }
                }
                if let message = emulator.message {
                    Text(message).font(.mono(10)).foregroundStyle(Palette.blood)
                }
                ForEach(Array(emulator.traffic.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.mono(10))
                        .foregroundStyle(Palette.dim)
                }
            }
        }
    }
}