import ARKit

protocol MountingRule {
    var errorType: MountingErrorType { get }
    func validateRule(for focus: ARRaycastResult, in session: ARSession) async -> Bool
}
