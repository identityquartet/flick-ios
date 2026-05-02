import Foundation
import SwiftUI
import UIKit

final class AppLogger {
    static let shared = AppLogger()

    private var entries: [String] = []
    private let maxEntries = 500
    private let lock = NSLock()

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    private var logFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("flick.log")
    }

    private init() {}

    func log(_ level: String, _ category: String, _ message: String) {
        let line = "[\(dateFormatter.string(from: Date()))] [\(level)] [\(category)] \(message)"
        lock.lock()
        entries.append(line)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        lock.unlock()
        appendToFile(line + "\n")
    }

    private func appendToFile(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        let url = logFileURL
        DispatchQueue.global(qos: .utility).async {
            if FileManager.default.fileExists(atPath: url.path) {
                guard let fh = try? FileHandle(forWritingTo: url) else { return }
                fh.seekToEndOfFile()
                fh.write(data)
                try? fh.close()
            } else {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    func exportText() -> String {
        lock.lock()
        defer { lock.unlock() }
        return entries.joined(separator: "\n")
    }

    var entryCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }

    func clearLogs() {
        lock.lock()
        entries.removeAll()
        lock.unlock()
        let url = logFileURL
        DispatchQueue.global(qos: .utility).async {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

func logDebug(_ category: String, _ message: String) { AppLogger.shared.log("DEBUG", category, message) }
func logInfo(_ category: String, _ message: String)  { AppLogger.shared.log("INFO",  category, message) }
func logWarn(_ category: String, _ message: String)  { AppLogger.shared.log("WARN",  category, message) }
func logError(_ category: String, _ message: String) { AppLogger.shared.log("ERROR", category, message) }

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
