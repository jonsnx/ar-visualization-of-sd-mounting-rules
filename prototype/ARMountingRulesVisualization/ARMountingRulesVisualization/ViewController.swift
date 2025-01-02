import UIKit
import RealityKit
import ARKit

class ViewController: UIViewController, ARSessionDelegate {
    @IBOutlet var arView: ARView!
    
    // Dictionary to keep track of AnchorEntities
    var anchorEntities: [UUID: AnchorEntity] = [:]
    var planes = [Plane]()
    var detector: SmokeDetector?
    var sceneAnchors = [UUID : Plane]()
    var anchorsToBeAdded = [ARPlaneAnchor]()
    var anchorsToBeRemoved = [ARPlaneAnchor]()
    var anchorsToBeUpdated = [ARPlaneAnchor]()
    var isProcessing = false
    
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
        /*
         for anchor in anchors {
         guard let planeAnchor = anchor as? ARPlaneAnchor else { continue }
         if planeAnchor.classification != .ceiling { continue }
         self.anchors.append(planeAnchor)
         
         //let plane = Plane(planeAnchor: planeAnchor)
         //self.planes.append(plane)
         //self.arView.scene.anchors.append(plane)
         
         //if detector == nil {
         //    self.detector = SmokeDetector(planeAnchor: planeAnchor)
         //    self.arView.scene.anchors.append(detector!)
         //}
         }
         */
        if isProcessing { return }
        isProcessing = true
        print("Add Process started...")
        process(anchors: anchors)
        for anchor in self.anchorsToBeAdded {
            let anchorEntity = Plane(planeAnchor: anchor)
            anchorEntity.transform.matrix = anchor.transform
            self.arView.scene.anchors.append(anchorEntity)
            self.sceneAnchors[anchorEntity.planeAnchor.identifier] = anchorEntity
        }
        anchorsToBeAdded.removeAll()
        isProcessing = false
        print("Add Process ended...")
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
//        for anchor in anchors {
//            guard let planeAnchor = anchor as? ARPlaneAnchor else { continue }
//            let plane = planes.first { $0.planeAnchor.identifier == planeAnchor.identifier }
//            plane?.didUpdate(anchor: planeAnchor)
//            if planeAnchor.identifier == detector?.planeAnchor.identifier {
//                detector?.didUpdate(anchor: planeAnchor)
//            }
//        }
        if isProcessing { return }
        isProcessing = true
        print("Update Process started...")
        print("didUpdate anchors: \(anchors)")
        process(anchors: anchors)
        for anchor in self.anchorsToBeUpdated {
            let updatedAnchor = self.sceneAnchors[anchor.identifier]
            updatedAnchor?.didUpdate(anchor: anchor)
        }
        anchorsToBeUpdated.removeAll()
        isProcessing = false
        print("Update Process ended...")
    }

    func process(anchors: [ARAnchor]) {
        var anchorsToProcess = [ARPlaneAnchor]()
        for anchor in anchors {
            guard let planeAnchor = anchor as? ARPlaneAnchor else { continue }
            if planeAnchor.classification == .ceiling {
                anchorsToProcess.append(planeAnchor)
            }
        }
        print("\(anchorsToProcess.count)")
        
        if anchorsToProcess.isEmpty { return }
        
        if anchorsToProcess.count == 1 && self.sceneAnchors.isEmpty {
            print("Adding: \(anchorsToProcess.first!)")
            self.anchorsToBeAdded.append(anchorsToProcess.first!)
            return
        }
        
        if anchorsToProcess.count == 1 && self.sceneAnchors.first?.key == anchorsToProcess.first?.identifier {
            print("Updating: \(anchorsToProcess.first!)")
            self.anchorsToBeUpdated.append(anchorsToProcess.first!)
            return
        }
        
        for a1 in anchorsToProcess {
            var isNonDominant = false
            for a2 in anchorsToProcess {
                if a1.identifier == a2.identifier { continue }
                if !a1.intersects(a2) { continue }
                if a1 < a2 {
                    isNonDominant = true
                    break
                }
            }
            if isNonDominant { continue }
            if self.sceneAnchors.contains(where: { $0.key == a1.identifier }) {
                self.anchorsToBeUpdated.append(a1)
            } else {
                self.anchorsToBeAdded.append(a1)
            }
        }
    }
    
}

extension ARPlaneAnchor {
    func intersects(_ other: ARPlaneAnchor) -> Bool {
        // Extract boundary vertices for both planes
        let selfVertices = self.geometry.boundaryVertices
        let otherVertices = other.geometry.boundaryVertices
        
        // Check if any of the vertices of one plane are inside the other plane's boundary
        for vertex in selfVertices {
            if isPointInsideBoundary(vertex, of: other) {
                return true
            }
        }
        
        for vertex in otherVertices {
            if isPointInsideBoundary(vertex, of: self) {
                return true
            }
        }
        
        return false
    }
    
    // Helper function to check if a point is inside a polygon (plane's boundary)
    private func isPointInsideBoundary(_ point: simd_float3, of otherAnchor: ARPlaneAnchor) -> Bool {
        let boundary = otherAnchor.geometry.boundaryVertices
        
        // Use the ray-casting algorithm to check if a point is inside the polygon
        var inside = false
        var j = boundary.count - 1
        
        for i in 0..<boundary.count {
            let vi = boundary[i]
            let vj = boundary[j]
            
            // Check if the point intersects with the edge of the polygon
            if ((vi.z > point.z) != (vj.z > point.z)) &&
                (point.x < (vj.x - vi.x) * (point.z - vi.z) / (vj.z - vi.z) + vi.x) {
                inside.toggle()
            }
            
            j = i
        }
        
        return inside
    }
    
    // Comparison operator "<" (less than)
    static func < (lhs: ARPlaneAnchor, rhs: ARPlaneAnchor) -> Bool {
        let lhsArea = lhs.planeExtent.width * lhs.planeExtent.height
        let rhsArea = rhs.planeExtent.width * rhs.planeExtent.height
        return lhsArea < rhsArea
    }
    
    // Comparison operator ">" (greater than)
    static func > (lhs: ARPlaneAnchor, rhs: ARPlaneAnchor) -> Bool {
        let lhsArea = lhs.planeExtent.width * lhs.planeExtent.height
        let rhsArea = rhs.planeExtent.width * rhs.planeExtent.height
        return lhsArea > rhsArea
    }
    
    // Comparison operator "<=" (less than or equal)
    static func <= (lhs: ARPlaneAnchor, rhs: ARPlaneAnchor) -> Bool {
        let lhsArea = lhs.planeExtent.width * lhs.planeExtent.height
        let rhsArea = rhs.planeExtent.width * rhs.planeExtent.height
        return lhsArea <= rhsArea
    }
    
    // Comparison operator ">=" (greater than or equal)
    static func >= (lhs: ARPlaneAnchor, rhs: ARPlaneAnchor) -> Bool {
        let lhsArea = lhs.planeExtent.width * lhs.planeExtent.height
        let rhsArea = rhs.planeExtent.width * rhs.planeExtent.height
        return lhsArea >= rhsArea
    }
}
