import ARKit

class MountingRuleManager {
    private var rules: [MountingRule] = []

    init(rules: [MountingRule]) {
        self.rules = rules
    }

    func validateRules(for focus: ARRaycastResult, in arSession: ARSession) async -> (isValid: Bool, errorType: MountingErrorType) {
        for rule in rules {
            if await !rule.validateRule(for: focus, in: arSession) {
                return (false, rule.errorType)
            }
        }
        return (true, .none)
    }
}
