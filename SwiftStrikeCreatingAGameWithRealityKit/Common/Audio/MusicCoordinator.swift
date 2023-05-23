/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Manages playback and volume of music.
*/

import AVFoundation
import os.log
import RealityKit

class MusicCoordinator: NSObject {
    enum Error: Swift.Error {
        case missingConfig
    }
    enum MusicState {
        case stopped
        case playing
        case stopping // transition from play to stop, fading out.
    }

    struct MusicConfig: Codable {
        let filename: String
        let volumeDB: Float
        let loops: Bool
    }

    class MusicPlayer {
        let name: String
        let audioPlayer: AVAudioPlayer
        let config: MusicConfig
        var state: MusicState
        
        init(name: String, config: MusicConfig) {
            self.name = name
            self.config = config
            self.state = .stopped
            do {
                guard let url = Bundle.main.url(forResource: config.filename, withExtension: nil) else {
                    fatalError("Failed to load sound for: \(name)")
                }
                self.audioPlayer = try AVAudioPlayer(contentsOf: url)
            } catch {
                fatalError("Failed to load sound for: \(name)")
            }
        }
    }
    
    var musicGain: Float {
        let volume = UserSettings.musicVolume
        // Map the slider value from 0...1 to a more natural curve:
        if volume > 0.0 {
            return volume * volume
        } else {
            return 0
        }
    }

    var musicPlayers = [String: MusicPlayer]()
    var musicConfigurations = [String: MusicConfig]()
    
    override init() {
        super.init()
        
        updateMusicVolume()
        
        do {
            guard let url = Bundle.main.url(forResource: "music.json", withExtension: nil) else {
                fatalError("Failed to load music config from Sounds/music.json")
            }
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            musicConfigurations = try decoder.decode([String: MusicConfig].self, from: data)
        } catch {
            fatalError("Failed to load music config from music.json")
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleDefaultsDidChange(_:)),
                                               name: UserDefaults.didChangeNotification,
                                               object: nil)
    }
    
    @objc
    private func handleDefaultsDidChange(_ notification: Notification) {
        updateMusicVolume()
    }

    private func linearGain(dB: Float) -> Float {
        // converting Decibels to linear gain. pow(10, dB/20) is that conversion.
        let input = musicGain * pow(10, dB / 20.0)
        return input.clamped(lowerBound: 0.0, upperBound: 1.0)
    }

    func updateMusicVolume() {
        for (_, player) in musicPlayers where player.state == .playing {
            player.audioPlayer.setVolume(linearGain(dB: player.config.volumeDB), fadeDuration: 0.1)
        }
    }
    
    func musicPlayer(name: String) -> MusicPlayer {
        if let player = musicPlayers[name] {
            return player
        }
        
        guard let config = musicConfigurations[name] else {
            fatalError("Missing music config for music event named '\(name)'")
        }
        let player = MusicPlayer(name: name, config: config)
        musicPlayers[name] = player
        return player
    }
    
    func playMusic(name: String, fadeIn: Double = 0.0) {
        let player = musicPlayer(name: name)
        let audioPlayer = player.audioPlayer
        
        switch player.state {
        case .playing:
            // Nothing to do
            return
        case .stopped:
            // Configure the audioPlayer, starting with volume at 0 and then fade in.
            audioPlayer.volume = 0
            audioPlayer.currentTime = 0
            if player.config.loops {
                audioPlayer.numberOfLoops = -1
            } else {
                audioPlayer.numberOfLoops = 0
            }
            
            audioPlayer.play()
        case .stopping:
            // Leave it playing. Update the volume and play state below.
            break
        }
        
        audioPlayer.setVolume(linearGain(dB: player.config.volumeDB), fadeDuration: fadeIn)
        
        player.state = .playing
    }

    func stopMusic(name: String, fadeOut: Double = 0.1) {
        let player = musicPlayer(name: name)
        if player.state == .playing {
            player.state = .stopping
            let audioPlayer = player.audioPlayer
            audioPlayer.setVolume(0.0, fadeDuration: fadeOut)
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + fadeOut) {
                if player.state == .stopping {
                    audioPlayer.stop()
                    player.state = .stopped
                }
            }
        }
    }
}
