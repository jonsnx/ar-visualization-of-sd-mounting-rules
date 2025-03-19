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
                targetPosition.y += RaycastConstants.raycastOffset
                addLineEntity(from: position, to: targetPosition, showDistanceLabel: true)
            }
        }
    }
    
    init(from start: SIMD3<Float>, to end: SIMD3<Float>) {
        super.init()
        addLineEntity(from: start, to: end)
    }
    
    private func addLineEntity(from start: SIMD3<Float>, to end: SIMD3<Float>, showDistanceLabel: Bool = false) {
        let midPosition = SIMD3(
            x:(start.x + end.x) / 2,
            y:(start.y + end.y) / 2,
            z:(start.z + end.z) / 2
        )
        let anchor = AnchorEntity()
        anchor.position = midPosition
        anchor.look(at: start, from: midPosition, relativeTo: nil)
        let meters = simd_distance(start, end)
        print("Distance: \(meters)m")
        let lineMaterial = UnlitMaterial.init(color: .magenta)
        let bottomLineMesh = MeshResource.generateBox(width:0.005, height: 0, depth: meters)
        let bottomLineEntity = ModelEntity(mesh: bottomLineMesh, materials: [lineMaterial])
        bottomLineEntity.position = .init(0, 0.025, 0)
        anchor.addChild(bottomLineEntity)
        if showDistanceLabel {
            let font = MeshResource.Font.systemFont(ofSize: 0.05)
            let textMesh = MeshResource.generateText("\(String(format: "%.2f", meters))m", extrusionDepth: 0, font: font)
            let textEntity = ModelEntity(mesh: textMesh, materials: [lineMaterial])
            // TODDO: fix orientation of text
            textEntity.transform.rotation *= simd_quatf(angle: 90.0 * .pi/180.0, axis: SIMD3<Float>(0, 1, 0))
            textEntity.transform.rotation *= simd_quatf(angle: 90.0 * .pi/180.0, axis: SIMD3<Float>(1, 0, 0))
            textEntity.position.x -= textEntity.visualBounds(relativeTo: nil).extents.x / 2
            anchor.addChild(textEntity)
        }
        self.lines.append(bottomLineEntity)
        self.addChild(anchor)
    }
}

//Real: 1.5m
//Distance: 1.5114754m
//Distance: 1.5054088m

//Real: 2m
//Distance: 2.975608m
//Distance: 2.985186m

//Real: 5m
//Distance: 4.9524994m
//Distance: 4.9443893m
