import Combine
import NetworkExtension
import SwiftUI

struct CaptureFile: Identifiable, Hashable {
    let url: URL
    let size: Int
    let date: Date

    var id: String { url.path }
}

@MainActor
final class TunnelManager: ObservableObject {
    @Published private(set) var status: NEVPNStatus = .disconnected
    @Published private(set) var files: [CaptureFile] = []
    @Published var message: String?

    private var manager: NETunnelProviderManager?
    private var observer: NSObjectProtocol?
    private var timer: Timer?

    var isRunning: Bool { status == .connected || status == .connecting || status == .reasserting }

    var statusText: String {
        switch status {
        case .connected: return "tapping"
        case .connecting: return "starting"
        case .reasserting: return "reasserting"
        case .disconnecting: return "stopping"
        case .invalid: return "invalid"
        case .disconnected: return "idle"
        @unknown default: return "?"
        }
    }

    func prepare() async {
        if let manager {
            status = manager.connection.status
            refreshFiles()
            return
        }
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            let manager = managers.first(where: { ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == "com.appleknife.blackbox.tunnel" })
                ?? NETunnelProviderManager()

            if manager.protocolConfiguration == nil {
                let proto = NETunnelProviderProtocol()
                proto.providerBundleIdentifier = "com.appleknife.blackbox.tunnel"
                proto.serverAddress = "10.7.0.1"
                manager.protocolConfiguration = proto
                manager.localizedDescription = "Blackbox tap"
                manager.isEnabled = true
                try await manager.saveToPreferences()
                try await manager.loadFromPreferences()
            }
            self.manager = manager
            status = manager.connection.status

            if observer == nil {
                observer = NotificationCenter.default.addObserver(
                    forName: .NEVPNStatusDidChange, object: manager.connection, queue: .main
                ) { [weak self] _ in
                    Task { @MainActor in
                        self?.status = manager.connection.status
                        self?.refreshFiles()
                    }
                }
            }
        } catch {
            message = error.localizedDescription
        }
        refreshFiles()
    }

    func toggle() {
        guard let manager else {
            Task {
                await prepare()
                toggle()
            }
            return
        }
        do {
            if manager.connection.status == .connected || manager.connection.status == .connecting {
                manager.connection.stopVPNTunnel()
            } else {
                try manager.connection.startVPNTunnel()
                CaseLog.shared.record("NET-04", "Packet tap started")
            }
        } catch {
            message = error.localizedDescription
            Haptics.miss()
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        timer?.invalidate()
    }

    func refreshFiles() {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.appleknife.blackbox") else {
            message = "App Group missing. Check entitlements."
            return
        }
        let folder = container.appendingPathComponent("captures")
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])) ?? []
        files = urls.compactMap { url in
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            return CaptureFile(url: url, size: values?.fileSize ?? 0, date: values?.contentModificationDate ?? Date())
        }
        .sorted { $0.date > $1.date }
    }

    func delete(_ file: CaptureFile) {
        try? FileManager.default.removeItem(at: file.url)
        refreshFiles()
    }

    func beginPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshFiles() }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
}