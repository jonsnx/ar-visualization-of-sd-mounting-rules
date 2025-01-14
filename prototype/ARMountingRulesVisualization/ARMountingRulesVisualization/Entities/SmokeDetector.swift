import ARKit
import RealityKit

class SmokeDetector: Entity, HasModel, HasAnchoring {
    private let size: Float = 0.05
    
    required init() { fatalError("No implementation for default initializer") }
    
    init(worldPosition: SIMD3<Float>) {
        super.init()
        self.position = worldPosition
        let planeGeometry: MeshResource = .generateCylinder(height: size, radius: size)
        let material: SimpleMaterial = .init(color: .white, isMetallic: true)
        self.model = ModelComponent(mesh: planeGeometry, materials: [material])
    }
    
    func moveTo(worldPosition: SIMD3<Float>) {
        self.position = worldPosition
    }
}
