import RealityKit
import ARKit

class DistanceIndicators: Entity, HasModel, HasAnchoring {
    private var lines = [ModelEntity]()
    
    required init() {
        fatalError("No implementation of default init available.")
    }
    
    init(from position: SIMD3<Float>, around raycastData: [RaycastData]) {
        super.init()
        self.position = position
        for data in raycastData {
            let distance = simd_distance(position, data.result.worldTransform.translation)
            guard let plane = data.result.anchor as? ARPlaneAnchor else { continue }
            print("Distance to plane \(plane): \(distance)")
            let finalWorldNormal = plane.calculateNormalVetor()
            
            let normalizedScalar = simd_dot(data.direction, finalWorldNormal) / (simd_length(finalWorldNormal) * simd_length(data.direction))
            
            let epsilon: Float = 0.005
            
            if  normalizedScalar > (1 - epsilon) || normalizedScalar < (-1 + epsilon) {
                var targetPosition = data.result.worldTransform.translation
                targetPosition.y += 0.2
                addLineEntity(from: position, to: targetPosition)
            }
        }
    }
    
    private func addLineEntity(from start: SIMD3<Float>, to end: SIMD3<Float>) {
        let midPosition = SIMD3(
            x:(start.x + end.x) / 2,
            y:(start.y + end.y) / 2,
            z:(start.z + end.z) / 2
        )
        let anchor = AnchorEntity()
        anchor.position = midPosition
        anchor.look(at: start, from: midPosition, relativeTo: nil)
        let meters = simd_distance(start, end)
        let lineMaterial = UnlitMaterial.init(color: .magenta)
        let bottomLineMesh = MeshResource.generateBox(width:0.005, height: 0, depth: meters)
        let bottomLineEntity = ModelEntity(mesh: bottomLineMesh, materials: [lineMaterial])
        bottomLineEntity.position = .init(0, 0.025, 0)
        anchor.addChild(bottomLineEntity)
        self.lines.append(bottomLineEntity)
        self.addChild(anchor)
    }
}
