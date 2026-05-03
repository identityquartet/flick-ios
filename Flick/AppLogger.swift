import Foundation

@MainActor
final class AppLogger {
    static let shared = AppLogger()

    private var entries: [String] = []
    private let maxEntries = 500

    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    private init() {}

    func log(_ level: String, _ category: String, _ message: String) {
        let line = "[\(formatter.string(from: Date()))] [\(level)] [\(category)] \(message)"
        entries.append(line)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    var entryCount: Int { entries.count }
    func exportText() -> String { entries.joined(separator: "\n") }
    func clearLogs() { entries.removeAll() }
}

func logDebug(_ category: String, _ message: String) { Task { @MainActor in AppLogger.shared.log("DEBUG", category, message) } }
func logInfo(_ category: String, _ message: String)  { Task { @MainActor in AppLogger.shared.log("INFO",  category, message) } }
func logWarn(_ category: String, _ message: String)  { Task { @MainActor in AppLogger.shared.log("WARN",  category, message) } }
func logError(_ category: String, _ message: String) { Task { @MainActor in AppLogger.shared.log("ERROR", category, message) } }
