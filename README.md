# MorseTrainer
Text file to morse code for iPhone and iPad 
# MorseTrainer

An iOS app that converts text from a `story.txt` file into Morse code audio, designed for iPhone and iPad. Built with SwiftUI and AVFoundation, it features a WPM slider (5–30), start/stop buttons, and a text display toggle. Uses single-precision `sinf` for fast audio processing.

## Features
- Loads `story.txt` into a circular buffer.
- Plays Morse code at 800 Hz with click-free audio.
- Supports A-Z, 0-9, punctuation, and spaces.
- Error handling: displays and plays "ERROR NO STORY.TXT" if file is missing.
- No speech recognition or microphone input.

## Setup
1. Clone the repo: `git clone https://github.com/bobh/MorseTrainer.git`
2. Add `story.txt` (UTF-8) to the project Resources.
3. Build in Xcode 16+ for iPhone (iOS 16+).
4. For iPad, import into Swift Playgrounds (iPadOS 16+).

## Files
- `ContentView.swift`: UI with slider and buttons.
- `MorseTrainer.swift`: Morse code and audio logic.
- `MorseTrainerApp.swift`: App entry point.
- `CircularBuffer.swift`: SafeCircularBuffer implementation.
- `story.txt`: Input text file.

