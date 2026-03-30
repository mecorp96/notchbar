import AppKit

@Observable
class NowPlayingManager {
    static let shared = NowPlayingManager()

    var trackTitle: String = ""
    var artistName: String = ""
    var isPlaying: Bool = false
    var hasNowPlayingInfo: Bool = false

    var displayText: String {
        if trackTitle.isEmpty && artistName.isEmpty { return "" }
        if artistName.isEmpty { return trackTitle }
        return "\(trackTitle) — \(artistName)"
    }

    private var pollTimer: Timer?

    private init() {
        fetchNowPlayingInfo()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.fetchNowPlayingInfo()
        }
    }

    // MARK: - Fetch Now Playing (Safari/YouTube via AppleScript + JS)

    private func fetchNowPlayingInfo() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let script = """
            tell application "System Events"
                if not (exists process "Safari") then return "null"
            end tell
            tell application "Safari"
                if (count of windows) is 0 then return "null"
                set tabURL to URL of current tab of front window
                if tabURL does not contain "youtube.com/watch" then return "null"
                set jsResult to do JavaScript "
                    (function() {
                        var v = document.querySelector('video');
                        if (!v) return JSON.stringify({playing: false, title: '', artist: '', volume: 1});
                        var title = document.querySelector('h1.ytd-watch-metadata yt-formatted-string');
                        var channel = document.querySelector('#channel-name yt-formatted-string a');
                        return JSON.stringify({
                            playing: !v.paused,
                            title: title ? title.textContent : document.title.replace(' - YouTube', ''),
                            artist: channel ? channel.textContent : '',
                            volume: v.volume
                        });
                    })()
                " in current tab of front window
                return jsResult
            end tell
            """

            var error: NSDictionary?
            let appleScript = NSAppleScript(source: script)
            let result = appleScript?.executeAndReturnError(&error)

            DispatchQueue.main.async {
                guard let self else { return }
                guard let jsonString = result?.stringValue,
                      jsonString != "null",
                      let data = jsonString.data(using: .utf8),
                      let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    if self.hasNowPlayingInfo {
                        self.trackTitle = ""
                        self.artistName = ""
                        self.isPlaying = false
                        self.hasNowPlayingInfo = false
                        NotificationCenter.default.post(name: .NotchyNotchStatusChanged, object: nil)
                    }
                    return
                }

                let title = info["title"] as? String ?? ""
                let artist = info["artist"] as? String ?? ""
                let playing = info["playing"] as? Bool ?? false

                let wasAvailable = self.hasNowPlayingInfo
                self.trackTitle = title
                self.artistName = artist
                self.isPlaying = playing
                self.hasNowPlayingInfo = !title.isEmpty

                if wasAvailable != self.hasNowPlayingInfo {
                    NotificationCenter.default.post(name: .NotchyNotchStatusChanged, object: nil)
                }
            }
        }
    }

    // MARK: - Playback Controls (Safari/YouTube via JS)

    func togglePlayPause() {
        runYouTubeJS("document.querySelector('video')?.paused ? document.querySelector('video').play() : document.querySelector('video').pause()")
    }

    func nextTrack() {
        runYouTubeJS("document.querySelector('.ytp-next-button')?.click()")
    }

    func previousTrack() {
        // YouTube has no native "previous" button; seek to start or go back in history
        runYouTubeJS("var v = document.querySelector('video'); if (v) { if (v.currentTime > 3) { v.currentTime = 0; } else { history.back(); } }")
    }

    private func runYouTubeJS(_ js: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let escaped = js.replacingOccurrences(of: "\"", with: "\\\"")
            let script = """
            tell application "Safari"
                if (count of windows) > 0 then
                    set tabURL to URL of current tab of front window
                    if tabURL contains "youtube.com" then
                        do JavaScript "\(escaped)" in current tab of front window
                    end if
                end if
            end tell
            """
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
        }
        // Refresh state quickly after action
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.fetchNowPlayingInfo()
        }
    }

}
