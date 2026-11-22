import CoreNFC
import SwiftUI

struct NFCRecord: Identifiable, Hashable {
    let id = UUID()
    let type: String
    let payloadHex: String
    let text: String?
}

@MainActor
final class NFCBench: NSObject, ObservableObject {
    @Published private(set) var records: [NFCRecord] = []
    @Published private(set) var status = "idle"
    @Published private(set) var tagInfo: [String] = []
    @Published var apdu = "00A4040007A0000000031010"
    @Published var response = ""
    @Published var message: String?

    private var ndefSession: NFCNDEFReaderSession?
    private var tagSession: NFCTagReaderSession?
    private var isoTag: NFCISO7816Tag?

    func readNDEF() {
        guard NFCNDEFReaderSession.readingAvailable else {
            message = "NFC unavailable on this device."
            return
        }
        records = []
        status = "waiting for tag"
        let session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        session.alertMessage = "Hold the tag against the top of the phone."
        session.begin()
        ndefSession = session
    }

    func openTagSession() {
        guard NFCNDEFReaderSession.readingAvailable else {
            message = "NFC unavailable on this device."
            return
        }
        status = "polling"
        tagInfo = []
        guard let session = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693], delegate: self, queue: nil) else {
            message = "Could not open a tag session."
            return
        }
        session.alertMessage = "Tap a badge or transit chip."
        session.begin()
        tagSession = session
    }

    func sendAPDU() {
        guard let tag = isoTag else {
            message = "Connect to a tag first."
            return
        }
        guard let command = Self.makeAPDU(apdu) else {
            message = "APDU needs at least 4 hex bytes."
            return
        }
        status = "apdu"
        tag.sendCommand(apdu: command) { [weak self] data, sw1, sw2, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.message = error.localizedDescription
                    return
                }
                let hex = (data + Data([sw1, sw2])).map { String(format: "%02X", $0) }.joined(separator: " ")
                self.response = hex
                self.status = String(format: "SW %02X%02X", sw1, sw2)
                CaseLog.shared.finding("RAD-02", "APDU \(self.apdu) -> \(hex)")
            }
        }
    }

    private static func makeAPDU(_ hex: String) -> NFCISO7816APDU? {
        let clean = hex.replacingOccurrences(of: " ", with: "")
        guard clean.count >= 8, clean.count % 2 == 0 else { return nil }
        var bytes: [UInt8] = []
        var index = clean.startIndex
        while index < clean.endIndex {
            let next = clean.index(index, offsetBy: 2)
            guard let byte = UInt8(clean[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        let body = bytes.count > 4 ? Data(bytes[4...]) : Data()
        return NFCISO7816APDU(instructionClass: bytes[0], instructionCode: bytes[1],
                              p1Parameter: bytes[2], p2Parameter: bytes[3],
                              data: body, expectedResponseLength: body.isEmpty ? 0 : 256)
    }
}

extension NFCBench: NFCNDEFReaderSessionDelegate {
    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        Task { @MainActor in
            self.status = "idle"
            self.ndefSession = nil
            if let nfcError = error as? NFCReaderError, nfcError.code != .readerSessionInvalidationErrorFirstNDEFTagRead {
                self.message = nfcError.localizedDescription
            }
        }
    }

    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        Task { @MainActor in
            for message in messages {
                for record in message.records {
                    let hex = record.payload.map { String(format: "%02x", $0) }.joined()
                    let text = String(data: record.payload, encoding: .utf8)
                    let type = String(data: record.typeNameFormat == .nfcWellKnown ? record.type : record.type, encoding: .utf8) ?? "?"
                    self.records.append(NFCRecord(type: type, payloadHex: hex, text: text))
                    CaseLog.shared.finding("RAD-02", "NDEF \(type)", fields: ["payload": hex])
                }
            }
            self.status = "read \(self.records.count) records"
            Haptics.hit()
        }
    }
}

extension NFCBench: NFCTagReaderSessionDelegate {
    nonisolated func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        Task { @MainActor in
            self.status = "idle"
            self.tagSession = nil
            self.isoTag = nil
            if let nfcError = error as? NFCReaderError,
               nfcError.code != .readerSessionInvalidationErrorUserCanceled {
                self.message = nfcError.localizedDescription
            }
        }
    }

    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else { return }
        session.connect(to: tag) { [weak self] error in
            guard error == nil else {
                session.invalidate(errorMessage: "Could not connect.")
                return
            }
            Task { @MainActor in
                guard let self else { return }
                guard case let .iso7816(iso) = tag else {
                    self.message = "Tag is not ISO 7816."
                    session.invalidate(errorMessage: "Not an ISO 7816 tag.")
                    return
                }
                self.isoTag = iso
                let uid = iso.identifier.map { String(format: "%02X", $0) }.joined()
                var info = ["uid": uid]
                if let historical = iso.historicalBytes {
                    info["historical"] = historical.map { String(format: "%02X", $0) }.joined()
                }
                if !iso.initialSelectedAID.isEmpty { info["aid"] = iso.initialSelectedAID }
                self.tagInfo = info.map { "\($0.key.uppercased()) \($0.value)" }
                self.status = "tag connected"
                Haptics.hit()
                CaseLog.shared.finding("RAD-02", "ISO 7816 tag", fields: info)
            }
        }
    }
}

