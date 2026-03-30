import AppKit

struct ClipboardItem: Identifiable {
    let id = UUID()
    let content: String
    let date: Date
    let isFile: Bool

    var preview: String {
        let clean = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.count <= 60 { return clean }
        return String(clean.prefix(57)) + "..."
    }

    var relativeTime: String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 5 { return "now" }
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        return "\(seconds / 3600)h"
    }
}

@Observable
class ClipboardManager {
    static let shared = ClipboardManager()

    var items: [ClipboardItem] = []
    private var lastChangeCount: Int = 0
    private var pollTimer: Timer?
    private let maxItems = 30

    var itemCount: Int { items.count }

    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }

    private func checkForChanges() {
        let current = NSPasteboard.general.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        let pb = NSPasteboard.general

        // Try file URLs first
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            let paths = urls.map(\.path).joined(separator: "\n")
            addItem(content: paths, isFile: true)
            return
        }

        // Then plain text
        if let text = pb.string(forType: .string), !text.isEmpty {
            // Avoid duplicating the most recent item
            if let last = items.first, last.content == text { return }
            addItem(content: text, isFile: false)
        }
    }

    private func addItem(content: String, isFile: Bool) {
        let item = ClipboardItem(content: content, date: Date(), isFile: isFile)
        items.insert(item, at: 0)
        if items.count > maxItems {
            items.removeLast()
        }
    }

    func restore(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(item.content, forType: .string)
        lastChangeCount = pb.changeCount // prevent re-capturing
    }

    func remove(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
    }

    func clearAll() {
        items.removeAll()
    }
}
