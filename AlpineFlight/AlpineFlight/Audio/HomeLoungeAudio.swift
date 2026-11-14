import AVFoundation

/// A small original synthesised loop; no streaming, downloaded music or background audio.
@MainActor
final class HomeLoungeAudio {
    private var player:AVAudioPlayer?
    func update(playing:Bool,volume:Float) {
        guard playing,volume>0 else { player?.pause(); return }
        if player == nil { player = try? AVAudioPlayer(data:Self.wave,fileTypeHint:AVFileType.wav.rawValue); player?.numberOfLoops = -1 }
        player?.volume = min(1,max(0,volume))*0.22
        if player?.isPlaying == false { player?.play() }
    }
    func stop() { player?.pause() }
    static let wave:Data = {
        let rate = 16000, count = rate*8
        var pcm = Data(capacity:count*2)
        let notes:[Double] = [164.81,220,261.63,329.63,293.66,261.63,220,196,164.81,246.94,293.66,369.99,329.63,293.66,246.94,196]
        for i in 0..<count {
            let t = Double(i)/Double(rate), beat = Int(t*2), phase = t*2-Double(beat)
            let envelope = min(1,phase*20)*min(1,(1-phase)*6)
            let tone = sin(2*Double.pi*notes[beat%notes.count]*t)*0.22+sin(2*Double.pi*82.405*t)*0.09
            var sample = Int16(max(-1,min(1,tone*envelope))*Double(Int16.max)).littleEndian
            withUnsafeBytes(of:&sample) { pcm.append(contentsOf:$0) }
        }
        var data = Data()
        func word<T:FixedWidthInteger>(_ value:T) { var little = value.littleEndian; withUnsafeBytes(of:&little) { data.append(contentsOf:$0) } }
        data.append(Data("RIFF".utf8)); word(UInt32(36+pcm.count)); data.append(Data("WAVEfmt ".utf8)); word(UInt32(16)); word(UInt16(1)); word(UInt16(1)); word(UInt32(rate)); word(UInt32(rate*2)); word(UInt16(2)); word(UInt16(16)); data.append(Data("data".utf8)); word(UInt32(pcm.count)); data.append(pcm)
        return data
    }()
}
