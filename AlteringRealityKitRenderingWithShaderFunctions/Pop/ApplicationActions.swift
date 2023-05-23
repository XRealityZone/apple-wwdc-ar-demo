/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Singleton that contains useful methods that can be called from anywhere in the
 app.
*/

import Foundation
import AVFoundation

@available(iOS 15.0, *)
struct ApplicationActions {
    
    /// Shared instance.
    static var shared = ApplicationActions()
    var realityView: RealityView? = nil
    
    /// Sound players.
    var popPlayers = [AVAudioPlayer]()
    let playerQueue = DispatchQueue(label: "com.apple.samplecode.player")
    let whooshPlayer: AVAudioPlayer

    init() {
        // Create an AVAudioPlayer for each of the pop sound files and store
        // them in the popPlayers array.
        for index in 1...6 {
            print("Loading pop\(index).wav...")
            if let path = Bundle.main.path(forResource: "pop\(index)", ofType: "wav") {
                let url = URL(fileURLWithPath: path)
                do {
                    let onePop = try AVAudioPlayer(contentsOf: url)
                    popPlayers.append(onePop)
                } catch {
                    print("Unable to load pop\(index).wav. Skipping...")
                }
            }
        }
        
        // Create an audio player for the whoosh sound used on reset.
        guard let whooshPath = Bundle.main.path(forResource: "whoosh", ofType: "wav") else {
            fatalError("Unable to load whoosh sound file.")
        }
        let url = URL(fileURLWithPath: whooshPath)
        do {
            whooshPlayer = try AVAudioPlayer(contentsOf: url)
        } catch {
            fatalError("Unable to create audio player for whoosh sound")
        }
    }
    
    /// Randomly selects and plays one of the loaded pop sounds.
    func playPop() {
        let endIndex = popPlayers.count - 1
        let index = Int.random(in: 0...endIndex)
        let player = popPlayers[index]
        player.play()
    }
    
    /// Plays a whoosh sound.
    func playWhoosh() {
        whooshPlayer.play()
    }
    
    /// Resets the scene so that all robots are visible.
    func resetRobots() {
        realityView?.resetRobots()
    }
    
    /// Passes taps from SwiftUI to the RealityView.
    func screenTapped(point: CGPoint) {
        realityView?.userTapped(at: point)
    }
}
