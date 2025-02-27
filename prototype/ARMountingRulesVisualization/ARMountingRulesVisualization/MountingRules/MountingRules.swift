import ARKit

protocol MountingRule {
    var errorType: MountingErrorType { get }
    func validateRule(for focus: ARRaycastResult, in session: ARSession) async -> Bool
}

class CeilingRule: MountingRule {
    var errorType: MountingErrorType {
        return .ceilingRuleError
    }
    
    func validateRule(for focus: ARRaycastResult, in arSession: ARSession) async -> Bool {
        guard let plane = focus.anchor as? ARPlaneAnchor
        else { return false }
        return plane.classification == .ceiling
    }
}

class WallRule: MountingRule {
    var errorType: MountingErrorType {
        return .wallRuleError
    }
    
    func validateRule(for focus: ARRaycastResult, in arSession: ARSession) async -> Bool {
        let position = focus.worldTransform.translation
        let raycasts = RaycastUtil.performRaycastsAroundYAxis(
            in: arSession,
            from: position
        )
        for rc in raycasts {
            let targetPosition = rc.result.worldTransform.translation
            let distance = simd_distance(position, targetPosition)
            if distance < 0.5 {
                return false
            }
        }
        return true
    }
}

class WindowDoorRule: MountingRule {
    var errorType: MountingErrorType {
        return .windowOrDoorRuleError
    }
    
    func validateRule(for focus: ARRaycastResult, in arSession: ARSession) async -> Bool {
        guard let anchors = arSession.currentFrame?.anchors
        else { return false }
        let position = focus.worldTransform.translation
        var meshAnchors = anchors.compactMap({ $0 as? ARMeshAnchor })
        let cutoffDistance: Float = MountingRuleConstants.minDistanceToWindowOrDoor
        meshAnchors.removeAll { distance($0.transform.translation, position) > cutoffDistance }
        for anchor in meshAnchors {
            for index in 0..<anchor.geometry.faces.count {
                if [.window, .door].contains(anchor.geometry.classificationOf(faceWithIndex: index)) {
                    let geometricCenterOfFace = anchor.geometry.centerOf(faceWithIndex: index)
                    var centerLocalTransform = matrix_identity_float4x4
                    centerLocalTransform.columns.3 = SIMD4<Float>(geometricCenterOfFace.0, geometricCenterOfFace.1, geometricCenterOfFace.2, 1)
                    let centerWorldPosition = (anchor.transform * centerLocalTransform).translation
                    let distanceToFace = distance(centerWorldPosition, position)
                    if distanceToFace <= MountingRuleConstants.minDistanceToWindowOrDoor {
                        return false
                    }
                }
            }
        }
        return true
    }
}

enum MountingErrorType {
    case ceilingRuleError
    case wallRuleError
    case windowOrDoorRuleError
    case none
    
    var message: String {
        switch self {
        case .ceilingRuleError:
            return "Richten Sie die Kamera auf die Decke!"
        case .wallRuleError:
            return "Der Abstand zu umgebenen Wänden ist zu gering."
        case .windowOrDoorRuleError:
            return "Der Abstand zu Fenstern oder Türen ist zu gering."
        case .none:
            return ""
        }
    }
}
