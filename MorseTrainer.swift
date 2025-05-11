// MorseTrainer.swift
import Foundation
import AVFoundation

class MorseTrainer: ObservableObject {
    @Published var wpm: Double = 20
    @Published var isPlaying: Bool = false
    @Published var showStory: Bool = false
    @Published var storyText: String = ""
    
    private var buffer = SafeCircularBuffer<Character>(capacity: 650) // ~130 words at 5 chars/word
    private var audioEngine: AVAudioEngine
    private var toneNode: AVAudioSourceNode
    private var playerNode: AVAudioPlayerNode
    private var mixer: AVAudioMixerNode
    private var processingTask: Task<Void, Never>?
    private var isRunning: Bool = false
    
    // Morse code mapping (A-Z, 0-9, common punctuation)
    private let morseCode: [Character: String] = [
        "A": ".-", "B": "-...", "C": "-.-.", "D": "-..", "E": ".", "F": "..-.", "G": "--.", "H": "....",
        "I": "..", "J": ".---", "K": "-.-", "L": ".-..", "M": "--", "N": "-.", "O": "---", "P": ".--.",
        "Q": "--.-", "R": ".-.", "S": "...", "T": "-", "U": "..-", "V": "...-", "W": ".--", "X": "-..-",
        "Y": "-.--", "Z": "--..", "0": "-----", "1": ".----", "2": "..---", "3": "...--", "4": "....-",
        "5": ".....", "6": "-....", "7": "--...", "8": "---..", "9": "----.", ".": ".-.-.-", ",": "--..--",
        "?": "..--..", "!": "-.-.--", " ": " "
    ]
    
    init() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        mixer = audioEngine.mainMixerNode
        
        // Initialize toneNode with placeholder
        toneNode = AVAudioSourceNode { _, _, _, _ in noErr }
        
        // Create actual toneNode
        let actualToneNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList in
            self?.renderTone(frameCount: frameCount, audioBufferList: audioBufferList) ?? noErr
        }
        toneNode = actualToneNode
        
        audioEngine.attach(toneNode)
        audioEngine.attach(playerNode)
        audioEngine.connect(toneNode, to: playerNode, format: nil)
        audioEngine.connect(playerNode, to: mixer, format: nil)
        
        try? audioEngine.start()
    }
    
    private func renderTone(frameCount: AVAudioFrameCount, audioBufferList: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let sampleRate: Float = 44100.0
        let frequency: Float = 800.0
        let amplitude: Float = 0.5
        let twoPi = Float.pi * 2.0
        
        for frame in 0..<Int(frameCount) {
            let sampleTime = Float(frame) / sampleRate
            let sample = amplitude * sinf(twoPi * frequency * sampleTime) // Use sinf
            let envelope = applyEnvelope(frame: frame, frameCount: Int(frameCount))
            for buffer in abl {
                let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                buf[frame] = sample * envelope
            }
        }
        return noErr
    }
    
    private func applyEnvelope(frame: Int, frameCount: Int) -> Float {
        let rampLength = 100 // Samples for ramp up/down
        if frame < rampLength {
            return Float(frame) / Float(rampLength)
        } else if frame > frameCount - rampLength {
            return Float(frameCount - frame) / Float(rampLength)
        }
        return 1.0
    }
    
    func loadStory() {
        guard let url = Bundle.main.url(forResource: "story", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            let errorMessage = "ERROR NO STORY.TXT"
            storyText = errorMessage
            Task {
                await buffer.pushBatch(Array(errorMessage.uppercased()))
            }
            return
        }
        storyText = text
        Task {
            await buffer.pushBatch(Array(text.uppercased()))
        }
    }
    
    func startProcessing() {
        isRunning = true
        processingTask = Task {
            while isRunning {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100 ms
                if isPlaying {
                    await processNextCharacter()
                }
            }
        }
    }
    
    func stopProcessing() {
        isRunning = false
        processingTask?.cancel()
        playerNode.stop()
    }
    
    func togglePlayback() {
        isPlaying.toggle()
        if !isPlaying {
            playerNode.stop()
        }
    }
    
    func toggleShowStory() {
        showStory.toggle()
    }
    
    private func processNextCharacter() async {
        guard let char = await buffer.pop() else { return }
        guard let morse = morseCode[char], char != " " else {
            // Pause for space (word gap)
            let unitTime = parisUnitTime(wpm: wpm)
            try? await Task.sleep(nanoseconds: UInt64(unitTime * 7 * 1_000_000_000))
            return
        }
        
        for symbol in morse {
            let unitTime = parisUnitTime(wpm: wpm)
            let duration = symbol == "." ? unitTime : unitTime * 3
            let pause = unitTime
            
            // Play tone
            playerNode.play()
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            playerNode.stop()
            
            // Intra-character pause
            try? await Task.sleep(nanoseconds: UInt64(pause * 1_000_000_000))
        }
        
        // Inter-character pause (3 units total, 1 already in last symbol pause)
        let unitTime = parisUnitTime(wpm: wpm)
        try? await Task.sleep(nanoseconds: UInt64(unitTime * 2 * 1_000_000_000))
    }
    
    private func parisUnitTime(wpm: Double) -> Double {
        // PARIS method: 1 WPM = 50 units/min, 1 unit = 1200/WPM ms
        return 1.2 / wpm
    }
}
