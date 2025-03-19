import RealityKit
import ARKit

class DistanceIndicators: Entity, HasModel, HasAnchoring {
    let lineMaterial = UnlitMaterial.init(color: .magenta)
    
    required init() {
        fatalError("No implementation of default init available.")
    }
    
    init(from position: SIMD3<Float>, around raycastData: [RaycastData]) {
        super.init()
        self.name = "DistanceIndicators"
        for data in raycastData {
            guard let plane = data.result.anchor as? ARPlaneAnchor else { continue }
            let planeNormal = plane.calculateNormalVetor()
            if isAngleBetweenVectorsAlmostZero(data.direction, planeNormal) {
                var targetPosition = data.result.worldTransform.translation
                targetPosition.y += RaycastConstants.raycastOffset
                addLineEntity(from: position, to: targetPosition, showDistanceLabel: true)
            }
        }
    }
    
    private func isAngleBetweenVectorsAlmostZero(_ rayDirection: SIMD3<Float>, _ planeNormal: SIMD3<Float>) -> Bool {
        let normalizedScalar = simd_dot(rayDirection, planeNormal) / (simd_length(planeNormal) * simd_length(rayDirection))
        return normalizedScalar > (1 - EntityConstants.angleThreshold)
            || normalizedScalar < (-1 + EntityConstants.angleThreshold)
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
        let meshResource = MeshResource.generateBox(width:0.005, height: 0, depth: meters)
        let bottomLineEntity = ModelEntity(mesh: meshResource, materials: [lineMaterial])
        anchor.addChild(bottomLineEntity)
        if showDistanceLabel {
            addDistanceLabel(anchor, meters)
        }
        self.addChild(anchor)
    }
    
    private func addDistanceLabel(_ anchor: AnchorEntity, _ distance: Float) {
        let font = MeshResource.Font.systemFont(ofSize: 0.05)
        let textMesh = MeshResource.generateText("\(String(format: "%.2f", distance))m", extrusionDepth: 0, font: font)
        let textEntity = ModelEntity(mesh: textMesh, materials: [lineMaterial])
        textEntity.transform.rotation *= simd_quatf(angle: 90.0 * .pi/180.0, axis: SIMD3<Float>(0, 1, 0))
        textEntity.transform.rotation *= simd_quatf(angle: 90.0 * .pi/180.0, axis: SIMD3<Float>(1, 0, 0))
        textEntity.position.x -= textEntity.visualBounds(relativeTo: nil).extents.x / 2
        anchor.addChild(textEntity)
    }
}
