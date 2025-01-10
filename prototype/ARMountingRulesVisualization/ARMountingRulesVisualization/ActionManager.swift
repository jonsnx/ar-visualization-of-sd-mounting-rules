import Combine

enum Actions {
    case placeDetector
    case removeDetector
    case showInfoText(text: String)
    case hideInfoText
}

class ActionManager {
    static let shared = ActionManager()
    
    private init() { }
    
    var actionStream = PassthroughSubject<Actions, Never>()
}
