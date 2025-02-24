import ARKit
import RealityKit

class Plane: Entity, HasModel, HasAnchoring {
    var planeAnchor: ARPlaneAnchor
    
    required init() { fatalError("No implementation for default initializer") }
    
    init(planeAnchor: ARPlaneAnchor) {
        self.planeAnchor = planeAnchor
        super.init()
        let planeAnchorRotation = planeAnchor.planeExtent.rotationOnYAxis
        
        let validPlaneModel = ModelEntity(
            mesh: generatePlaneGeometry(SIMD3<Float>(MountingRules.minDistanceToWalls,0,MountingRules.minDistanceToWalls)),
            materials: [generateUnlitMaterial(color: .green, opacity: 0.5)]
        )
        validPlaneModel.position = getCenterPosition()
        validPlaneModel.transform.rotation = getQuaternionAroundYAxis(from: planeAnchorRotation)
        self.addChild(validPlaneModel)
        
        let invalidPlaneModel = ModelEntity(
            mesh: generatePlaneGeometry(),
            materials: [generateUnlitMaterial(color: .red, opacity: 0.5)]
        )
        invalidPlaneModel.position = getCenterPosition(y: -0.01)
        invalidPlaneModel.transform.rotation = getQuaternionAroundYAxis(from: planeAnchorRotation)
        self.addChild(invalidPlaneModel)
    }
    
    func didUpdate(anchor: ARPlaneAnchor) {
        planeAnchor = anchor
        let planeAnchorRotation = planeAnchor.planeExtent.rotationOnYAxis
        let model = self.children[0] as! ModelEntity
        model.model?.mesh = generatePlaneGeometry(SIMD3<Float>(MountingRules.minDistanceToWalls,0,MountingRules.minDistanceToWalls))
        model.position = getCenterPosition()
        model.transform.rotation = getQuaternionAroundYAxis(from: planeAnchorRotation)
        
        let model2 = self.children[1] as! ModelEntity
        model2.model?.mesh = generatePlaneGeometry()
        model2.position = getCenterPosition(y: -0.01)
        model2.transform.rotation = getQuaternionAroundYAxis(from: planeAnchorRotation)
    }
    
    private func getCenterPosition(y: Float = 0) -> SIMD3<Float> {
        return [planeAnchor.center.x, y, planeAnchor.center.z]
    }
    
    private func generatePlaneGeometry(_ boundaries: SIMD3<Float> = [0, 0, 0]) -> MeshResource {
        return MeshResource.generatePlane(
            width: self.planeAnchor.planeExtent.width - 2 * boundaries[0],
            depth: self.planeAnchor.planeExtent.height - 2 * boundaries[2]
        )
    }
    
    private func generateUnlitMaterial(color: UIColor, opacity: PhysicallyBasedMaterial.Opacity) -> UnlitMaterial {
        var material = UnlitMaterial(color: color)
        material.blending = .transparent(opacity: opacity)
        return material
    }
    
    private func getQuaternionAroundYAxis(from angle: Float) -> simd_quatf {
        return simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
    }
}
