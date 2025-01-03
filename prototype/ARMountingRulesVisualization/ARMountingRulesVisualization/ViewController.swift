import UIKit
import RealityKit
import ARKit

class ViewController: UIViewController, ARSessionDelegate {
    @IBOutlet var arView: ARView!
    
    var arManager = ARManager()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        arView.session.delegate = self
        
        arView.environment.sceneUnderstanding.options = []
        arView.environment.sceneUnderstanding.options.insert(.physics)
        arView.debugOptions.insert(.showSceneUnderstanding)
        arView.renderOptions = [.disablePersonOcclusion, .disableDepthOfField, .disableMotionBlur]
        
        arView.automaticallyConfigureSession = false
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.sceneReconstruction = .meshWithClassification
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            arView.session.run(configuration)
        }
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        Task {
            await processAnchors(anchors: anchors)
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        Task {
            print("\(Thread.current)")
            await processAnchors(anchors: anchors)
        }
    }

    func processAnchors(anchors: [ARAnchor]) async {
        if arManager.isProcessing { return }
        arManager.isProcessing = true
        
        print("Processing anchors...")

        // Process the anchors using ARManager
        let (addedAnchors, updatedAnchors) = await arManager.process(anchors: anchors)

        // Update the scene with the processed anchors
        addAnchorsToScene(addedAnchors)
        updateAnchorsInScene(updatedAnchors)
        
        arManager.isProcessing = false
        print("Anchor processing finished.")
    }

    // Method to add anchors to the scene
    func addAnchorsToScene(_ anchors: [ARPlaneAnchor]) {
        for anchor in anchors {
            let anchorEntity = Plane(planeAnchor: anchor)
            anchorEntity.transform.matrix = anchor.transform
            arManager.sceneAnchors[anchorEntity.planeAnchor.identifier] = anchorEntity
            arView.scene.anchors.append(anchorEntity)
        }
    }
    
    // Method to update existing anchors in the scene
    func updateAnchorsInScene(_ anchors: [ARPlaneAnchor]) {
        for anchor in anchors {
            if let updatedAnchorEntity = arManager.sceneAnchors[anchor.identifier] {
                updatedAnchorEntity.didUpdate(anchor: anchor)
            }
        }
    }
}
