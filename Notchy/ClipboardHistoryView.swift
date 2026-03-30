import SwiftUI

struct ClipboardHistoryView: View {
    private var manager: ClipboardManager { .shared }
    @State private var flashedId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Text("Clipboard")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                if !manager.items.isEmpty {
                    Text("Clear")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                        .contentShape(Rectangle())
                        .onTapGesture { manager.clearAll() }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)

            if manager.items.isEmpty {
                Text("No items yet")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.2))
                    .frame(height: 28)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(manager.items) { item in
                            clipboardCard(item)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
                }
            }
        }
    }

    private func clipboardCard(_ item: ClipboardItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: item.isFile ? "doc.fill" : "text.alignleft")
                    .font(.system(size: 7))
                    .foregroundStyle(.white.opacity(0.3))
                Text(item.relativeTime)
                    .font(.system(size: 7, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
            }

            Text(item.preview)
                .font(.system(size: 9, weight: .regular))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(2)
                .frame(width: 120, alignment: .leading)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(flashedId == item.id ? Color.green.opacity(0.2) : Color.white.opacity(0.06))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            manager.restore(item)
            withAnimation(.easeOut(duration: 0.15)) { flashedId = item.id }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation { flashedId = nil }
            }
        }
    }
}
