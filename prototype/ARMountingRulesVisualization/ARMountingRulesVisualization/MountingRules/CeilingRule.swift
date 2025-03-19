import ARKit

/**
 Checks if current position is on a ceiling plane
 */
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
