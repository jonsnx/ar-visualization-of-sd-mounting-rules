import SwiftUI
import Combine

struct ARViewContainer: UIViewControllerRepresentable {
    @Binding var infoText: String

    func updateUIViewController(_ uiViewController: ViewController, context: Context) {
        // update here
    }
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ARViewContainer>) -> ViewController {
        let viewController = ViewController()
        ActionManager.shared.actionStream
            .sink { [self] action in
                switch action {
                case .showInfoText(text: let newText):
                    self.infoText = newText
                case .hideInfoText:
                    self.infoText = ""
                case .placeDetector, .removeDetector:
                    return
                }
            }
            .store(in: &context.coordinator.cancellables)  // Store the subscription
        return viewController
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
}

class Coordinator: NSObject {
    var cancellables: Set<AnyCancellable> = []
}
