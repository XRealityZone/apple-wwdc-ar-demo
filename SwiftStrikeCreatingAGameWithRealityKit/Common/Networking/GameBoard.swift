/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Manages placement of the game board in real space before starting a game.
*/

import ARKit
import Combine
import os.log
import RealityKit

/// GameBoard represents the physical surface which the game is played upon.
///
/// It provides two nodes for placing the board in the world:
///
/// The `boardNode` is attached to the ARAnchor for the level. Its transform can get updated as
/// ARKit learns more about the world.
///
/// `scaleNode` is the first child of `boardNode`, and is used to scale the level.
/// In this node's child coordinate space, coordinates are normalized to the
/// board's width. So if the user wants to see the game appear in worldspace 1.5 meters
/// wide, the scale portion of this node's transform will be 1.5 in all dimensions.
///
/// The level content becomes a child of `scaleNode`.
class GameBoard {
    // MARK: - Properties
    /// The BoardAnchor in the scene
    var anchor: ARAnchor? {
        didSet {
            if let anchor = anchor {
                position = anchor.transform.translation
                isShowingPlacementUI = false
            }
        }
    }

    /// Indicates whether the placement UI is currently visible
    var isShowingPlacementUI: Bool {
        get { return placementUI?.isEnabled ?? false }
        set {
            if newValue == placementUI?.isEnabled { return }
            if newValue {
                os_log(.default, log: GameLog.gameboard, "adding board component")
            } else {
                os_log(.default, log: GameLog.gameboard, "removing board component")
            }
            placementUI?.isEnabled = newValue
        }
    }

    private static let boardScaleEntityName = "boardScale"
    private static var boardScale: Entity?
    static var boardScaleEntity: Entity? {
        return boardScale
    }
    static var boardScaleUniform: Float {
        if let entity = boardScale {
            return entity.transform.scale.x
        }
        return 1
    }

    private static var boardRect = CGRect(x: 0, y: 0, width: 0, height: 0)
    private func setBounds() {
        let cgWidth = preferredSize.width
        let cgHeight = preferredSize.height
        GameBoard.boardRect = CGRect(origin: CGPoint(x: -cgWidth * 0.5, y: -cgHeight * 0.5),
                                     size: CGSize(width: cgWidth, height: cgHeight))
        os_log(.default, log: GameLog.gameboard, "bounds = %s", "\(GameBoard.boardRect)")
    }

    /// The level's preferred size.
    /// This is used both to set the aspect ratio and to determine
    /// the default size.
    private let preferredSize: CGSize
    private let isResizable: Bool

    /// If the level isResizable, then these
    /// are the scale limits
    private let defaultScale: Float
    private let minimumScale: Float
    private let maximumScale: Float

    /// The aspect ratio of the level. (width / height)
    let aspectRatio: Float
    enum Orientation {
        case portrait
        case landscape
    }
    let orientation: Orientation

    /// The game board's most recent positions.
    private var recentPositions: [SIMD3<Float>] = []

    /// The game board's most recent rotation angles.
    private var recentRotationAngles: [Float] = []

    /// The mesh used to visualize the board area.
    private var placementUI: Entity?
    private var loadCancellables = [AnyCancellable]()

    /// The entity representing the board.
    /// Its pose (rotation, translation) relative to the origin defines
    /// where the center of the board is located.
    let anchorEntity: AnchorEntity
    /// Defines the size of the board.
    /// Assumes the level is 1m wide, so if we want the level to appear to be
    /// 2.1 meters wide, this should have a scale of (2.1, 2.1, 2.1).
    let scaleEntity: Entity

    init(level: GameLevel, placementUILoader: AnyPublisher<Entity, Error>?) {
        self.preferredSize = level.targetSize
        self.isResizable = level.isResizable
        self.defaultScale = level.defaultScale
        self.minimumScale = level.minimumScale
        self.maximumScale = level.maximumScale
        self.aspectRatio = Float(preferredSize.height / preferredSize.width)
        self.orientation = self.preferredSize.width > self.preferredSize.height ? .landscape : .portrait
        os_log(.default, log: GameLog.gameboard, "GameBoard size=%s, resize=%s, defaultScale=%s, minScale=%s, maxScale=%s, orientation=%s",
               "\(self.preferredSize)",
               "\(self.isResizable)",
               "\(self.defaultScale)",
               "\(self.minimumScale)",
               "\(self.maximumScale)",
               "\(self.orientation)"
        )

        let entity = AnchorEntity()
        entity.name = "gameboard"
        entity.isEnabled = true

        self.anchorEntity = entity

        let scaleEntity = Entity()
        scaleEntity.name = GameBoard.boardScaleEntityName
        scaleEntity.transform.scale = SIMD3<Float>(repeating: self.defaultScale)
        GameBoard.boardScale = scaleEntity

        anchorEntity.children.append(scaleEntity)
        self.scaleEntity = scaleEntity

        placementUILoader?
            .sink(receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    fatalError(error.localizedDescription)
                }
            }) { [weak self] entity in
                self?.placementUI = entity
                self?.scaleEntity.children.append(entity)
            }
            .store(in: &loadCancellables)
        
        self.isShowingPlacementUI = false
        self.setBounds()
    }

    private func cancelSubscriptions() {
        loadCancellables = []
    }

    var isHidden: Bool {
        get { return !anchorEntity.isEnabled }
        set { anchorEntity.isEnabled = !newValue }
    }

   var position: SIMD3<Float> {
        get { return anchorEntity.transform.translation }
        set { anchorEntity.transform.translation = newValue }
    }

    var uniformScale: Float {
        get { return scaleEntity.transform.scale.x }
        set {
            if isResizable {
                guard newValue != scaleEntity.transform.scale.x else { return }
                if newValue < minimumScale {
                    os_log(.default, log: GameLog.gameboard, "Scale too small (%s<%s) - how?", "\(newValue)", "\(minimumScale)")
                } else if newValue > maximumScale {
                    os_log(.default, log: GameLog.gameboard, "Scale too big (%s>%s) - how?", "\(newValue)", "\(maximumScale)")
                }
                scaleEntity.transform.scale = SIMD3<Float>(repeating: newValue)
                os_log(.default, log: GameLog.gameboard, "Scale = %s", "\(newValue)")
            }
        }
    }

    // in radians, around the Y axis, relative to X axis
    var rotationAboutY: Float {
        get {
            return anchorEntity.transform.rotation.angle
        }
        set {
            anchorEntity.transform.rotation = simd_quatf(angle: Angle.sanitizeAngle(angle: newValue), axis: [0, 1, 0])
        }
    }
    
    // encodes only the pose, not the scale.
    var transform: float4x4 {
        return anchorEntity.transformMatrix(relativeTo: nil)
    }

    /// Updates the game board with the latest hit test result and camera.
    func update(with hitTestResult: ARRaycastResult, camera: ARCamera) {
        isShowingPlacementUI = true
        let hitPosition = hitTestResult.worldTransform.translation

        // Average using several most recent positions.
        recentPositions.append(hitPosition)
        recentPositions = Array(recentPositions.suffix(10))

        // Move to average of recent positions to avoid jitter.
        let average = recentPositions.reduce(SIMD3<Float>(repeating: 0), { $0 + $1 }) / Float(recentPositions.count)
        position = average

        // Orient bounds to plane if possible
        if let planeAnchor = hitTestResult.anchor as? ARPlaneAnchor {
            orientToPlane(planeAnchor, camera: camera)
            if !isResizable {
                scaleToPlane(planeAnchor)
            }
        } else {
            // Fall back to camera orientation
            orientToCamera(camera)
            useMinimumScale()
        }
    }

    var numberOfFramesLookedAtPlane = 0
    var planeAnchor: ARPlaneAnchor?
    
    func didLookLongEnoughAtPlane(_ plane: ARPlaneAnchor) -> Bool {
        // Require to look at a certain plane for some time,
        // to prevent placing the board too fast.
        let requiredFramesLookingAtPlane = 30
        
        guard let planeAnchor = planeAnchor else {
            numberOfFramesLookedAtPlane = 0
            self.planeAnchor = plane
            return false
        }
        
        if planeAnchor == plane {
            numberOfFramesLookedAtPlane += 1
            if numberOfFramesLookedAtPlane >= requiredFramesLookingAtPlane {
                return true
            }
        } else {
            numberOfFramesLookedAtPlane = 0
            self.planeAnchor = plane
            return false
        }
        
        return false
    }

    func reset() {
        GameBoard.boardScale = nil

        // maybe this should be done in reset with no deinit necessary...
        if let entity = placementUI {
            scaleEntity.removeChild(entity)
            placementUI = nil
        }
        anchorEntity.removeChild(scaleEntity)

        isShowingPlacementUI = false
        recentPositions.removeAll()
        recentRotationAngles.removeAll()
        isHidden = false
        planeAnchor = nil
        numberOfFramesLookedAtPlane = 0
        cancelSubscriptions()
    }

    /// Incrementally scales the board by the given amount
    func scale(by factor: Float) {
        let currentScale = uniformScale
        let newScale = currentScale * factor
        uniformScale = newScale.clamped(lowerBound: minimumScale, upperBound: maximumScale)
    }

    func useDefaultScale() {
        uniformScale = defaultScale
    }
    
    func useMinimumScale() {
        uniformScale = minimumScale
    }

    // MARK: Helper Methods
    func orientToCamera(_ camera: ARCamera) {
        // Until attached to a plane, keep the board in front of and facing the camera
        var transform = camera.transform
        var offsetFromCamera = matrix_identity_float4x4
        offsetFromCamera.translation = SIMD3<Float>(0, 0, -1.0)
        transform *= offsetFromCamera
        
        self.position = transform.translation
        self.position.y -= 0.5
        self.rotationAboutY = camera.eulerAngles.y
    }

    private func orientToPlane(_ planeAnchor: ARPlaneAnchor, camera: ARCamera) {
        // Get board rotation about y
        var boardAngle = self.rotationAboutY

        if !isResizable {
            // If plane is longer than deep, rotate 90 degrees
            let planeOrientation = planeAnchor.extent.x > planeAnchor.extent.z ? Orientation.landscape : Orientation.portrait
            if planeOrientation != orientation {
                boardAngle += .pi / 2
            }
        }

        // Normalize angle to closest 180 degrees to camera angle
        boardAngle = boardAngle.normalizedAngle(forMinimalRotationTo: camera.eulerAngles.y, increment: .pi)

        rotate(to: boardAngle)
    }

    private func rotate(to angle: Float) {
        let previousAngle = recentRotationAngles.reduce(0, { $0 + $1 }) / Float(recentRotationAngles.count)
        if abs(angle - previousAngle) > .pi / 2 {
            recentRotationAngles = recentRotationAngles.map { $0.normalizedAngle(forMinimalRotationTo: angle, increment: .pi) }
        }

        // Average using several most recent rotation angles.
        recentRotationAngles.append(angle)
        recentRotationAngles = Array(recentRotationAngles.suffix(20))

        // Move to average of recent positions to avoid jitter.
        let averageAngle = recentRotationAngles.reduce(0, { $0 + $1 }) / Float(recentRotationAngles.count)
        self.rotationAboutY = averageAngle
    }

    private func scaleToPlane(_ planeAnchor: ARPlaneAnchor) {

        // Flip dimensions if necessary
        let planeExtent = planeAnchor.extent
        os_log(.default, log: GameLog.gameboard, "Plane Extent = %s", "\(planeExtent)")

        // Scale board to the max extent that fits in the plane
        var width = min(planeExtent.x, maximumScale)
        let depth = min(planeExtent.z, width * aspectRatio)
        width = depth / aspectRatio
        uniformScale = width

        // Adjust position of board within plane's bounds
        let planeLocalExtent = SIMD3<Float>(width, 0, depth)
        adjustPosition(withinPlaneBounds: planeAnchor, extent: planeLocalExtent)
    }

    private func adjustPosition(withinPlaneBounds planeAnchor: ARPlaneAnchor, extent: SIMD3<Float>) {
        var positionAdjusted = false
        let worldToPlane = planeAnchor.transform.inverse

        // Get current position in the local plane coordinate space
        var planeLocalPosition = (worldToPlane * SIMD4<Float>(position.x, position.y, position.z, 0))

        // Compute bounds min and max
        let boardMin = planeLocalPosition.xyz - extent / 2
        let boardMax = planeLocalPosition.xyz + extent / 2
        let planeMin = planeAnchor.center - planeAnchor.extent / 2
        let planeMax = planeAnchor.center + planeAnchor.extent / 2

        // Adjust position for x within plane bounds
        if boardMin.x < planeMin.x {
            planeLocalPosition.x += planeMin.x - boardMin.x
            positionAdjusted = true
        } else if boardMax.x > planeMax.x {
            planeLocalPosition.x -= boardMax.x - planeMax.x
            positionAdjusted = true
        }

        // Adjust position for z within plane bounds
        if boardMin.z < planeMin.z {
            planeLocalPosition.z += planeMin.z - boardMin.z
            positionAdjusted = true
        } else if boardMax.z > planeMax.z {
            planeLocalPosition.z -= boardMax.z - planeMax.z
            positionAdjusted = true
        }

        if positionAdjusted {
            position = (planeAnchor.transform * planeLocalPosition).xyz
        }
    }

    static func pinToBounds(_ position: SIMD3<Float>, buffer: Float) -> SIMD3<Float> {
        let inset = CGFloat(-buffer)
        let rect = boardRect.insetBy(dx: inset, dy: inset)

        var xPos = CGFloat(position.x)
        var yPos = CGFloat(position.z)

        if xPos < rect.minX {
            xPos = rect.minX
        } else if xPos > rect.maxX {
            xPos = rect.maxX
        }
        if yPos < rect.minY {
            yPos = rect.minY
        } else if yPos > rect.maxY {
            yPos = rect.maxY
        }

        return SIMD3<Float>(Float(xPos), position.y, Float(yPos))
    }

    /// pinToGameBoardBounds
    /// position is in Physics Origin space
    /// buffer is number of meters to add to edges of rect
    static func pinToGameBoardBounds(_ position: SIMD3<Float>, buffer: Float? = nil) -> SIMD3<Float> {
        let edgeBuffer = buffer ?? 0.0
        return pinToBounds(position, buffer: edgeBuffer)
    }

}
