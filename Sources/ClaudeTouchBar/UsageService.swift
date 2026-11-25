import Foundation

struct UsageWindow: Equatable {
    let percent: Double
    let resetsAt: Date?
}

struct UsageSnapshot: Equatable {
    let session: UsageWindow?
    let weekly: UsageWindow?
    let fetchedAt: Date

    var peakPercent: Double {
        max(session?.percent ?? 0, weekly?.percent ?? 0)
    }
}

enum UsageError: LocalizedError {
    case noCredentials
    case unauthorized
    case http(Int)
    case rateLimited(retryAfter: TimeInterval?)
    case decoding

    var errorDescription: String? {
        switch self {
        case .noCredentials: return "Credenciais do Claude Code não encontradas no Keychain"
        case .unauthorized: return "Token expirado — abra o Claude Code para renovar"
        case .http(let code): return "Erro HTTP \(code)"
        case .rateLimited: return "Muitas consultas à API"
        case .decoding: return "Resposta inesperada da API"
        }
    }
}

final class UsageService {
    private let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private let keychainService = "Claude Code-credentials"

    func fetch() async throws -> UsageSnapshot {
        guard let token = readAccessToken() else { throw UsageError.noCredentials }

        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 401 || http.statusCode == 403 { throw UsageError.unauthorized }
            if http.statusCode == 429 {
                let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
                throw UsageError.rateLimited(retryAfter: retryAfter)
            }
            guard (200..<300).contains(http.statusCode) else { throw UsageError.http(http.statusCode) }
        }
        return try Self.parse(data)
    }

    static func parse(_ data: Data) throws -> UsageSnapshot {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageError.decoding
        }
        func window(_ key: String) -> UsageWindow? {
            guard let obj = json[key] as? [String: Any],
                  let util = (obj["utilization"] as? NSNumber)?.doubleValue else { return nil }
            return UsageWindow(percent: util, resetsAt: parseDate(obj["resets_at"] as? String))
        }
        let snapshot = UsageSnapshot(session: window("five_hour"),
                                     weekly: window("seven_day"),
                                     fetchedAt: Date())
        if snapshot.session == nil && snapshot.weekly == nil { throw UsageError.decoding }
        return snapshot
    }

    static func parseDate(_ string: String?) -> Date? {
        guard var s = string else { return nil }
        if let dot = s.firstIndex(of: ".") {
            let rest = s[dot...]
            if let tz = rest.firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }) {
                s = String(s[..<dot]) + String(s[tz...])
            } else {
                s = String(s[..<dot])
            }
        }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    private func readAccessToken() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", keychainService, "-w"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else { return nil }
        return token
    }
}
