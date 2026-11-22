import Foundation
import Network

struct Announcement: Identifiable, Hashable {
    let name: String
    let type: String

    var id: String { "\(type)-\(name)" }
}

@MainActor
final class AnnouncementBrowser: ObservableObject {
    static let types = [
        "_http._tcp", "_https._tcp", "_ssh._tcp", "_airplay._tcp", "_raop._tcp",
        "_googlecast._tcp", "_ipp._tcp", "_printer._tcp", "_spotify-connect._tcp",
        "_companion-link._tcp"
    ]

    @Published private(set) var found: [Announcement] = []
    @Published private(set) var isBrowsing = false
    @Published var message: String?

    private var browsers: [NWBrowser] = []
    private let queue = DispatchQueue(label: "com.appleknife.blackbox.bonjour")

    func start() {
        guard !isBrowsing else { return }
        isBrowsing = true
        message = nil
        found = []
        CaseLog.shared.record("NET-02", "Browsing \(Self.types.count) mDNS service types")

        for type in Self.types {
            let parameters = NWParameters.tcp
            parameters.includePeerToPeer = true
            let browser = NWBrowser(for: .bonjour(type: type, domain: nil), using: parameters)
            browser.stateUpdateHandler = { [weak self] state in
                if case .failed(let error) = state {
                    Task { @MainActor in self?.message = error.localizedDescription }
                }
            }
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                Task { @MainActor in self?.absorb(results, type: type) }
            }
            browser.start(queue: queue)
            browsers.append(browser)
        }
    }

    func stop() {
        guard isBrowsing else { return }
        browsers.forEach { $0.cancel() }
        browsers = []
        isBrowsing = false
        CaseLog.shared.record("NET-02", "Stopped browsing with \(found.count) announcements")
    }

    private func absorb(_ results: Set<NWBrowser.Result>, type: String) {
        for result in results {
            guard case let .service(name, _, _, _) = result.endpoint else { continue }
            let item = Announcement(name: name, type: type)
            guard !found.contains(item) else { continue }
            found.append(item)
            Haptics.tap()
            CaseLog.shared.finding("NET-02", "\(name) announces \(type)", fields: ["service": name, "type": type])
        }
    }
}