import Foundation

enum Recon {
    static func dns(_ domain: String, type: String) async throws -> String {
        var components = URLComponents(string: "https://cloudflare-dns.com/dns-query")!
        components.queryItems = [
            URLQueryItem(name: "name", value: domain),
            URLQueryItem(name: "type", value: type)
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 15
        request.setValue("application/dns-json", forHTTPHeaderField: "accept")
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8) ?? "unreadable"
        }
        let status = object["Status"] as? Int ?? -1
        let answers = (object["Answer"] as? [[String: Any]]) ?? []
        if answers.isEmpty {
            return status == 0 ? "no records for \(type)" : "rcode \(status)"
        }
        return answers.map { row in
            let name = row["name"] as? String ?? ""
            let data = row["data"] as? String ?? ""
            let ttl = row["TTL"] as? Int ?? 0
            return "\(name)  \(data)  ttl \(ttl)"
        }.joined(separator: "\n")
    }

    static func rdap(_ domain: String) async throws -> String {
        guard let url = URL(string: "https://rdap.org/domain/\(domain)") else { return "bad domain" }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/rdap+json", forHTTPHeaderField: "accept")
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8) ?? "unreadable"
        }
        var lines: [String] = []
        if let handle = object["handle"] as? String { lines.append("handle \(handle)") }
        if let status = object["status"] as? [String] { lines.append("status \(status.joined(separator: ", "))") }
        if let events = object["events"] as? [[String: Any]] {
            for event in events {
                let action = event["eventAction"] as? String ?? "?"
                let date = event["eventDate"] as? String ?? "?"
                lines.append("\(action)  \(date)")
            }
        }
        if let nameservers = object["nameservers"] as? [[String: Any]] {
            let hosts = nameservers.compactMap { $0["ldhName"] as? String }
            if !hosts.isEmpty { lines.append("nameservers \(hosts.joined(separator: ", "))") }
        }
        return lines.isEmpty ? "no summary fields" : lines.joined(separator: "\n")
    }

    static func certificates(_ domain: String) async throws -> String {
        guard let url = URL(string: "https://crt.sh/?q=%25.\(domain)&output=json") else { return "bad domain" }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return String(data: data, encoding: .utf8)?.prefix(400).description ?? "unreadable"
        }
        var seen = Set<String>()
        for row in rows {
            let name = row["name_value"] as? String ?? ""
            name.split(separator: "\n").forEach { seen.insert(String($0)) }
        }
        let sorted = seen.sorted()
        return sorted.isEmpty ? "no names" : "\(rows.count) certs\n\n" + sorted.prefix(80).joined(separator: "\n")
    }

    static func headers(_ target: String) async throws -> String {
        var text = target.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.contains("://") { text = "https://" + text }
        guard let url = URL(string: text) else { return "bad URL" }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 12
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return "no HTTP response" }
        let fields = http.allHeaderFields
            .map { "\($0.key): \($0.value)" }
            .sorted()
            .joined(separator: "\n")
        return "HTTP \(http.statusCode)\n\(fields)"
    }
}
