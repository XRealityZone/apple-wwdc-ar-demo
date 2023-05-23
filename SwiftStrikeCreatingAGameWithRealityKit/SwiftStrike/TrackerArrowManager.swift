/*
See LICENSE folder for this sample’s licensing information.

Abstract:
TrackerArrowManager
*/

import ARKit
import Combine
import RealityKit
import UIKit

class TrackerArrowManager {
    private let entityCache: EntityCache
    private weak var realityView: ARView?

    private var trackingArrows = [TrackerArrow]()
    private var cancellables = [AnyCancellable]()

    init(entityCache: EntityCache, realityView: ARView) {
        self.entityCache = entityCache
        self.realityView = realityView
        realityView.scene.publisher(for: SceneEvents.Update.self)
            .sink { [weak self] receiveValue in
                self?.sceneUpdateEvent(receiveValue)
            }
            .store(in: &cancellables)
    }

    func sceneUpdateEvent(_ input: SceneEvents.Update) {
        guard let realityView = realityView else { return }

        // see if new new entites need to be added to the view
        var trackedEntities: [HasOffScreenTracking] = []
        entityCache.forEachEntity { entity in
            guard let trackedEntity = entity as? HasOffScreenTracking else { return }
            trackedEntities.append(trackedEntity)
            let elementsWithId = trackingArrows.filter { $0.identifier == trackedEntity.offScreenTracking.identifier }
            if elementsWithId.isEmpty {
                let newArrow = TrackerArrow(entity: entity,
                                            identifier: trackedEntity.offScreenTracking.identifier,
                                            imageToken: trackedEntity.offScreenTracking.imageToken,
                                            imageSize: trackedEntity.offScreenTracking.imageSize)
                // add arrow to the list and push it onto the view
                trackingArrows.append(newArrow)
                realityView.addSubview(newArrow.imageView)
            } else {
                return
            }
        }
        //remove arrows whose entity has dissapeared from the scene
        trackingArrows = trackingArrows.filter { arrow -> Bool in
            for entity in trackedEntities where entity.offScreenTracking.identifier == arrow.identifier {
                return true
            }
            arrow.imageView.removeFromSuperview()
            return false
        }

        for arrow in trackingArrows {
            arrow.updataOffscreenTargetArrow(view: realityView)
        }
    }
}

class TrackerArrow {
    let identifier: UUID
    var imageToken: String
    let trackedEntity: Entity?
    var imageView: UIImageView
    let imageSize: CGFloat

    init( entity: Entity, identifier: UUID, imageToken: String = "", imageSize: CGFloat = 100 ) {
        self.identifier = identifier
        self.imageToken = imageToken
        self.trackedEntity = entity
        self.imageSize = imageSize
        if imageToken == "" {
            self.imageToken = "ballIndicator" // the default arrow
        }
        let image = UIImage(named: self.imageToken)//replace with imageToken
        imageView = UIImageView(image: image)
        imageView.frame = CGRect(x: 0, y: 0, width: imageSize, height: imageSize)
        imageView.contentMode = .scaleAspectFill
    }

    func updataOffscreenTargetArrow(view: ARView) {
        if let camera = view.session.currentFrame?.camera, let entity = trackedEntity {
            //this assumes the game board is at y = 0
            if entity.transformMatrix(relativeTo: nil).columns.3.y < 0 || !entity.isEnabled { //see if entity is below gameboard or not enabled
                self.imageView.isHidden = true
                return
            }
            let targetPoint = entity.transformMatrix(relativeTo: nil).translation
            let viewBounds = view.bounds

            guard var projectedPoint = view.project(targetPoint) else { return }
            let targetBehindCamera = isTargetBehindCamera(targetPoint: targetPoint, camera: camera)
            if targetBehindCamera {
                projectedPoint.x = viewBounds.width - projectedPoint.x
                projectedPoint.y = viewBounds.height - projectedPoint.y
            }

            if (projectedPoint.x < 0 || projectedPoint.y < 0 || projectedPoint.x > viewBounds.width
                || projectedPoint.y > viewBounds.height) || targetBehindCamera {
                self.imageView.isHidden = false
            } else {
                self.imageView.isHidden = true
                return
            }

            self.imageView.frame.origin = findTargetProjectionToScreen(
                viewBounds: viewBounds, projectedPoint: projectedPoint, edgeBuffer: imageSize )

            // Current image asset is round so not wasting time on rotating the view, in addiotion
            // the CGAffineTransform adds an odd scaling to the image that makes the tracker come off the
            // edge by a few pixels for some rotations
            //Leaving code in as comments as it is the complete implementation for a generic tracking asset
//            let rads = atan2(CGFloat(projectedPoint.y - viewBounds.center.y), CGFloat(projectedPoint.x - viewBounds.center.x))
//            self.imageView.transform = CGAffineTransform(rotationAngle: rads - .pi / 2)

            // without this set the image size will grow fro what ever reason
            self.imageView.layer.bounds = CGRect(x: 0, y: 0, width: imageSize, height: imageSize)
        } else {
            self.imageView.isHidden = true
        }
    }

    // Finds where the arrow should be drawn on the edge of the screen
    private func findTargetProjectionToScreen(viewBounds: CGRect, projectedPoint: CGPoint, edgeBuffer: CGFloat = 100 ) -> CGPoint {
        var screenPoint = CGPoint(x: 0, y: 0)
        let slope = (projectedPoint.y - viewBounds.center.y) / (projectedPoint.x - viewBounds.center.x)
        //check if the arrow should be drwn on the left or right edges
        if slope * viewBounds.width / 2 >= -viewBounds.height / 2 && slope * viewBounds.width / 2 <= viewBounds.height / 2 {
            if projectedPoint.x >= viewBounds.center.x { //hits right bound
                screenPoint.x = viewBounds.width - edgeBuffer
                screenPoint.y = viewBounds.center.y + slope * viewBounds.width / 2
            } else { // hits left bound
                screenPoint.x = 0
                screenPoint.y = viewBounds.center.y - slope * viewBounds.width / 2
            }
        } else { //arrow is on the upper or lower edge
            if projectedPoint.y >= viewBounds.center.y { //hits lower edge
                screenPoint.y = viewBounds.height - edgeBuffer
                screenPoint.x = viewBounds.center.x + viewBounds.height / 2 / slope
            } else { // hits top edge
                screenPoint.y = 0
                screenPoint.x = viewBounds.center.x - viewBounds.height / 2 / slope
            }
        }
        //make sure the content stays on screen
        screenPoint.x = screenPoint.x < viewBounds.width - edgeBuffer ? screenPoint.x : viewBounds.width - edgeBuffer
        screenPoint.y = screenPoint.y < viewBounds.height - edgeBuffer ? screenPoint.y : viewBounds.height - edgeBuffer
        screenPoint.x = screenPoint.x > 0 ? screenPoint.x : 0
        screenPoint.y = screenPoint.y > 0 ? screenPoint.y : 0
        return screenPoint
    }

    // Function to dermine weather a point is behind the virtual camera
    private func isTargetBehindCamera(targetPoint: SIMD3<Float>, camera: ARCamera) -> Bool {
        let positionVector = SIMD4<Float>(targetPoint.x, targetPoint.y, targetPoint.z, 1)
        let pointInCameraSpace = camera.transform.inverse * positionVector
        return pointInCameraSpace.z > 0 ? true : false
    }
}
