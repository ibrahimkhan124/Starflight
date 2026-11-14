import SwiftUI
import AVFoundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Bundled opening film. The native layer aspect-fits the artwork and never adds transport controls.
/// Keep the original title animation as the caller's fallback when the bundled movie is absent.
struct VideoLaunchIntro: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var playback: LaunchFilmPlayback

    init(url: URL, muted: Bool = true, finish: @escaping () -> Void) {
        _playback = StateObject(wrappedValue: LaunchFilmPlayback(url: url, muted: muted, finish: finish))
    }

    var body: some View {
        VStack(spacing: 8) {
            LaunchFilmSurface(player: playback.player)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
                .accessibilityLabel("Starflight opening film")
                .accessibilityIdentifier("Intro video")
            Button { playback.finishOnce() } label: {
                Text("Skip intro")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 88, minHeight: 44)
                    .contentShape(Capsule())
            }
                .buttonStyle(.plain)
                .flightButtonGlass()
                .accessibilityIdentifier("Skip intro")
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            if reduceMotion { playback.finishOnce() }
            else { playback.setActive(scenePhase == .active) }
        }
        .onChange(of: scenePhase) { _, phase in
            playback.setActive(phase == .active && !reduceMotion)
        }
        .onChange(of: reduceMotion) { _, enabled in
            if enabled { playback.finishOnce() }
        }
        .onDisappear { playback.stop() }
    }
}

/// Playback owns only the local film. It never changes the game's audio-session configuration.
@MainActor
final class LaunchFilmPlayback: ObservableObject {
    let player = AVPlayer()
    private let url: URL
    private let finish: () -> Void
    private var statusObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var failureObserver: NSObjectProtocol?
    private var watchdog: Task<Void, Never>?
    private var finished = false
    private var active = false
    private var lastMediaTime: Double = 0
    private var lastAdvanceAt: TimeInterval = 0

    init(url: URL, muted: Bool, finish: @escaping () -> Void) {
        self.url = url
        self.finish = finish
        player.isMuted = muted
        player.actionAtItemEnd = .pause
        player.preventsDisplaySleepDuringVideoPlayback = false
    }

    func setActive(_ value: Bool) {
        guard !finished else { return }
        active = value
        guard value else {
            player.pause()
            watchdog?.cancel(); watchdog = nil
            return
        }
        if player.currentItem == nil { prepare() }
        guard !finished else { return }
        lastMediaTime = player.currentTime().seconds
        lastAdvanceAt = ProcessInfo.processInfo.systemUptime
        player.play()
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
                guard let self, self.active, !self.finished else { return }
                self.checkProgress()
            }
        }
    }

    private func prepare() {
        guard url.isFileURL, FileManager.default.fileExists(atPath: url.path) else {
            finishOnce(); return
        }
        let item = AVPlayerItem(url: url)
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            Task { @MainActor [weak self] in self?.finishOnce() }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                                               object: item, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.finishOnce() }
        }
        failureObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime,
                                                                   object: item, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.finishOnce() }
        }
        player.replaceCurrentItem(with: item)
    }

    private func checkProgress() {
        let now = ProcessInfo.processInfo.systemUptime
        let mediaTime = player.currentTime().seconds
        if mediaTime.isFinite && (!lastMediaTime.isFinite || mediaTime > lastMediaTime + 0.02) {
            lastMediaTime = mediaTime
            lastAdvanceAt = now
        }
        // Local playback should not leave the launch screen stuck if a file is corrupt or decoding stalls.
        if player.status == .failed || player.currentItem?.status == .failed || now - lastAdvanceAt > 10 {
            finishOnce()
        }
    }

    func finishOnce() {
        guard !finished else { return }
        finished = true
        stop()
        finish()
    }

    func stop() {
        active = false
        watchdog?.cancel(); watchdog = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        statusObservation?.invalidate(); statusObservation = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let failureObserver { NotificationCenter.default.removeObserver(failureObserver) }
        endObserver = nil; failureObserver = nil
    }
}

#if canImport(UIKit)
private final class LaunchFilmLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

private struct LaunchFilmSurface: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> LaunchFilmLayerView {
        let view = LaunchFilmLayerView()
        view.backgroundColor = .black
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }
    func updateUIView(_ view: LaunchFilmLayerView, context: Context) { view.playerLayer.player = player }
    static func dismantleUIView(_ view: LaunchFilmLayerView, coordinator: ()) { view.playerLayer.player = nil }
}
#else
private final class LaunchFilmLayerView: NSView {
    let playerLayer = AVPlayerLayer()
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer = playerLayer
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = NSColor.black.cgColor
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private struct LaunchFilmSurface: NSViewRepresentable {
    let player: AVPlayer
    func makeNSView(context: Context) -> LaunchFilmLayerView {
        let view = LaunchFilmLayerView()
        view.playerLayer.player = player
        return view
    }
    func updateNSView(_ view: LaunchFilmLayerView, context: Context) { view.playerLayer.player = player }
    static func dismantleNSView(_ view: LaunchFilmLayerView, coordinator: ()) { view.playerLayer.player = nil }
}
#endif
