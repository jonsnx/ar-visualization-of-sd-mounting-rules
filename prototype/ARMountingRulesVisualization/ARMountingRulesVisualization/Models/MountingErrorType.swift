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
