import Foundation

struct CaseEntry: Identifiable, Codable {
    enum Kind: String, Codable {
        case observation
        case finding
        case note
        case error
    }

    let id: UUID
    let date: Date
    let module: String
    let kind: Kind
    let message: String
    var fields: [String: String]

    init(module: String, kind: Kind, message: String, fields: [String: String] = [:]) {
        id = UUID()
        date = Date()
        self.module = module
        self.kind = kind
        self.message = message
        self.fields = fields
    }
}

@MainActor
final class CaseLog: ObservableObject {
    static let shared = CaseLog()

    @Published private(set) var entries: [CaseEntry] = []
    @Published private(set) var caseNumber: String = CaseLog.makeCaseNumber()

    private var handle: FileHandle?
    private let limit = 800

    var fileURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("case-\(caseNumber).jsonl")
    }

    private static func makeCaseNumber() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMdd-HHmm"
        return formatter.string(from: Date())
    }

    func record(_ module: String, kind: CaseEntry.Kind = .observation,
                _ message: String, fields: [String: String] = [:]) {
        let entry = CaseEntry(module: module, kind: kind, message: message, fields: fields)
        entries.append(entry)
        if entries.count > limit { entries.removeFirst(entries.count - limit) }
        append(entry)
    }

    func finding(_ module: String, _ message: String, fields: [String: String] = [:]) {
        record(module, kind: .finding, message, fields: fields)
    }

    var summary: (findings: Int, hosts: Int, observations: Int) {
        (
            entries.filter { $0.kind == .finding }.count,
            Set(entries.compactMap { $0.fields["host"] }).count,
            entries.count
        )
    }

    private func append(_ entry: CaseEntry) {
        guard let data = try? JSONEncoder.caseEncoder.encode(entry) else { return }
        if handle == nil { openFile() }
        guard let handle else { return }
        try? handle.write(contentsOf: data + Data("\n".utf8))
    }

    private func openFile() {
        let url = fileURL
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        handle = try? FileHandle(forWritingTo: url)
        try? handle?.seekToEnd()
    }

    func clear() {
        entries.removeAll()
        handle = nil
        caseNumber = Self.makeCaseNumber()
    }

    func exportJSON() -> Data {
        (try? JSONEncoder.caseEncoder.encode(entries)) ?? Data("[]".utf8)
    }
}

extension JSONEncoder {
    static var caseEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}