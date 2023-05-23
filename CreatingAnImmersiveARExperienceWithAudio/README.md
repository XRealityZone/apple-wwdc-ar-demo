# Creating an Immersive AR Experience with Audio

Use sound effects and environmental sound layers to create an engaging AR experience. 

## Overview

This sample app uses SceneKit’s node-based audio API to associate environmental sounds with a virtual object that's placed in the real world. Because audio is 3D positional in SceneKit by default, volume is automatically mixed based on the user's distance from a node.

## Getting Started

* This sample code supports `Relocalization` and therefore, it requires ARKit 1.5 (iOS 11.3) or greater 
* ARKit is not available in the iOS Simulator
* Building the sample requires Xcode 9.3 or later

## Run an AR Session and Place Virtual Content

Before you can use audio, you need to set up a session and place the object from which to play sound. For simplicity, this sample runs a world tracking configuration and places a virtual object on the first horizontal plane that it detects. For more detail about this kind of session setup, see [Tracking and Visualizing Planes](https://developer.apple.com/documentation/arkit/tracking_and_visualizing_planes). The object placement approach in this sample is similar to the one demonstrated in [Placing Objects and Handling 3D Interaction](https://developer.apple.com/documentation/arkit/placing_objects_and_handling_3d_interaction).

## Add 3D Audio to the Scene

To play audio from a given position in 3D space, create an [`SCNAudioSource`][0] from an audio file. This sample loads the file from the bundle in `viewDidLoad`: 

[0]:https://developer.apple.com/documentation/scenekit/scnaudiosource
``` swift
// Instantiate the audio source
audioSource = SCNAudioSource(fileNamed: "fireplace.mp3")!
```
[View in Source](x-source-tag://SetUpAudio)

Then, the audio source is configured and prepared: 
``` swift
// As an environmental sound layer, audio should play indefinitely
audioSource.loops = true
// Decode the audio from disk ahead of time to prevent a delay in playback
audioSource.load()
```
[View in Source](x-source-tag://SetUpAudio)

When you're ready to play the sound, create an [`SCNAudioPlayer`][1], passing it the audio source: 

[1]:https://developer.apple.com/documentation/scenekit/scnaudioplayer
``` swift
// Create a player from the source and add it to `objectNode`
objectNode.addAudioPlayer(SCNAudioPlayer(source: audioSource))
```
[View in Source](x-source-tag://AddAudioPlayer)

- Note: For best results, use mono audio files. SceneKit’s audio engine uses panning to create 3D positional effects, so stereo audio sources produce less recognizable 3D audio effects.