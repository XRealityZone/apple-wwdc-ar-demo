/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Gesture interaction methods for the Game Scene View Controller.
*/

import os.log
import UIKit

class GameViewGestureRecognizer: NSObject, UIGestureRecognizerDelegate {

    // Gesture recognizers
    var gestureRecognizers = [UIGestureRecognizer]()

    weak var gameSessionManager: GameSessionManager?

    func configure(with gameSessionManager: GameSessionManager, levelIsResizable: Bool) {
        gestureRecognizers.removeAll()
        self.gameSessionManager = gameSessionManager

        let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        gestureRecognizer.delegate = self
        gameSessionManager.view.addGestureRecognizer(gestureRecognizer)
        gestureRecognizers.append(gestureRecognizer)
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGestureRecognizer.delegate = self
        gameSessionManager.view.addGestureRecognizer(tapGestureRecognizer)
        gestureRecognizers.append(tapGestureRecognizer)

        let doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
        doubleTapGestureRecognizer.delegate = self
        gameSessionManager.view.addGestureRecognizer(doubleTapGestureRecognizer)
        gestureRecognizers.append(doubleTapGestureRecognizer)
        
        if levelIsResizable {
            let pinchGestureRecognizer = ThresholdPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            pinchGestureRecognizer.delegate = self
            gameSessionManager.view.addGestureRecognizer(pinchGestureRecognizer)
            gestureRecognizers.append(pinchGestureRecognizer)
        }
        
        let rotationGestureRecognizer = ThresholdRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        rotationGestureRecognizer.delegate = self
        gameSessionManager.view.addGestureRecognizer(rotationGestureRecognizer)
        gestureRecognizers.append(rotationGestureRecognizer)
        
        let panGestureRecognizer = ThresholdPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGestureRecognizer.delegate = self
        gameSessionManager.view.addGestureRecognizer(panGestureRecognizer)
        gestureRecognizers.append(panGestureRecognizer)
    }
    
    // MARK: - UI Gestures and Touches
    @objc
    func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let gameSessionManager = gameSessionManager,
            gesture.state == .ended else { return }

        gameSessionManager.handleTouch(.tapped)
    }
    
    @objc
    func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard let gameSessionManager = gameSessionManager,
            gesture.state == .ended else { return }
        os_log("tap %s", "\(gesture)")
        gameSessionManager.view.scene.anchors.forEach {
            let dumpLog = $0.dump()
            os_log(.default, log: GameLog.general, "DUMP:\n%@", dumpLog)
        }
    }

    @objc
    func handlePinch(_ gesture: ThresholdPinchGestureRecognizer) {
        guard let gameSessionManager = gameSessionManager else { return }
        switch gesture.state {
        case .changed where gesture.isThresholdExceeded:
            gameSessionManager.scaleBoard(by: Float(gesture.scale))
            gesture.scale = 1
        default:
            break
        }
    }

    @objc
    func handleRotation(_ gesture: ThresholdRotationGestureRecognizer) {
        guard let gameSessionManager = gameSessionManager else { return }
        switch gesture.state {
        case .changed where gesture.isThresholdExceeded:
            gameSessionManager.rotateBoard(by: Float(gesture.rotation))
            gesture.rotation = 0
        default:
            break
        }
    }

    @objc
    func handlePan(_ gesture: ThresholdPanGestureRecognizer) {
        guard let gameSessionManager = gameSessionManager else { return }
        let location = gesture.location(in: gameSessionManager.view)
        let results = gameSessionManager.view.raycast(from: location, allowing: .existingPlaneGeometry, alignment: .horizontal)
        guard let nearestPlane = results.first else {
            return
        }

        let touchPosition = nearestPlane.worldTransform.columns.3.xyz

        switch gesture.state {
        case .began:
            gameSessionManager.panStartedAt(touchPosition)
        case .changed:
            gameSessionManager.panMovedTo(touchPosition)
        default:
            break
        }
    }

    @objc
    func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard let gameSessionManager = gameSessionManager else { return }
        gameSessionManager.useDefaultScale()
    }

    func gestureRecognizer(_ first: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith second: UIGestureRecognizer) -> Bool {
        if first is UIRotationGestureRecognizer && second is UIPinchGestureRecognizer {
            return true
        } else if first is UIRotationGestureRecognizer && second is UIPanGestureRecognizer {
            return true
        } else if first is UIPinchGestureRecognizer && second is UIRotationGestureRecognizer {
            return true
        } else if first is UIPinchGestureRecognizer && second is UIPanGestureRecognizer {
            return true
        } else if first is UIPanGestureRecognizer && second is UIPinchGestureRecognizer {
            return true
        } else if first is UIPanGestureRecognizer && second is UIRotationGestureRecognizer {
            return true
        }
        return false
    }
}
