/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main view controller for the Game.
*/

import UIKit
import SceneKit

class GameViewController: UIViewController, SCNSceneRendererDelegate {
    
    @IBOutlet var sceneView: SCNView!
    
    @IBOutlet weak var blueSlider: UISlider!
    @IBAction func blueSliderChanged(_ sender: Any) {
        setColor()
    }
    
    @IBOutlet weak var greenSlider: UISlider!
    @IBAction func greenSliderChanged(_ sender: Any) {
        setColor()
    }
    
    @IBOutlet weak var redSlider: UISlider!
    @IBAction func redSliderChanged(_ sender: Any) {
        setColor()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // The scene in this sample was configured entirely in the max.scn file
        let scene = SCNScene(named: "art.scnassets/Character/max.scn")!
        
        sceneView.scene = scene
        sceneView.showsStatistics = true
        sceneView.delegate = self
        
        let technique = SCNTechnique(dictionary: MyTechnique.techniqueDictionary)
        sceneView.technique = technique
        
        setColor()
    }
    
    /// - Tag: updateAtTime
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        sceneView.technique?.setValue(Float(abs(cos(time))), forKey: "time_symbol")
    }
    
    /// - Tag: setColor
    func setColor() {
        DispatchQueue.main.async { [self] in
            let color = SCNVector3(redSlider.value, greenSlider.value, blueSlider.value)
            sceneView.technique?.setValue(color, forKey: "color_weights_symbol")
        }
    }
}
