import SwiftUI

struct ARViewContainer: UIViewControllerRepresentable {
    func updateUIViewController(_ uiViewController: ViewController, context: Context) {
        // update here
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<ARViewContainer>) -> ViewController {
        let viewController = ViewController()
        return viewController
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
}
