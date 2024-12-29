import UIKit
import RealityKit
import ARKit

class ViewController: UIViewController, ARSessionDelegate {
    @IBOutlet var arView: ARView!
    
    // Dictionary to keep track of AnchorEntities
    var anchorEntities: [UUID: AnchorEntity] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        
        arView.session.delegate = self
        
        arView.environment.sceneUnderstanding.options = []
        
        // Turn on occlusion from the scene reconstruction's mesh.
        arView.environment.sceneUnderstanding.options.insert(.occlusion)
        
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
            guard let planeAnchor = anchor as? ARPlaneAnchor,
                  planeAnchor.classification == .ceiling else {
                print("Skipping anchor: \(anchor)")
                continue
            }
            print("Anchor: \(anchor)")
            addRedPlane(for: planeAnchor)
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let planeAnchor = anchor as? ARPlaneAnchor,
                  planeAnchor.classification == .ceiling else { continue }
            
            // Update the red plane if the plane anchor is updated
            updateRedPlane(for: planeAnchor)
        }
    }
    
    private func addRedPlane(for planeAnchor: ARPlaneAnchor) {
        // Create the plane entity (a red rectangle) with the correct size
        let planeEntity = ModelEntity(mesh: .generatePlane(width: planeAnchor.planeExtent.width, height: planeAnchor.planeExtent.height))
        planeEntity.model?.materials = [SimpleMaterial(color: .red, isMetallic: false)]
        
        // Create an AnchorEntity using the ARPlaneAnchor's transform to match its position and orientation
        let anchorEntity = AnchorEntity(anchor: planeAnchor)
        
        // Set the name of the anchor entity to the plane anchor's UUID string
        anchorEntity.name = planeAnchor.identifier.uuidString
        
        // Add the plane entity to the anchor entity
        anchorEntity.addChild(planeEntity)
        
        // Add the anchor entity to the scene
        arView.scene.addAnchor(anchorEntity)
        
        // Save the anchorEntity in the dictionary for later use
        anchorEntities[planeAnchor.identifier] = anchorEntity
    }
    
    private func updateRedPlane(for planeAnchor: ARPlaneAnchor) {
        // Get the corresponding AnchorEntity from the dictionary using the plane anchor's identifier
        guard let anchorEntity = anchorEntities[planeAnchor.identifier],
              let planeEntity = anchorEntity.children.first as? ModelEntity else {
            print("Update skipped: AnchorEntity not found!")
            return
        }
        
        print("Updating...")
        
        // Update the plane's size and position to match the new planeAnchor's extent and position
        planeEntity.model = ModelComponent(mesh: .generatePlane(width: planeAnchor.planeExtent.width, height: planeAnchor.planeExtent.height),
                                           materials: [SimpleMaterial(color: .red, isMetallic: false)])
        
        // Apply the updated position and orientation from the planeAnchor's transform
        anchorEntity.transform = Transform(matrix: planeAnchor.transform)
    }
}
