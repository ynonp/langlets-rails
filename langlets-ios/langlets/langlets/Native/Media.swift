import SwiftUI
import WebKit
import AVFoundation
import Speech

@MainActor
final class NativePronunciation {
    static let shared = NativePronunciation()
    private var playbackID = UUID()
    private var player: AVAudioPlayer?
    private let synthesizer = AVSpeechSynthesizer()
    func play(_ token: NativeToken, language: String, store: NativeStore) async {
        stop()
        let expected = playbackID
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        if let audio = token.audio, let account = store.session?.userId {
            do {
                let url = try await store.disk.audioURL(audio, account: account)
                if !FileManager.default.fileExists(atPath: url.path), store.online { try await store.disk.downloadAudio(audio, account: account) }
                guard expected == playbackID, store.session?.userId == account else { return }
                player = try AVAudioPlayer(contentsOf: url)
                player?.play(); return
            } catch { /* System speech keeps words usable when a download is unavailable. */ }
        }
        guard expected == playbackID else { return }
        speak(token.text, language: language)
    }
    func speak(_ text: String, language: String) {
        stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        synthesizer.speak(utterance)
    }
    func stop() { playbackID = UUID(); player?.stop(); player = nil; synthesizer.stopSpeaking(at: .immediate) }
}

@MainActor
final class NativeSpeech: ObservableObject {
    @Published var text = ""
    @Published var listening = false
    @Published var error: String?
    private let engine = AVAudioEngine()
    private var task: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var installedTap = false
    func start(language: String) async {
        stop()
        let status = await withCheckedContinuation { continuation in SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) } }
        let microphone = await AVAudioApplication.requestRecordPermission()
        guard status == .authorized, microphone else { error = "Allow microphone and speech access in Settings, or skip this exercise."; return }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language)), recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            error = "On-device recognition is unavailable for this language. You can still listen, practise aloud and continue."; return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = true
            self.request = request; text = ""; error = nil
            let input = engine.inputNode
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in request.append(buffer) }
            installedTap = true
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    if let result { self?.text = result.bestTranscription.formattedString }
                    if error != nil || result?.isFinal == true { self?.stop() }
                }
            }
            engine.prepare(); try engine.start(); listening = true
        } catch { self.error = error.localizedDescription; stop() }
    }
    func stop() {
        engine.stop()
        if installedTap { engine.inputNode.removeTap(onBus: 0); installedTap = false }
        request?.endAudio(); task?.cancel(); task = nil; request = nil; listening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

@MainActor
final class NativePlayback: ObservableObject {
    @Published var position: Double = 0
    @Published var failure: String?
    @Published var playing = false
    weak var webView: WKWebView?
    func seek(_ time: Double) { webView?.evaluateJavaScript("command('seek', \(time));") }
    func resume() { webView?.evaluateJavaScript("command('play', 0);") }
    func pause() { webView?.evaluateJavaScript("command('pause', 0);") }
    func pauseAndWait() async {
        pause()
        for _ in 0..<32 {
            if !playing || Task.isCancelled { return }
            try? await Task.sleep(for: .milliseconds(25))
        }
    }
}

// A media-only view. No Rails pages, session cookies, navigation or bridge components.
struct NativeProviderPlayer: UIViewRepresentable {
    @Environment(\.scenePhase) private var scenePhase
    let provider: String
    let videoId: String
    let start: Double
    let end: Double?
    @ObservedObject var playback: NativePlayback
    func makeCoordinator() -> Coordinator { Coordinator(playback: playback) }
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.allowsInlineMediaPlayback = true
        config.userContentController.add(context.coordinator, name: "playback")
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false; view.backgroundColor = .black
        view.scrollView.isScrollEnabled = false
        playback.webView = view
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {
        if scenePhase != .active { playback.pause() }
        let identity = "\(provider):\(videoId):\(start):\(end ?? 0)"
        guard context.coordinator.identity != identity else { return }
        context.coordinator.identity = identity
        guard !videoId.isEmpty, videoId.range(of: "^[a-zA-Z0-9_-]+$", options: .regularExpression) != nil else { return }
        let bounds = "const begin=\(start), finish=\(end ?? 1_000_000);"
        let core = """
        let ready=false, player, timer;
        function report(t){window.webkit.messageHandlers.playback.postMessage({time:t});if(t>=finish){command('pause',0);command('seek',begin)}}
        """
        let script: String
        if provider == "tiktok" {
            script = """
            const frame=document.createElement('iframe');frame.src='https://www.tiktok.com/player/v1/\(videoId)?autoplay=0';frame.allow='autoplay; fullscreen';document.getElementById('player').replaceWith(frame);
            function command(type,value){if(!ready)return;frame.contentWindow.postMessage({'x-tiktok-player':true,type:type==='seek'?'seekTo':type,value:value},'https://www.tiktok.com')}
            window.addEventListener('message',e=>{if(e.origin!=='https://www.tiktok.com'||e.source!==frame.contentWindow)return;const d=e.data;if(!d||!d['x-tiktok-player'])return;if(d.type==='onPlayerReady'){ready=true}if(d.type==='onStateChange'){window.webkit.messageHandlers.playback.postMessage({playing:d.value===1})}if(d.type==='onCurrentTime'){const t=Number(d.value.currentTime);if(t<begin){command('seek',begin)}else report(t)}});
            """
        } else {
            script = """
            function command(type,value){if(!ready)return;if(type==='seek')player.seekTo(value,true);if(type==='pause')player.pauseVideo();if(type==='play')player.playVideo()}
            function onYouTubeIframeAPIReady(){player=new YT.Player('player',{videoId:'\(videoId)',playerVars:{playsinline:1,start:Math.floor(begin),origin:'https://langlets.app'},events:{onStateChange:e=>window.webkit.messageHandlers.playback.postMessage({playing:e.data===1}),onReady:()=>{ready=true;timer=setInterval(()=>{if(player.getPlayerState()===1){const t=player.getCurrentTime();if(t<begin)command('seek',begin);else report(t)}},150)},onError:()=>window.webkit.messageHandlers.playback.postMessage({error:'Video unavailable. You can continue with the transcript.'})}})}
            const s=document.createElement('script');s.src='https://www.youtube.com/iframe_api';document.head.appendChild(s);
            """
        }
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"><meta name="referrer" content="strict-origin-when-cross-origin"><style>html,body{margin:0;background:black;width:100%;height:100%}iframe,#player{border:0;width:100%;height:100%}</style></head><body><div id="player"></div><script>\(bounds)\(core)\(script)</script></body></html>
        """
        view.loadHTMLString(html, baseURL: rootURL)
    }
    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        view.evaluateJavaScript("command('pause',0);clearInterval(timer);")
        view.configuration.userContentController.removeScriptMessageHandler(forName: "playback")
        view.stopLoading()
    }
    final class Coordinator: NSObject, WKScriptMessageHandler {
        let playback: NativePlayback
        var identity = ""
        init(playback: NativePlayback) { self.playback = playback }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let data = message.body as? [String: Any] else { return }
            if let playing = data["playing"] as? Bool { playback.playing = playing }
            if let time = data["time"] as? Double { playback.position = time }
            if let error = data["error"] as? String { playback.failure = error }
        }
    }
}
