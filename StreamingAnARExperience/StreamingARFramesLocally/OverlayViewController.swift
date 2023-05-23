/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The overlay view controller of the sample app.
*/

import UIKit
import MetalKit

///- Tag: OverlayViewController
class OverlayViewController: UIViewController {
    
    @IBOutlet weak var pipView: MTKView!
    
    @IBOutlet weak var pipViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var pipViewWidthConstraint: NSLayoutConstraint!
        
    // Set in viewDidLoad of the main ViewController.
    weak var multipeerSession: MultipeerSession?
    
    // Renders the pixel buffers from the connected peer.
    var renderer: Renderer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure the pipView
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Unable to get system default device!")
        }
        
        pipView.device = device
        pipView.backgroundColor = .clear
        
        pipView.colorPixelFormat = .bgra8Unorm
        pipView.depthStencilPixelFormat = .depth32Float_stencil8
        
        // Configure the renderer to render to the pipView.
        renderer = Renderer(device: device, renderDestination: pipView)
        renderer.mtkView(pipView, drawableSizeWillChange: pipView.bounds.size)
        
        pipView.delegate = renderer
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        pipView.addGestureRecognizer(tapGesture)
    }
    
    @objc
    func tapped(_ sender: UITapGestureRecognizer) {
        guard let view = sender.view else { return }
        let location = sender.location(in: view)
        
        // Make sure you have the necessary matrices to construct a ray.
        guard let inverseProjectionMatrix = renderer.lastDrawnInverseProjectionMatrix,
            let inverseViewMatrix = renderer.lastDrawnInverseViewMatrix else {
            return
        }
        let rayQuery = makeRay(from: location,
            viewportSize: view.frame.size,
            inverseProjectionMatrix: simd_float4x4(inverseProjectionMatrix),
            inverseViewMatrix: simd_float4x4(inverseViewMatrix))
        do {
            let data = try JSONEncoder().encode(rayQuery)
            multipeerSession?.sendToAllPeers(data, reliably: true)
        } catch {
            fatalError("Failed to encode rayQuery as JSON with error: \(error.localizedDescription)")
        }
    }
    ///- Tag: MakeRay
    private func makeRay(from viewPoint: CGPoint,
                         viewportSize: CGSize,
                         inverseProjectionMatrix: simd_float4x4,
                         inverseViewMatrix: simd_float4x4) -> Ray {
        
        // Calculating near position.
        let nearClipPosition = makeClipSpacePosition(viewPoint: viewPoint, viewportSize: viewportSize, clipZ: 0)
        var nearViewPosition = inverseProjectionMatrix * nearClipPosition
        nearViewPosition /= nearViewPosition.w
        let nearWorldPosition = inverseViewMatrix * nearViewPosition
        
        // Getting the cameraPosition from the inverse view matrix.
        let cameraPosition = inverseViewMatrix.columns.3.xyz
        
        // Calculating ray direction.
        let direction = normalize(nearWorldPosition.xyz - cameraPosition)
                
        return Ray(direction: direction, origin: cameraPosition)
    }
    
    private func makeClipSpacePosition(viewPoint: CGPoint, viewportSize: CGSize, clipZ: Float) -> SIMD4<Float> {
        
        let clipX = Float(viewPoint.x * 2 / viewportSize.width - 1)
        let clipY = -Float(viewPoint.y * 2 / viewportSize.height - 1)
        
        return .init(clipX, clipY, clipZ, 1)
    }
    
    func setPipViewConstraints(width: CGFloat, height: CGFloat) {
        DispatchQueue.main.async { [self] in
            pipViewWidthConstraint?.constant = width / pipView.contentScaleFactor
            pipViewHeightConstraint?.constant = height / pipView.contentScaleFactor
        }
    }
}
