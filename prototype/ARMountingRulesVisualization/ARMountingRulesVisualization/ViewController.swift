import UIKit
import RealityKit
import ARKit

class ViewController: UIViewController, ARSessionDelegate {
    @IBOutlet var arView: ARView!
    
    // Dictionary to keep track of AnchorEntities
    var anchorEntities: [UUID: AnchorEntity] = [:]
    var planes = [Plane]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        arView.session.delegate = self
        
        arView.environment.sceneUnderstanding.options = []
        
        // Turn on occlusion from the scene reconstruction's mesh.
        // arView.environment.sceneUnderstanding.options.insert(.occlusion)
        
        // Turn on physics for the scene reconstruction's mesh.
        arView.environment.sceneUnderstanding.options.insert(.physics)
        
        // Display a debug visualization of the mesh.
        arView.debugOptions.insert(.showSceneUnderstanding)
        
        // For performance, disable render options that are not required for this app.
        arView.renderOptions = [.disablePersonOcclusion, .disableDepthOfField, .disableMotionBlur]
        
        // Manually configure what kind of AR session to run since
        // ARView on its own does not turn on mesh classification.
        arView.automaticallyConfigureSession = false
        
        // Configure AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal] // Include vertical planes
        configuration.sceneReconstruction = .meshWithClassification
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            arView.session.run(configuration)
        }
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        print("didAdd anchors: \(anchors)")
        for anchor in anchors {
            guard let planeAnchor = anchor as? ARPlaneAnchor else { continue }
            if planeAnchor.classification != .ceiling { continue }
            let plane = Plane(planeAnchor: planeAnchor)
            plane.transform.matrix = planeAnchor.transform
            self.arView.scene.anchors.append(plane)
            self.planes.append(plane)
        }
    }
    
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let planeAnchor = anchor as? ARPlaneAnchor else { continue }
            let plane: Plane? = planes.filter { pln in
                pln.planeAnchor.identifier == planeAnchor.identifier }.first
            guard let updatedPlane: Plane = plane else { continue }
            updatedPlane.didUpdate(anchor: planeAnchor)
        }
    }
}
