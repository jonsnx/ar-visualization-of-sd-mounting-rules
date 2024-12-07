import Foundation
import ARKit

actor ARManager: NSObject, ARSessionDelegate, ObservableObject {
    
    @MainActor let sceneView = ARSCNView()
    @MainActor private var isProcessing = false
    @MainActor @Published var isCapturing = false
    
    @MainActor
    override init() {
        super.init()
        
        sceneView.session.delegate = self

        // start session
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = .sceneDepth
        sceneView.session.run(configuration)
    }
        
    // an ARSessionDelegate function for receiving an ARFrame instances
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        Task { await process(frame: frame) }
    }
        
    // process a frame and skip frames that arrive while processing
    @MainActor
    private func process(frame: ARFrame) async {
        guard !isProcessing else { return }
    
        isProcessing = true
        let pointCloud = PointCloud()
        await pointCloud.process(frame: frame)
        isProcessing = false
    }
}
