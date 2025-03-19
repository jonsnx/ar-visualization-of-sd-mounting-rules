import ARKit

/**
 Checks if distance to walls is sufficient
 */
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
            if !isMinimumDistanceMaintained(position, targetPosition) {
                return false
            }
        }
        return true
    }
    
    func isMinimumDistanceMaintained(_ position: SIMD3<Float>, _ targetPosition: SIMD3<Float>) -> Bool {
        let distance = simd_distance(position, targetPosition)
        if distance < MinDistances.minDistanceToWalls {
            return false
        }
        return true
    }
}
