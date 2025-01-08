import Combine

enum Actions {
    case placeDetector
    case removeDetector
}

class ActionManager {
    static let shared = ActionManager()
    
    private init() { }
    
    var actionStream = PassthroughSubject<Actions, Never>()
}
