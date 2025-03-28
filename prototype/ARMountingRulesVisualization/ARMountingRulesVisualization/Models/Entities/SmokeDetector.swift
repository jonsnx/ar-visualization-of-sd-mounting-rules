import ARKit
import RealityKit

class SmokeDetector: Entity, HasModel, HasAnchoring {
    required init() { fatalError("No implementation for default initializer") }
    
    init(worldPosition: SIMD3<Float>) {
        super.init()
        self.name = "SmokeDetector"
        self.position = worldPosition
        let planeGeometry: MeshResource = .generateCylinder(
            height: EntityConstants.smokeDetectorSize,
            radius: EntityConstants.smokeDetectorSize
        )
        let material: SimpleMaterial = .init(color: .white, isMetallic: true)
        self.model = ModelComponent(mesh: planeGeometry, materials: [material])
    }
    
    func moveTo(worldPosition: SIMD3<Float>) {
        self.position = worldPosition
    }
}
