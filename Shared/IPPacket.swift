import Foundation

/// Just enough of the IP header to label a capture entry without a full stack.
enum IPPacket {
    enum Transport: String {
        case tcp = "TCP"
        case udp = "UDP"
        case icmp = "ICMP"
        case other = "IP"
    }

    struct Header {
        let version: UInt8
        let transport: Transport
        let source: String
        let destination: String
        let sourcePort: UInt16?
        let destinationPort: UInt16?
        let length: Int
    }

    static func parse(_ data: Data) -> Header? {
        guard data.count >= 20 else { return nil }
        let bytes = [UInt8](data.prefix(60))
        let version = bytes[0] >> 4
        guard version == 4 || version == 6 else { return nil }

        if version == 4 {
            let headerLength = Int(bytes[0] & 0x0F) * 4
            guard headerLength >= 20, headerLength <= data.count else { return nil }
            let proto = bytes[9]
            let source = "\(bytes[12]).\(bytes[13]).\(bytes[14]).\(bytes[15])"
            let destination = "\(bytes[16]).\(bytes[17]).\(bytes[18]).\(bytes[19])"
            let totalLength = Int(bytes[2]) << 8 | Int(bytes[3])

            var sourcePort: UInt16?
            var destinationPort: UInt16?
            if headerLength + 4 <= bytes.count, proto == 6 || proto == 17 {
                sourcePort = UInt16(bytes[headerLength]) << 8 | UInt16(bytes[headerLength + 1])
                destinationPort = UInt16(bytes[headerLength + 2]) << 8 | UInt16(bytes[headerLength + 3])
            }

            let transport: Transport
            switch proto {
            case 6: transport = .tcp
            case 17: transport = .udp
            case 1: transport = .icmp
            default: transport = .other
            }

            return Header(version: 4, transport: transport, source: source, destination: destination,
                          sourcePort: sourcePort, destinationPort: destinationPort,
                          length: totalLength == 0 ? data.count : totalLength)
        }

        guard data.count >= 44 else { return nil }
        let proto = bytes[6]
        var groups: [String] = []
        for offset in stride(from: 8, to: 40, by: 2) {
            groups.append(String(format: "%02x%02x", bytes[offset], bytes[offset + 1]))
        }
        var sourcePort: UInt16?
        var destinationPort: UInt16?
        if data.count >= 48, proto == 6 || proto == 17 {
            sourcePort = UInt16(bytes[40]) << 8 | UInt16(bytes[41])
            destinationPort = UInt16(bytes[42]) << 8 | UInt16(bytes[43])
        }
        let transport: Transport = proto == 6 ? .tcp : (proto == 17 ? .udp : (proto == 58 ? .icmp : .other))
        return Header(version: 6, transport: transport, source: groups.joined(separator: ":"),
                      destination: groups.joined(separator: ":"),
                      sourcePort: sourcePort, destinationPort: destinationPort, length: data.count)
    }
}
