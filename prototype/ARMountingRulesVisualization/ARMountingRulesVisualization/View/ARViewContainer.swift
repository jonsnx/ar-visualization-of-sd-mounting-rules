import SwiftUI
import Combine
import ARKit
import RealityKit

struct ARViewWrapper: UIViewRepresentable {
    @ObservedObject var arViewModel: ARViewModel
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.session = arViewModel.arSession
        arView.environment.sceneUnderstanding.options = []
        arView.debugOptions.insert(.showSceneUnderstanding)
        arView.renderOptions = [.disablePersonOcclusion, .disableDepthOfField, .disableMotionBlur]
        arView.automaticallyConfigureSession = false
        for entity in arViewModel.scene {
            arView.scene.addAnchor(entity)
        }
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) { }
}
