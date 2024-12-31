import ARKit
import RealityKit

class Plane: Entity, HasModel, HasAnchoring {
    var planeAnchor: ARPlaneAnchor
    
    init(planeAnchor: ARPlaneAnchor) {
        self.planeAnchor = planeAnchor
        super.init()
        self.didSetup()
    }
    
    func didSetup() {
        let planeGeometry: MeshResource = .generatePlane(width: planeAnchor.planeExtent.width,
                                                         depth: planeAnchor.planeExtent.height)
        let material: UnlitMaterial = .init(color: .red)
        let model = ModelEntity(mesh: planeGeometry, materials: [material])
        model.position = [planeAnchor.center.x, 0, planeAnchor.center.z]
        self.addChild(model)
    }
    
    func didUpdate(anchor: ARPlaneAnchor) {
        planeAnchor = anchor
        let planeGeometry: MeshResource = .generatePlane(width: anchor.planeExtent.width,
                                                         depth: anchor.planeExtent.height)
        let pose: SIMD3<Float> = [anchor.center.x, 0, anchor.center.z]
        let model = self.children[0] as! ModelEntity
        let planeRotation = planeAnchor.planeExtent.rotationOnYAxis
        let modelRotation = model.transform.rotation
        print("Anchor rotation: \(planeRotation), Model rotation \(modelRotation)")
        model.model?.mesh = planeGeometry
        model.position = pose
        model.transform.rotation = simd_quatf(angle: planeRotation, axis: SIMD3<Float>(0, 1, 0))
        
    }
    required init() { fatalError("Hasn't been implemented yet") }
    
    private func angleBetweenQuaternions(_ q1: simd_quatf, _ q2: simd_quatf) -> Float {
        let dotProduct = simd_dot(q1, q2)
        let angle = 2 * acos(abs(dotProduct))  // acos returns a value in radians
        return angle
    }

    // Function to rotate one quaternion to match another (relative rotation)
    func rotateQuaternion(_ q1: simd_quatf, toMatch q2: simd_quatf) -> simd_quatf {
        // Inverse of the second quaternion
        let q2Inverse = simd_inverse(q2)
        
        // Compute the relative rotation quaternion
        let qRelative = q2 * q2Inverse
        
        return qRelative
    }
}

extension float4x4 {
    
    /// Returns the translation components of the matrix
    func toTranslation() -> SIMD3<Float> {
        return [self[3,0], self[3,1], self[3,2]]
    }
    
    /// Returns a quaternion representing the
    /// rotation component of the matrix
    func toQuaternion() -> simd_quatf {
        return simd_quatf(self)
    }
}
