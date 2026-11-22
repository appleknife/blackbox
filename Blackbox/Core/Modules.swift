import Foundation

enum ModuleGroup: String, CaseIterable {
    case network = "The wire"
    case radio = "Radios"
    case tradecraft = "Tradecraft"
    case recon = "Open source"
}

enum ModuleID: String, CaseIterable, Identifiable {
    case lanSweep
    case bonjour
    case wifi
    case bleed
    case nfc
    case capture
    case encode
    case hash
    case osint

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lanSweep: return "LAN sweep"
        case .bonjour: return "Announcements"
        case .wifi: return "Wi-Fi readout"
        case .bleed: return "BLE explorer"
        case .nfc: return "NFC bench"
        case .capture: return "Packet tap"
        case .encode: return "Encode deck"
        case .hash: return "Hash bench"
        case .osint: return "Open source"
        }
    }

    var glyph: String {
        switch self {
        case .lanSweep: return "dot.radiowaves.left.and.right"
        case .bonjour: return "antenna.radiowaves.left.and.right"
        case .wifi: return "wifi"
        case .bleed: return "wave.3.right"
        case .nfc: return "radiowaves.left"
        case .capture: return "square.stack.3d.up"
        case .encode: return "chevron.left.forwardslash.chevron.right"
        case .hash: return "number"
        case .osint: return "globe"
        }
    }

    var blurb: String {
        switch self {
        case .lanSweep: return "Knock ports across the subnet and keep what answers."
        case .bonjour: return "Listen to devices announcing themselves."
        case .wifi: return "SSID, BSSID, signal, local address."
        case .bleed: return "Enumerate GATT, read, write, notify."
        case .nfc: return "Dump NDEF, ISO 7816 and 15693 tags."
        case .capture: return "Route traffic through a pcap tunnel."
        case .encode: return "Base64, hex, JWT, XOR, rot13."
        case .hash: return "Identify digests and run short wordlists."
        case .osint: return "DNS, RDAP, certificate pulls."
        }
    }

    var group: ModuleGroup {
        switch self {
        case .lanSweep, .bonjour, .wifi, .capture: return .network
        case .bleed, .nfc: return .radio
        case .encode, .hash: return .tradecraft
        case .osint: return .recon
        }
    }

    var code: String {
        switch self {
        case .lanSweep: return "NET-01"
        case .bonjour: return "NET-02"
        case .wifi: return "NET-03"
        case .capture: return "NET-04"
        case .bleed: return "RAD-01"
        case .nfc: return "RAD-02"
        case .encode: return "TRD-01"
        case .hash: return "TRD-02"
        case .osint: return "OSN-01"
        }
    }

    static func inGroup(_ group: ModuleGroup) -> [ModuleID] {
        allCases.filter { $0.group == group }
    }
}