import ARKit
import RealityKit

class SmokeDetector: Entity, HasModel, HasAnchoring {
    var planeAnchor: ARPlaneAnchor
    let size: Float = 0.05
    
    required init() { fatalError("No implementation for default initializer") }
    
    init(planeAnchor: ARPlaneAnchor) {
        self.planeAnchor = planeAnchor
        super.init()
        let planeGeometry = MeshResource.generateCylinder(height: size, radius: size)
        let material: SimpleMaterial = .init(color: .darkGray, roughness: 0.5, isMetallic: true)
        let model = ModelEntity(mesh: planeGeometry, materials: [material])
        model.position = getCenterPosition()
        self.addChild(model)
    }
    
    func didUpdate(anchor: ARPlaneAnchor) {
        planeAnchor = anchor
        let model = self.children[0] as! ModelEntity
        model.position = getCenterPosition()
    }
    
    private func getCenterPosition() -> SIMD3<Float> {
        return [planeAnchor.center.x, size, planeAnchor.center.z]
    }
}
