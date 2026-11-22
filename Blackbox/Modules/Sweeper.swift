import Foundation
import Network
import UIKit

struct SweepHit: Identifiable, Hashable {
    let host: String
    let port: UInt16
    let service: String
    var banner: String?

    var id: String { "\(host):\(port)" }
}

@MainActor
final class HostSweeper: ObservableObject {
    static let ports: [(port: UInt16, service: String)] = [
        (22, "ssh"), (53, "dns"), (80, "http"), (443, "https"), (445, "smb"),
        (554, "rtsp"), (1883, "mqtt"), (3389, "rdp"), (5000, "upnp"),
        (8008, "cast"), (8080, "http-alt"), (8443, "https-alt"),
        (9100, "printer"), (62078, "lockdown")
    ]

    @Published private(set) var hits: [SweepHit] = []
    @Published private(set) var isRunning = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var address: String?
    @Published var message: String?

    private var stopped = false
    private static let queue = DispatchQueue(label: "com.appleknife.blackbox.sweep", qos: .userInitiated)

    func start() async {
        guard !isRunning else { return }
        guard let local = Self.wifiAddress() else {
            message = "No local IPv4 address. Join Wi-Fi first."
            Haptics.miss()
            return
        }

        address = local
        hits = []
        progress = 0
        stopped = false
        isRunning = true

        let prefix = local.split(separator: ".").dropLast().joined(separator: ".")
        let own = local
        let hosts = (1...254).map { "\(prefix).\($0)" }.filter { $0 != own }
        CaseLog.shared.record("NET-01", "Sweeping \(prefix).0/24 on \(Self.ports.count) ports")

        var done = 0
        let total = hosts.count
        for chunk in hosts.chunked(into: 6) {
            if stopped { break }
            await withTaskGroup(of: SweepHit?.self) { group in
                for host in chunk {
                    for entry in Self.ports {
                        group.addTask {
                            await Self.probe(host: host, port: entry.port, service: entry.service)
                        }
                    }
                }
                for await hit in group {
                    if let hit {
                        hits.append(hit)
                        Haptics.hit()
                        CaseLog.shared.finding("NET-01", "\(hit.service) open", fields: ["host": hit.host, "port": "\(hit.port)"])
                    }
                }
            }
            done += chunk.count
            progress = Double(done) / Double(total)
            if Task.isCancelled { break }
        }

        isRunning = false
        message = stopped ? "Aborted after \(hits.count) hits." : (hits.isEmpty ? "Nothing answered. Quiet network." : "\(hits.count) open services.")
        CaseLog.shared.record("NET-01", "Sweep finished with \(hits.count) hits")
    }

    func stop() {
        stopped = true
        isRunning = false
    }

    private static func probe(host: String, port: UInt16, service: String) async -> SweepHit? {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return nil }
        let box = Box()
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
        connection.stateUpdateHandler = { state in box.state = state }
        connection.start(queue: Self.queue)

        func wait(_ seconds: Double) async { try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }

        var ready = false
        waitLoop: for _ in 0..<12 {
            await wait(0.05)
            switch box.state {
            case .ready:
                ready = true
                break waitLoop
            case .failed, .cancelled:
                ready = false
                break waitLoop
            default:
                continue
            }
        }
        guard ready else {
            connection.cancel()
            return nil
        }

        var banner: String?
        if service.hasPrefix("http") || service == "upnp" || service == "cast" {
            connection.send(content: Data("HEAD / HTTP/1.0\r\n\r\n".utf8), completion: .idempotent)
        }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 512) { data, _, _, _ in
            box.banner = data
        }
        await wait(0.28)
        connection.cancel()

        if let data = box.banner, let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) {
            banner = text.split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty }
        }

        if let banner {
            CaseLog.shared.finding("NET-01", "Banner: \(banner.prefix(80))", fields: ["host": host, "port": "\(port)"])
        }
        return SweepHit(host: host, port: port, service: service, banner: banner)
    }

    private final class Box: @unchecked Sendable {
        private let lock = NSLock()
        private var storedState: NWConnection.State = .setup
        private var storedBanner: Data?

        var state: NWConnection.State {
            get { lock.lock(); defer { lock.unlock() }; return storedState }
            set { lock.lock(); storedState = newValue; lock.unlock() }
        }

        var banner: Data? {
            get { lock.lock(); defer { lock.unlock() }; return storedBanner }
            set { lock.lock(); storedBanner = newValue; lock.unlock() }
        }
    }

    static func wifiAddress() -> String? {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return nil }
        defer { freeifaddrs(pointer) }

        for cursor in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = cursor.pointee
            guard let raw = interface.ifa_addr else { continue }
            guard raw.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: interface.ifa_name)
            guard name.hasPrefix("en") else { continue }
            var address = raw.pointee
            var text = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(&address, socklen_t(raw.pointee.sa_len),
                              &text, socklen_t(text.count), nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let value = String(cString: text)
            if !value.hasPrefix("169.254.") { return value }
        }
        return nil
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        return stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
