import SwiftUI

struct FileShelfView: View {
    private var manager: FileShelfManager { .shared }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "tray.full")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Text("File Shelf")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                if !manager.files.isEmpty {
                    Text("Clear")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                        .contentShape(Rectangle())
                        .onTapGesture { manager.clearAll() }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)

            if manager.files.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.2))
                    Text("Drop files on the notch")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.2))
                }
                .frame(height: 36)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(manager.files) { file in
                            fileCard(file)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
                }
            }
        }
    }

    private func fileCard(_ file: ShelfFile) -> some View {
        VStack(spacing: 3) {
            ZStack(alignment: .topTrailing) {
                // File icon
                Image(nsImage: file.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)

                // Remove button
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
                    .offset(x: 4, y: -4)
                    .contentShape(Circle())
                    .onTapGesture { manager.removeFile(file) }
            }

            Text(file.name)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
                .frame(width: 56)

            Text(file.formattedSize)
                .font(.system(size: 7))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.06))
        )
        .contentShape(Rectangle())
        .onDrag {
            NSItemProvider(object: file.url as NSURL)
        }
        .onTapGesture { manager.openFile(file) }
    }
}
