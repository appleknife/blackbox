import Foundation

/// Minimal libpcap stream writer. Packets handed to the tunnel are raw IP,
/// so the capture uses LINKTYPE_RAW (101). Open in Wireshark directly.
final class PcapWriter {
    static let linkTypeRaw: UInt32 = 101

    private let handle: FileHandle
    private let queue = DispatchQueue(label: "com.appleknife.blackbox.pcap")
    private(set) var packetCount = 0
    private(set) var byteCount = 0

    let url: URL

    init(url: URL) throws {
        self.url = url
        let manager = FileManager.default
        if !manager.fileExists(atPath: url.path) {
            manager.createFile(atPath: url.path, contents: nil)
        }
        handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: 0)
        try writeHeader()
    }

    deinit {
        try? handle.close()
    }

    private func writeHeader() throws {
        var header = Data()
        header.appendLE(UInt32(0xA1B2C3D4).littleEndian)
        header.appendLE(UInt16(2).littleEndian)
        header.appendLE(UInt16(4).littleEndian)
        header.appendLE(UInt32(0).littleEndian)
        header.appendLE(UInt32(0).littleEndian)
        header.appendLE(UInt32(65535).littleEndian)
        header.appendLE(Self.linkTypeRaw.littleEndian)
        try handle.write(contentsOf: header)
    }

    func append(_ packet: Data, at date: Date = Date()) {
        guard !packet.isEmpty else { return }
        queue.async { [weak self] in
            guard let self else { return }
            let stamp = UInt32(date.timeIntervalSince1970)
            var record = Data()
            record.appendLE(stamp.littleEndian)
            record.appendLE(min(999_999, UInt32((date.timeIntervalSince1970 - Double(stamp)) * 1_000_000)).littleEndian)
            record.appendLE(UInt32(packet.count).littleEndian)
            record.appendLE(UInt32(packet.count).littleEndian)
            record.append(packet)
            try? self.handle.write(contentsOf: record)
            self.packetCount += 1
            self.byteCount += packet.count
        }
    }

    func flush() {
        queue.sync {
            try? self.handle.synchronize()
        }
    }
}


extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var raw = value.littleEndian
        Swift.withUnsafeBytes(of: &raw) { append(contentsOf: $0) }
    }
}

