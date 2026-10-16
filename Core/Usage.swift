import Foundation

public enum Provider: String, CaseIterable, Codable, Identifiable, Sendable {
    case codex, claude
    public var id: String { rawValue }
    public var title: String { self == .codex ? "Codex" : "Claude" }
    public var subtitle: String { self == .codex ? "Your ChatGPT subscription" : "Your Claude subscription" }
    public var host: String { self == .codex ? "chatgpt.com" : "claude.ai" }
    public var usageURL: URL {
        URL(string: self == .codex ? "https://chatgpt.com/codex/settings/usage" : "https://claude.ai/settings/usage")!
    }
    public var storageID: UUID {
        UUID(uuidString: self == .codex ? "E3737C63-D4B2-4366-B66C-0C9F9483A001" : "E3737C63-D4B2-4366-B66C-0C9F9483A002")!
    }
}

public struct UsageWindow: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let usedPercent: Double
    public let resetsAt: Date?

    public func remainingPercent(at now: Date = Date()) -> Double? {
        if let resetsAt, resetsAt <= now { return nil }
        return max(0, min(100, 100 - usedPercent))
    }
}

public struct UsageSnapshot: Codable, Sendable, Equatable {
    public let provider: Provider
    public let plan: String?
    public let windows: [UsageWindow]
    public let fetchedAt: Date

    public func isStale(at now: Date = Date()) -> Bool {
        now.timeIntervalSince(fetchedAt) > 900 || windows.contains { $0.resetsAt.map { $0 <= now } ?? false }
    }
}

public enum UsageParseError: LocalizedError {
    case unexpectedResponse, noUsage
    public var errorDescription: String? {
        switch self {
        case .unexpectedResponse: "The provider returned an unfamiliar response. Open its usage page and try again."
        case .noUsage: "No subscription usage windows were reported. Check the signed-in account and plan on the provider’s usage page."
        }
    }
}

public enum UsageParser {
    public static func parse(_ data: Data, provider: Provider, now: Date = Date()) throws -> UsageSnapshot {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageParseError.unexpectedResponse
        }
        var windows: [UsageWindow] = []
        if provider == .codex {
            appendCodex(object["rate_limit"] as? [String: Any], prefix: "main", name: nil, into: &windows)
            for (index, item) in ((object["additional_rate_limits"] as? [[String: Any]]) ?? []).enumerated() {
                let name = item["limit_name"] as? String ?? item["metered_feature"] as? String ?? "Additional limit"
                appendCodex(item["rate_limit"] as? [String: Any], prefix: "additional-\(index)", name: name, into: &windows)
            }
        } else {
            let keys = ["five_hour", "seven_day"] + object.keys.filter { $0.hasPrefix("seven_day_") }.sorted()
            for key in keys {
                guard let value = object[key] as? [String: Any], let percent = percentage(value["utilization"]) else { continue }
                let title: String
                if key == "five_hour" { title = "5-hour limit" }
                else if key == "seven_day" { title = "Weekly · all models" }
                else { title = "Weekly · " + key.replacingOccurrences(of: "seven_day_", with: "").replacingOccurrences(of: "_", with: " ").capitalized }
                windows.append(UsageWindow(id: key, title: title, usedPercent: percent, resetsAt: date(value["resets_at"])))
            }
        }
        guard !windows.isEmpty else { throw UsageParseError.noUsage }
        return UsageSnapshot(provider: provider, plan: object["plan_type"] as? String, windows: windows, fetchedAt: now)
    }

    private static func appendCodex(_ rate: [String: Any]?, prefix: String, name: String?, into windows: inout [UsageWindow]) {
        guard let rate else { return }
        for key in ["primary_window", "secondary_window"] {
            guard let value = rate[key] as? [String: Any], let percent = percentage(value["used_percent"]) else { continue }
            let seconds = (value["limit_window_seconds"] as? NSNumber)?.intValue
            let duration: String
            switch seconds {
            case 604800: duration = "Weekly limit"
            case let seconds? where seconds > 0 && seconds % 3600 == 0: duration = "\(seconds / 3600)-hour limit"
            case let seconds? where seconds > 0 && seconds % 60 == 0: duration = "\(seconds / 60)-minute limit"
            default: duration = key == "primary_window" ? "Primary limit" : "Secondary limit"
            }
            windows.append(UsageWindow(id: "\(prefix)-\(key)", title: name.map { "\($0) · \(duration)" } ?? duration, usedPercent: percent, resetsAt: date(value["reset_at"])))
        }
    }

    private static func percentage(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let result = number.doubleValue
        return result.isFinite && (0...100).contains(result) ? result : nil
    }

    private static func date(_ value: Any?) -> Date? {
        if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue > 0 {
            return Date(timeIntervalSince1970: number.doubleValue)
        }
        guard let text = value as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let result = formatter.date(from: text) { return result }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }
}

import CoreFoundation
