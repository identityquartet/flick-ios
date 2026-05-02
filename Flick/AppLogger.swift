import Foundation
import SwiftUI
import UIKit

final class AppLogger {
    static let shared = AppLogger()

    private var entries: [String] = []
    private let maxEntries = 500
    private let queue = DispatchQueue(label: "com.stacknest.flick.logger", qos: .utility)

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
        // Timestamp on calling thread (DateFormatter is thread-safe for reads)
        let line = "[\(dateFormatter.string(from: Date()))] [\(level)] [\(category)] \(message)"
        // Dispatch async so we never block Swift's cooperative thread pool
        queue.async { [weak self] in
            guard let self else { return }
            self.entries.append(line)
            if self.entries.count > self.maxEntries {
                self.entries.removeFirst(self.entries.count - self.maxEntries)
            }
            self.writeToFile(line + "\n")
        }
    }

    private func writeToFile(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        let url = logFileURL
        if FileManager.default.fileExists(atPath: url.path) {
            guard let fh = try? FileHandle(forWritingTo: url) else { return }
            try? fh.seekToEnd()
            try? fh.write(contentsOf: data)
            try? fh.close()
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }

    func exportText() -> String {
        queue.sync { entries.joined(separator: "\n") }
    }

    var entryCount: Int {
        queue.sync { entries.count }
    }

    func clearLogs() {
        let url = logFileURL
        queue.async { [weak self] in
            self?.entries.removeAll()
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
