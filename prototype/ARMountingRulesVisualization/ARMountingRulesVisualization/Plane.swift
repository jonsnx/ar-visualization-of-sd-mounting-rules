import ARKit
import RealityKit

class Plane: Entity, HasModel, HasAnchoring {
    var planeAnchor: ARPlaneAnchor
    var planeGeometry: MeshResource!
    
    init(planeAnchor: ARPlaneAnchor) {
        self.planeAnchor = planeAnchor
        super.init()
        self.didSetup()
    }
        
    func didSetup() {
        self.planeGeometry = .generatePlane(width: planeAnchor.planeExtent.width,
                                            depth: planeAnchor.planeExtent.height)
        let material: UnlitMaterial = .init(color: .red)
        let model = ModelEntity(mesh: planeGeometry, materials: [material])
        model.position = [planeAnchor.center.x, 0, planeAnchor.center.z]
        self.addChild(model)
    }
    
    func didUpdate(anchor: ARPlaneAnchor) {
        self.planeGeometry = .generatePlane(width: anchor.planeExtent.width,
                                            depth: anchor.planeExtent.height)
        let pose: SIMD3<Float> = [anchor.center.x, 0, anchor.center.z]
        let model = self.children[0] as! ModelEntity
        model.position = pose
    }
    required init() { fatalError("Hasn't been implemented yet") }
}
