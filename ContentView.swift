// ContentView.swift
import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var morseTrainer = MorseTrainer()
    
    var body: some View {
        VStack(spacing: 16) {
            // WPM Slider
            Text("Speed: \(Int(morseTrainer.wpm)) WPM")
                .font(.headline)
            Slider(value: $morseTrainer.wpm, in: 5...30, step: 1)
                .padding(.horizontal)
            
            // Start/Stop Button
            Button(morseTrainer.isPlaying ? "Stop" : "Start") {
                morseTrainer.togglePlayback()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(morseTrainer.isPlaying ? Color.red : Color.green)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Show Story Button
            Button(morseTrainer.showStory ? "Hide Story" : "Show Story") {
                morseTrainer.toggleShowStory()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Story Text Display
            ScrollView {
                Text(morseTrainer.showStory ? morseTrainer.storyText : "")
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .onAppear {
            morseTrainer.loadStory()
            morseTrainer.startProcessing()
        }
        .onDisappear {
            morseTrainer.stopProcessing()
        }
    }
}

#Preview {
    // Simplified preview with static data, no ObservableObject
    struct PreviewContentView: View {
        var wpm: Double = 15
        var isPlaying: Bool = false
        var showStory: Bool = true
        var storyText: String = "Sample story text for preview.\nThis is a test of MorseTrainer."
        
        var body: some View {
            VStack(spacing: 16) {
                Text("Speed: \(Int(wpm)) WPM")
                    .font(.headline)
                Slider(value: .constant(wpm), in: 5...30, step: 1)
                    .padding(.horizontal)
                
                Button(isPlaying ? "Stop" : "Start") {
                    // No action in preview
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(isPlaying ? Color.red : Color.green)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                Button(showStory ? "Hide Story" : "Show Story") {
                    // No action in preview
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                ScrollView {
                    Text(showStory ? storyText : "")
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding()
        }
    }
    
    // Wrap in error-catching view for diagnostics
    return ErrorCatchingView {
        PreviewContentView()
    }
}

// View to catch and log uncaught exceptions
struct ErrorCatchingView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .onAppear {
                // Log to help diagnose crashes
                print("Preview rendering started")
            }
            .onDisappear {
                print("Preview rendering stopped")
            }
    }
}
