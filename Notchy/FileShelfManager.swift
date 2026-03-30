import AppKit

struct ShelfFile: Identifiable, Codable {
    let id: UUID
    let path: String
    let name: String
    let dateAdded: Date
    let size: Int64

    var url: URL { URL(fileURLWithPath: path) }
    var exists: Bool { FileManager.default.fileExists(atPath: path) }

    var icon: NSImage {
        guard exists else { return NSImage(systemSymbolName: "questionmark.square", accessibilityDescription: nil) ?? NSImage() }
        return NSWorkspace.shared.icon(forFile: path)
    }

    var formattedSize: String {
        if size < 1024 { return "\(size) B" }
        if size < 1_048_576 { return "\(size / 1024) KB" }
        return String(format: "%.1f MB", Double(size) / 1_048_576)
    }

    init(url: URL) {
        self.id = UUID()
        self.path = url.path
        self.name = url.lastPathComponent
        self.dateAdded = Date()
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        self.size = (attrs?[.size] as? Int64) ?? 0
    }
}

@Observable
class FileShelfManager {
    static let shared = FileShelfManager()

    var files: [ShelfFile] = []
    private let maxFiles = 20
    private let maxAge: TimeInterval = 86400 // 24 hours

    var fileCount: Int { files.count }

    private init() {
        loadFromDefaults()
        cleanExpired()
    }

    func addFiles(_ urls: [URL]) {
        for url in urls {
            // Avoid duplicates
            guard !files.contains(where: { $0.path == url.path }) else { continue }
            files.insert(ShelfFile(url: url), at: 0)
        }
        // Trim to max
        if files.count > maxFiles {
            files = Array(files.prefix(maxFiles))
        }
        saveToDefaults()
    }

    func removeFile(_ file: ShelfFile) {
        files.removeAll { $0.id == file.id }
        saveToDefaults()
    }

    func clearAll() {
        files.removeAll()
        saveToDefaults()
    }

    func openFile(_ file: ShelfFile) {
        NSWorkspace.shared.open(file.url)
    }

    private func cleanExpired() {
        let cutoff = Date().addingTimeInterval(-maxAge)
        files.removeAll { $0.dateAdded < cutoff || !$0.exists }
        saveToDefaults()
    }

    // MARK: - Persistence

    private func saveToDefaults() {
        if let data = try? JSONEncoder().encode(files) {
            UserDefaults.standard.set(data, forKey: "fileShelf")
        }
    }

    private func loadFromDefaults() {
        guard let data = UserDefaults.standard.data(forKey: "fileShelf"),
              let saved = try? JSONDecoder().decode([ShelfFile].self, from: data) else { return }
        files = saved
    }
}
