import ARKit

/**
 Checks if distance to windows or doors  is sufficient
 */
class WindowDoorRule: MountingRule {
    var errorType: MountingErrorType {
        return .windowOrDoorRuleError
    }
    
    func validateRule(for focus: ARRaycastResult, in arSession: ARSession) async -> Bool {
        guard let anchors = arSession.currentFrame?.anchors
        else { return false }
        let position = focus.worldTransform.translation
        var meshAnchors = anchors.compactMap({ $0 as? ARMeshAnchor })
        let cutoffDistance: Float = MinDistances.minDistanceToWindowOrDoor
        meshAnchors.removeAll { distance($0.transform.translation, position) > cutoffDistance }
        for anchor in meshAnchors {
            for index in 0..<anchor.geometry.faces.count {
                if isAnchorClassifiedAsWindowOrDoor(anchor, index) {
                    if isMinimumDistanceMaintained(anchor, index, position) {
                        return false
                    }
                }
            }
        }
        return true
    }
    
    func isAnchorClassifiedAsWindowOrDoor(_ anchor: ARMeshAnchor, _ index: Int) -> Bool {
        return [.window, .door].contains(anchor.geometry.classificationOf(faceWithIndex: index))
    }
    
    func isMinimumDistanceMaintained(_ anchor: ARMeshAnchor, _ index: Int, _ position: SIMD3<Float>) -> Bool {
        let geometricCenterOfFace = anchor.geometry.centerOf(faceWithIndex: index)
        var centerLocalTransform = matrix_identity_float4x4
        centerLocalTransform.columns.3 = SIMD4<Float>(geometricCenterOfFace.0, geometricCenterOfFace.1, geometricCenterOfFace.2, 1)
        let centerWorldPosition = (anchor.transform * centerLocalTransform).translation
        let distanceToFace = distance(centerWorldPosition, position)
        if distanceToFace <= MinDistances.minDistanceToWindowOrDoor {
            return false
        }
        return true
    }
}
