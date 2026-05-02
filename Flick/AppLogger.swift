import Foundation

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
        // Append on the main queue — reads from UI always happen on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.entries.append(line)
            if self.entries.count > self.maxEntries {
                self.entries.removeFirst(self.entries.count - self.maxEntries)
            }
        }
    }

    var entryCount: Int { entries.count }
    func exportText() -> String { entries.joined(separator: "\n") }
    func clearLogs() { entries.removeAll() }
}

func logDebug(_ category: String, _ message: String) { AppLogger.shared.log("DEBUG", category, message) }
func logInfo(_ category: String, _ message: String)  { AppLogger.shared.log("INFO",  category, message) }
func logWarn(_ category: String, _ message: String)  { AppLogger.shared.log("WARN",  category, message) }
func logError(_ category: String, _ message: String) { AppLogger.shared.log("ERROR", category, message) }
