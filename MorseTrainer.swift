import Foundation
import AVFoundation
import os.log

/* 5/12/25
 Initializing MorseTrainer
 AVAudioSession configured successfully
 toneNode successfully attached and connected
 AudioEngine started successfully
 */

class MorseTrainer: ObservableObject {
    @Published var wpm: Double = 20
    @Published var isPlaying: Bool = false
    @Published var showStory: Bool = false
    @Published var storyText: String = ""

    private var buffer = SafeCircularBuffer<Character>(capacity: 650)
    private var audioEngine: AVAudioEngine
    private var toneNode: AVAudioSourceNode?
    private var playerNode: AVAudioPlayerNode
    private var mixer: AVAudioMixerNode
    private var processingTask: Task<Void, Never>?
    private var isRunning: Bool = false

    private let logger = Logger(subsystem: "com.speechtomorse", category: "morse")

    private let morseCode: [Character: String] = [
        "A": ".-", "B": "-...", "C": "-.-.", "D": "-..", "E": ".", "F": "..-.", "G": "--.", "H": "....",
        "I": "..", "J": ".---", "K": "-.-", "L": ".-..", "M": "--", "N": "-.", "O": "---", "P": ".--.",
        "Q": "--.-", "R": ".-.", "S": "...", "T": "-", "U": "..-", "V": "...-", "W": ".--", "X": "-..-",
        "Y": "-.--", "Z": "--..", "0": "-----", "1": ".----", "2": "..---", "3": "...--", "4": "....-",
        "5": ".....", "6": "-....", "7": "--...", "8": "---..", "9": "----.", ".": ".-.-.-", ",": "--..--",
        "?": "..--..", "!": "-.-.--", " ": " "
    ]

    init() {
        logger.log("Initializing MorseTrainer")

        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        mixer = audioEngine.mainMixerNode

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            logger.log("AVAudioSession configured successfully")
        } catch {
            logger.error("Failed to configure AVAudioSession: \(error.localizedDescription)")
        }

        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 1)!

        toneNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList in
            guard let self = self else {
                self?.logger.error("toneNode closure failed due to weak reference")
                return noErr
            }

            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let sampleRate: Float = 44100.0
            let frequency: Float = 800.0
            let amplitude: Float = 0.5
            let twoPi = Float.pi * 2.0

            for frame in 0..<Int(frameCount) {
                let sampleTime = Float(frame) / sampleRate
                let sample = amplitude * sinf(twoPi * frequency * sampleTime)
                let envelope = self.applyEnvelope(frame: frame, frameCount: Int(frameCount))
                for buffer in abl {
                    let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                    buf[frame] = sample * envelope
                }
            }
            return noErr
        }

        if let toneNode = toneNode {
            audioEngine.attach(toneNode)
            audioEngine.connect(toneNode, to: mixer, format: audioFormat)
            logger.log("toneNode successfully attached and connected")
        } else {
            logger.error("toneNode initialization failed!")
        }

        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: mixer, format: audioFormat)

        do {
            try audioEngine.start()
            logger.log("AudioEngine started successfully")
        } catch {
            logger.error("Failed to start AudioEngine: \(error.localizedDescription)")
            fatalError("Could not start AudioEngine: \(error)")
        }
    }

    private func applyEnvelope(frame: Int, frameCount: Int) -> Float {
        let rampLength = 100
        if frame < rampLength {
            return Float(frame) / Float(rampLength)
        } else if frame > frameCount - rampLength {
            return Float(frameCount - frame) / Float(rampLength)
        }
        return 1.0
    }

    func loadStory() {
        logger.log("Loading story.txt")
        guard let url = Bundle.main.url(forResource: "story", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            let errorMessage = "ERROR NO STORY.TXT"
            self.storyText = errorMessage
            logger.error("Failed to load story.txt")
            Task {
                await buffer.pushBatch(Array(errorMessage.uppercased()))
            }
            return
        }
        self.storyText = text
        logger.log("Successfully loaded story.txt")
        Task {
            await buffer.pushBatch(Array(text.uppercased()))
        }
    }

    func startProcessing() {
        isRunning = true
        logger.log("Starting processing task")
        processingTask = Task {
            while isRunning {
                try? await Task.sleep(nanoseconds: 100_000_000)
                if self.isPlaying {
                    await processNextCharacter()
                }
            }
        }
    }

    func stopProcessing() {
        isRunning = false
        processingTask?.cancel()
        playerNode.stop()
        logger.log("Stopped processing task")
    }

    func togglePlayback() {
        isPlaying.toggle()
        logger.log("Playback toggled: \(self.isPlaying)")
        if !isPlaying {
            playerNode.stop()
            logger.log("Playback stopped")
        } else {
            logger.log("Playback started")
        }
    }

    func toggleShowStory() {
        showStory.toggle()
        logger.log("Show story toggled to: \(self.showStory)")
    }

    private func processNextCharacter() async {
        guard let char = await buffer.pop() else {
            logger.log("Buffer empty, no character to process")
            return
        }
        guard let morse = morseCode[char], char != " " else {
            let unitTime = parisUnitTime(wpm: wpm)
            try? await Task.sleep(nanoseconds: UInt64(unitTime * 7 * 1_000_000_000))
            logger.log("Processed space character")
            return
        }

        for symbol in morse {
            let unitTime = parisUnitTime(wpm: wpm)
            let duration = symbol == "." ? unitTime : unitTime * 3
            let pause = unitTime

            playerNode.play()
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            playerNode.stop()

            try? await Task.sleep(nanoseconds: UInt64(pause * 1_000_000_000))
        }

        let unitTime = parisUnitTime(wpm: wpm)
        try? await Task.sleep(nanoseconds: UInt64(unitTime * 2 * 1_000_000_000))
        logger.log("Processed character: \(char)")
    }

    private func parisUnitTime(wpm: Double) -> Double {
        return 1.2 / wpm
    }
}
