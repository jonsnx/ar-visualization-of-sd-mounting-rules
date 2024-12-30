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
                pln.planeAnchor.identifier == planeAnchor.identifier }[0]
            guard let updatedPlane: Plane = plane else { continue }
            updatedPlane.didUpdate(anchor: planeAnchor)
        }
    }
    
    /*
     private func addRedPlane(for planeAnchor: ARPlaneAnchor) {
     let planeResource: MeshResource = .generatePlane(width: planeAnchor.planeExtent.width, height: planeAnchor.planeExtent.height)
     let planeMaterial: SimpleMaterial = .init(color: .red, isMetallic: false)
     let planeEntity: ModelEntity = ModelEntity(mesh: planeResource, materials: [planeMaterial])
     let plane = Plane(planeAnchor: planeAnchor)
     
     
     let position = planeAnchor.transform.toTranslation()
     let orientation = planeAnchor.transform.toQuaternion()
     
     // Create the plane entity (a red rectangle) with the correct size
     let planeEntity = ModelEntity(mesh: MeshResource.generatePlane(width: planeAnchor.planeExtent.width, height: planeAnchor.planeExtent.height))
     planeEntity.model?.materials = [SimpleMaterial(color: .red, isMetallic: false)]
     
     // Apply position and orientation
     planeEntity.transform.translation = position
     planeEntity.transform.rotation = orientation
     
     // Create an AnchorEntity using the ARPlaneAnchor's transform
     let anchorEntity = AnchorEntity(world: position)
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
     
     print("Updated ARPlaneAnchor: \(planeAnchor)")
     
     let position = planeAnchor.transform.toTranslation()
     let orientation = planeAnchor.transform.toQuaternion()
     
     // The center is a position before the orientation is taken in to
     // account, so we need to rotate it  to get the true position before
     // we add it to the anchors position
     let rotatedCenter = orientation.act(planeAnchor.center)
     
     planeEntity.transform.translation = position + rotatedCenter
     planeEntity.transform.rotation = orientation
     
     planeEntity.model?.mesh = MeshResource.generatePlane(
     width: planeAnchor.planeExtent.width,
     height: planeAnchor.planeExtent.height
     )
     
     anchorEntity.position = planeAnchor.center
     }
     */
}
