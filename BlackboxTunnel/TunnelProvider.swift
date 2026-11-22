import Foundation
import Network
import NetworkExtension

final class TunnelProvider: NEPacketTunnelProvider {
    private var relay: TunnelRelay?

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.7.0.1")
        let ipv4 = NEIPv4Settings(addresses: ["10.7.0.2"], subnetMasks: ["255.255.255.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        ipv4.excludedRoutes = [
            NEIPv4Route(destinationAddress: "10.0.0.0", subnetMask: "255.0.0.0"),
            NEIPv4Route(destinationAddress: "172.16.0.0", subnetMask: "255.240.0.0"),
            NEIPv4Route(destinationAddress: "192.168.0.0", subnetMask: "255.255.0.0"),
            NEIPv4Route(destinationAddress: "169.254.0.0", subnetMask: "255.255.0.0"),
            NEIPv4Route(destinationAddress: "224.0.0.0", subnetMask: "240.0.0.0")
        ]
        settings.ipv4Settings = ipv4
        settings.dnsSettings = NEDNSSettings(servers: ["1.1.1.1", "9.9.9.9"])
        settings.mtu = 1400

        let relay = TunnelRelay(provider: self)
        self.relay = relay

        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self else { return }
            if let error {
                self.relay = nil
                completionHandler(error)
                return
            }
            relay.start()
            self.readLoop()
            completionHandler(nil)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        relay?.shutdown()
        relay = nil
        completionHandler()
    }

    private func readLoop() {
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self, let relay = self.relay else { return }
            for (packet, proto) in zip(packets, protocols) where proto.int32Value == AF_INET {
                relay.handle(packet)
            }
            self.readLoop()
        }
    }

    func inject(_ packet: Data) {
        relay?.capture(packet)
        packetFlow.writePackets([packet], withProtocols: [NSNumber(value: AF_INET)])
    }
}

final class TunnelRelay {
    private weak var provider: TunnelProvider?
    private let queue = DispatchQueue(label: "com.appleknife.blackbox.relay")
    private var writer: PcapWriter?
    private var tcp: [String: TCPFlow] = [:]
    private var udp: [String: UDPFlow] = [:]
    private var timer: DispatchSourceTimer?

    private struct TCPFlow {
        var connection: NWConnection
        var clientNext: UInt32
        var serverNext: UInt32
        var ready = false
        var pending = Data()
        var lastSeen = Date()
    }

    private struct UDPFlow {
        var connection: NWConnection
        var lastSeen = Date()
    }

    init(provider: TunnelProvider) {
        self.provider = provider
        openCapture()
    }

    private func openCapture() {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.appleknife.blackbox") else { return }
        let folder = container.appendingPathComponent("captures")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = "capture-\(Int(Date().timeIntervalSince1970)).pcap"
        writer = try? PcapWriter(url: folder.appendingPathComponent(name))
    }

    func capture(_ packet: Data) {
        writer?.append(packet)
    }

    func start() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 30, repeating: 30)
        timer.setEventHandler { [weak self] in self?.reap() }
        timer.resume()
        self.timer = timer
    }

    func shutdown() {
        timer?.cancel()
        timer = nil
        queue.sync {
            tcp.values.forEach { $0.connection.cancel() }
            tcp.removeAll()
            udp.values.forEach { $0.connection.cancel() }
            udp.removeAll()
        }
        writer?.flush()
        writer = nil
    }

    func handle(_ packet: Data) {
        capture(packet)
        guard let header = IPPacket.parse(packet),
              let src = Self.octets(header.source),
              let dst = Self.octets(header.destination) else { return }

        let bytes = [UInt8](packet)
        guard bytes.count >= 20 else { return }
        let offset = Int(bytes[0] & 0x0F) * 4
        let protocolNumber = bytes[9]
        guard bytes.count >= offset + 4 else { return }

        let sourcePort = UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1])
        let destinationPort = UInt16(bytes[offset + 2]) << 8 | UInt16(bytes[offset + 3])
        let key = "\(header.source):\(sourcePort)>\(header.destination):\(destinationPort)"

        switch protocolNumber {
        case 6:
            guard bytes.count >= offset + 20 else { return }
            let flags = bytes[offset + 13]
            let seq = Self.beUInt32(bytes, offset + 4)
            let headerLength = Int(bytes[offset + 12] >> 4) * 4
            guard headerLength >= 20, offset + headerLength <= bytes.count else { return }
            let payload = Data(bytes[(offset + headerLength)...])
            handleTCP(key: key, flags: flags, seq: seq, payload: payload,
                      sourcePort: sourcePort, destinationPort: destinationPort,
                      src: dst, dst: src)
        case 17:
            guard bytes.count >= offset + 8 else { return }
            let payload = Data(bytes[(offset + 8)...])
            handleUDP(key: key, payload: payload,
                      sourcePort: sourcePort, destinationPort: destinationPort,
                      src: dst, dst: src)
        default:
            break
        }
    }

    private func handleTCP(key: String, flags: UInt8, seq: UInt32, payload: Data,
                           sourcePort: UInt16, destinationPort: UInt16, src: [UInt8], dst: [UInt8]) {
        if flags & 0x02 != 0 && flags & 0x10 == 0 {
            queue.async { [weak self] in
                guard let self else { return }
                if let existing = self.tcp[key] {
                    if existing.ready {
                        self.sendTCP(flags: 0x12, seq: existing.serverNext &- 1, ack: existing.clientNext,
                                     payload: Data(), src: src, dst: dst,
                                     sourcePort: destinationPort, destinationPort: sourcePort)
                    }
                    return
                }
                let connection = NWConnection(host: NWEndpoint.Host(Self.dotted(src)),
                                              port: NWEndpoint.Port(rawValue: destinationPort) ?? .any, using: .tcp)
                let flow = TCPFlow(connection: connection, clientNext: seq &+ 1,
                                   serverNext: UInt32.random(in: 1_000_000...4_000_000_000))
                self.tcp[key] = flow
                connection.stateUpdateHandler = { [weak self] state in
                    self?.queue.async {
                        guard let self, var current = self.tcp[key] else { return }
                        switch state {
                        case .ready:
                            current.ready = true
                            self.tcp[key] = current
                            self.sendTCP(flags: 0x12, seq: current.serverNext, ack: current.clientNext,
                                         payload: Data(), src: src, dst: dst,
                                         sourcePort: destinationPort, destinationPort: sourcePort)
                            current.serverNext = current.serverNext &+ 1
                            if let pending = self.tcp[key]?.pending, !pending.isEmpty {
                                connection.send(content: pending, completion: .idempotent)
                                self.tcp[key]?.pending = Data()
                            }
                        case .failed, .cancelled:
                            self.sendTCP(flags: 0x14, seq: current.serverNext, ack: current.clientNext,
                                         payload: Data(), src: src, dst: dst,
                                         sourcePort: destinationPort, destinationPort: sourcePort)
                            self.tcp[key] = nil
                        default:
                            break
                        }
                    }
                }
                connection.start(queue: self.queue)
                self.receive(connection: connection, key: key,
                             sourcePort: sourcePort, destinationPort: destinationPort,
                             src: src, dst: dst)
            }
            return
        }

        if flags & 0x04 != 0 {
            queue.async { [weak self] in
                self?.tcp.removeValue(forKey: key)?.connection.cancel()
            }
            return
        }

        queue.async { [weak self] in
            guard let self, var flow = self.tcp[key] else { return }
            flow.lastSeen = Date()
            if !payload.isEmpty {
                flow.clientNext = seq &+ UInt32(payload.count)
                if flow.ready {
                    flow.connection.send(content: payload, completion: .idempotent)
                } else {
                    flow.pending.append(payload)
                }
                self.tcp[key] = flow
                self.sendTCP(flags: 0x10, seq: flow.serverNext, ack: flow.clientNext,
                             payload: Data(), src: src, dst: dst,
                             sourcePort: destinationPort, destinationPort: sourcePort)
            }
            if flags & 0x01 != 0 {
                flow.connection.cancel()
                self.tcp[key] = nil
                self.sendTCP(flags: 0x11, seq: flow.serverNext &+ 1, ack: flow.clientNext,
                             payload: Data(), src: src, dst: dst,
                             sourcePort: destinationPort, destinationPort: sourcePort)
            }
        }
    }

    private func receive(connection: NWConnection, key: String,
                         sourcePort: UInt16, destinationPort: UInt16, src: [UInt8], dst: [UInt8]) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1440) { [weak self] data, _, complete, _ in
            guard let self else { return }
            self.queue.async {
                guard var flow = self.tcp[key] else { return }
                if let data, !data.isEmpty {
                    let chunks = stride(from: 0, to: data.count, by: 1200).map {
                        data.subdata(in: $0..<min($0 + 1200, data.count))
                    }
                    for chunk in chunks {
                        self.sendTCP(flags: 0x18, seq: flow.serverNext, ack: flow.clientNext,
                                     payload: chunk, src: src, dst: dst,
                                     sourcePort: destinationPort, destinationPort: sourcePort)
                        flow.serverNext = flow.serverNext &+ UInt32(chunk.count)
                    }
                    flow.lastSeen = Date()
                    self.tcp[key] = flow
                }
                if complete {
                    self.sendTCP(flags: 0x11, seq: flow.serverNext, ack: flow.clientNext,
                                 payload: Data(), src: src, dst: dst,
                                 sourcePort: destinationPort, destinationPort: sourcePort)
                    self.tcp[key] = nil
                } else {
                    self.receive(connection: connection, key: key,
                                 sourcePort: sourcePort, destinationPort: destinationPort, src: src, dst: dst)
                }
            }
        }
    }

    private func handleUDP(key: String, payload: Data, sourcePort: UInt16, destinationPort: UInt16,
                           src: [UInt8], dst: [UInt8]) {
        queue.async { [weak self] in
            guard let self else { return }
            if var existing = self.udp[key] {
                existing.lastSeen = Date()
                self.udp[key] = existing
                existing.connection.send(content: payload, completion: .idempotent)
                return
            }
            let connection = NWConnection(host: NWEndpoint.Host(Self.dotted(src)),
                                          port: NWEndpoint.Port(rawValue: destinationPort) ?? .any, using: .udp)
            self.udp[key] = UDPFlow(connection: connection)
            connection.stateUpdateHandler = { [weak self] state in
                self?.queue.async {
                    guard let self else { return }
                    switch state {
                    case .ready:
                        connection.send(content: payload, completion: .idempotent)
                        self.receiveUDP(connection: connection, key: key,
                                        sourcePort: sourcePort, destinationPort: destinationPort,
                                        src: src, dst: dst)
                    case .failed, .cancelled:
                        self.udp[key] = nil
                    default:
                        break
                    }
                }
            }
            connection.start(queue: self.queue)
        }
    }

    private func receiveUDP(connection: NWConnection, key: String,
                            sourcePort: UInt16, destinationPort: UInt16, src: [UInt8], dst: [UInt8]) {
        connection.receiveMessage { [weak self] data, _, complete, error in
            guard let self else { return }
            self.queue.async {
                guard var flow = self.udp[key] else { return }
                if let data, !data.isEmpty {
                    flow.lastSeen = Date()
                    self.udp[key] = flow
                    self.sendUDP(payload: data, src: src, dst: dst,
                                 sourcePort: destinationPort, destinationPort: sourcePort)
                }
                if complete || error != nil {
                    connection.cancel()
                    self.udp[key] = nil
                } else {
                    self.receiveUDP(connection: connection, key: key,
                                    sourcePort: sourcePort, destinationPort: destinationPort, src: src, dst: dst)
                }
            }
        }
    }

    private func reap() {
        queue.async { [weak self] in
            guard let self else { return }
            let cutoff = Date().addingTimeInterval(-45)
            for (key, flow) in self.tcp where flow.lastSeen < cutoff {
                flow.connection.cancel()
                self.tcp[key] = nil
            }
            let udpCutoff = Date().addingTimeInterval(-60)
            for (key, flow) in self.udp where flow.lastSeen < udpCutoff {
                flow.connection.cancel()
                self.udp[key] = nil
            }
        }
    }

    private func sendTCP(flags: UInt8, seq: UInt32, ack: UInt32, payload: Data,
                         src: [UInt8], dst: [UInt8], sourcePort: UInt16, destinationPort: UInt16) {
        let header = tcpHeader(src: src, dst: dst, sourcePort: sourcePort, destinationPort: destinationPort,
                               seq: seq, ack: ack, flags: flags, payload: payload)
        guard let packet = ipv4(src: src, dst: dst, proto: 6, payload: header + payload) else { return }
        provider?.inject(packet)
    }

    private func sendUDP(payload: Data, src: [UInt8], dst: [UInt8],
                         sourcePort: UInt16, destinationPort: UInt16) {
        let header = udpHeader(src: src, dst: dst, sourcePort: sourcePort, destinationPort: destinationPort, payload: payload)
        guard let packet = ipv4(src: src, dst: dst, proto: 17, payload: header + payload) else { return }
        provider?.inject(packet)
    }

    private func tcpHeader(src: [UInt8], dst: [UInt8], sourcePort: UInt16, destinationPort: UInt16,
                           seq: UInt32, ack: UInt32, flags: UInt8, payload: Data) -> Data {
        var header = Data()
        header.append(contentsOf: Self.be(sourcePort))
        header.append(contentsOf: Self.be(destinationPort))
        header.append(contentsOf: Self.be(seq))
        header.append(contentsOf: Self.be(ack))
        header.append(0x50)
        header.append(flags)
        header.append(contentsOf: Self.be(UInt16(64240)))
        header.append(contentsOf: [0, 0])
        header.append(contentsOf: [0, 0])
        var checksumData = Data()
        checksumData.append(contentsOf: src)
        checksumData.append(contentsOf: dst)
        checksumData.append(contentsOf: [0, 6])
        checksumData.append(contentsOf: Self.be(UInt16(header.count + payload.count)))
        checksumData.append(header)
        checksumData.append(payload)
        let sum = Self.checksum([UInt8](checksumData))
        header[16] = UInt8(sum >> 8)
        header[17] = UInt8(sum & 0xFF)
        return header
    }

    private func udpHeader(src: [UInt8], dst: [UInt8], sourcePort: UInt16, destinationPort: UInt16, payload: Data) -> Data {
        var header = Data()
        header.append(contentsOf: Self.be(sourcePort))
        header.append(contentsOf: Self.be(destinationPort))
        header.append(contentsOf: Self.be(UInt16(8 + payload.count)))
        header.append(contentsOf: Self.be(UInt16(0)))
        var checksumData = Data()
        checksumData.append(contentsOf: src)
        checksumData.append(contentsOf: dst)
        checksumData.append(contentsOf: [0, 17])
        checksumData.append(contentsOf: Self.be(UInt16(header.count + payload.count)))
        checksumData.append(header)
        checksumData.append(payload)
        var sum = Self.checksum([UInt8](checksumData))
        if sum == 0 { sum = 0xFFFF }
        header[6] = UInt8(sum >> 8)
        header[7] = UInt8(sum & 0xFF)
        return header
    }

    private func ipv4(src: [UInt8], dst: [UInt8], proto: UInt8, payload: Data) -> Data? {
        guard src.count == 4, dst.count == 4 else { return nil }
        var header = Data([0x45, 0x00])
        header.append(contentsOf: Self.be(UInt16(20 + payload.count)))
        header.append(contentsOf: Self.be(UInt16.random(in: 1...65000)))
        header.append(contentsOf: [0x40, 0x00])
        header.append(contentsOf: [64, proto, 0, 0])
        header.append(contentsOf: src)
        header.append(contentsOf: dst)
        let sum = Self.checksum([UInt8](header))
        header[10] = UInt8(sum >> 8)
        header[11] = UInt8(sum & 0xFF)
        return header + payload
    }

    private static func octets(_ text: String) -> [UInt8]? {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var result: [UInt8] = []
        for part in parts {
            guard let value = UInt8(part) else { return nil }
            result.append(value)
        }
        return result
    }

    private static func dotted(_ octets: [UInt8]) -> String {
        octets.map(String.init).joined(separator: ".")
    }

    private static func be(_ value: UInt16) -> [UInt8] {
        [UInt8(value >> 8), UInt8(value & 0xFF)]
    }

    private static func be(_ value: UInt32) -> [UInt8] {
        [UInt8(value >> 24 & 0xFF), UInt8(value >> 16 & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF)]
    }

    private static func beUInt32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16
            | UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3])
    }

    private static func checksum(_ bytes: [UInt8]) -> UInt16 {
        var sum: UInt32 = 0
        var index = 0
        while index + 1 < bytes.count {
            sum += UInt32(bytes[index]) << 8 | UInt32(bytes[index + 1])
            index += 2
        }
        if index < bytes.count { sum += UInt32(bytes[index]) << 8 }
        while sum >> 16 != 0 { sum = (sum & 0xFFFF) + (sum >> 16) }
        return UInt16(~sum & 0xFFFF)
    }
}