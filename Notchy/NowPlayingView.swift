import SwiftUI
import Combine

// MARK: - Left wing: track info + equalizer

struct NowPlayingInfoView: View {
    private var manager: NowPlayingManager { .shared }

    var body: some View {
        HStack(spacing: 6) {
            // Equalizer bars
            AudioBarsView(isPlaying: manager.isPlaying)
                .frame(width: 12, height: 16)

            // Track info — two lines
            VStack(alignment: .leading, spacing: 1) {
                MarqueeText(text: manager.trackTitle, font: .system(size: 10.5, weight: .semibold), speed: 30)
                    .foregroundStyle(.white)

                if !manager.artistName.isEmpty {
                    MarqueeText(text: manager.artistName, font: .system(size: 9, weight: .medium), speed: 25)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Marquee (scrolling) text

struct MarqueeText: View {
    let text: String
    var font: Font = .system(size: 10.5, weight: .semibold)
    var speed: CGFloat = 30 // points per second

    @State private var offset: CGFloat = 0
    @State private var timer: Timer?
    @State private var delayWork: DispatchWorkItem?
    @State private var scrollID = UUID() // tracks current scroll cycle

    private let gap: CGFloat = 40
    private let pauseDuration: TimeInterval = 2.0

    var body: some View {
        let measuredSize = measureText(text, font: font)

        GeometryReader { geo in
            let scrolling = measuredSize.width > geo.size.width + 2

            if scrolling {
                HStack(spacing: gap) {
                    Text(text).font(font).lineLimit(1).fixedSize()
                    Text(text).font(font).lineLimit(1).fixedSize()
                }
                .offset(x: offset)
                .onAppear {
                    startScrolling(textWidth: measuredSize.width)
                }
                .onChange(of: text) {
                    offset = 0
                    startScrolling(textWidth: measureText(text, font: font).width)
                }
            } else {
                Text(text).font(font).lineLimit(1)
                    .onAppear { stopAll() }
            }
        }
        .frame(height: measuredSize.height > 0 ? measuredSize.height : 14)
        .clipped()
        .onDisappear { stopAll() }
    }

    private func measureText(_ string: String, font: Font) -> CGSize {
        let nsFont: NSFont
        if font == .system(size: 10.5, weight: .semibold) {
            nsFont = NSFont.systemFont(ofSize: 10.5, weight: .semibold)
        } else if font == .system(size: 9, weight: .medium) {
            nsFont = NSFont.systemFont(ofSize: 9, weight: .medium)
        } else {
            nsFont = NSFont.systemFont(ofSize: 11)
        }
        let attributes: [NSAttributedString.Key: Any] = [.font: nsFont]
        return (string as NSString).size(withAttributes: attributes)
    }

    private func startScrolling(textWidth: CGFloat) {
        stopAll()
        let id = UUID()
        scrollID = id
        let scrollDistance = textWidth + gap
        let stepInterval: TimeInterval = 1.0 / 60.0
        let stepSize = speed * stepInterval

        let work = DispatchWorkItem { [self] in
            guard scrollID == id else { return }
            self.timer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { _ in
                guard self.scrollID == id else {
                    self.timer?.invalidate()
                    return
                }
                self.offset -= stepSize
                if self.offset <= -scrollDistance {
                    self.offset = 0
                    self.timer?.invalidate()
                    self.timer = nil
                    self.startScrolling(textWidth: textWidth)
                }
            }
        }
        delayWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + pauseDuration, execute: work)
    }

    private func stopAll() {
        delayWork?.cancel()
        delayWork = nil
        timer?.invalidate()
        timer = nil
        offset = 0
        scrollID = UUID()
    }
}

// MARK: - Right wing: transport controls

struct NowPlayingControlsView: View {
    let isHovering: Bool
    private var manager: NowPlayingManager { .shared }

    var body: some View {
        HStack(spacing: 14) {
            controlButton("backward.fill", size: 10) { manager.previousTrack() }

            controlButton(
                manager.isPlaying ? "pause.fill" : "play.fill",
                size: 13
            ) { manager.togglePlayPause() }

            controlButton("forward.fill", size: 10) { manager.nextTrack() }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func controlButton(_ icon: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Image(systemName: icon)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
            .onTapGesture { action() }
    }
}

// MARK: - Animated equalizer bars

struct AudioBarsView: View {
    let isPlaying: Bool

    @State private var heights: [CGFloat] = [0.3, 0.5, 0.4, 0.6]
    private let barCount = 4
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 1.5) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.6)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 2, height: isPlaying ? heights[i] * 14 : 2)
            }
        }
        .frame(height: 14, alignment: .bottom)
        .onReceive(timer) { _ in
            guard isPlaying else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                heights = (0..<barCount).map { _ in CGFloat.random(in: 0.15...1.0) }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isPlaying)
    }
}

