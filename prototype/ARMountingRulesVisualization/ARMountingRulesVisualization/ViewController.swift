import RealityKit
import ARKit
import FocusEntity
import Combine

class ViewController: UIViewController, ARSessionDelegate {
    private var focusEntity: FocusEntity!
    private var arView: ARView!
    private var cancellables: Set<AnyCancellable> = []
    private var detector: AnchorEntity?
    
    var arManager = ARManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        subscribeToActionStream()
        
        arView = ARView(frame: view.bounds)
        arView.session.delegate = self
        view.addSubview(arView)
        
        arView.environment.sceneUnderstanding.options = []
        arView.environment.sceneUnderstanding.options.insert(.physics)
        //arView.debugOptions.insert(.showSceneUnderstanding)
        arView.renderOptions = [.disablePersonOcclusion, .disableDepthOfField, .disableMotionBlur]
        
        arView.automaticallyConfigureSession = false
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.sceneReconstruction = .meshWithClassification
        arView.session.run(configuration)
        focusEntity = FocusEntity.init(on: arView, focus: FocusEntityComponent.detector)
    }
    
    /*
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
         Task {
         await processAnchors(anchors: anchors)
         }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        /*
         Task {
         await processAnchors(anchors: anchors)
         }
         */
    }
    
    func processAnchors(anchors: [ARAnchor]) async {
        if arManager.isProcessing { return }
        arManager.toggleIsProcessing()
        
        let (addedAnchors, removedAnchors) = await arManager.process(anchors: anchors)
        
        addedAnchors.forEach({ arView.scene.addAnchor($0) })
        removedAnchors.forEach({ arView.scene.anchors.remove($0) })
        
        arManager.toggleIsProcessing()
    }
    
    func placeDetector() {
        guard let focusEntity = self.focusEntity else { return }
        removeDetector()
        let modelEntity = ModelEntity.init(mesh: MeshResource.generateCylinder(height: 0.05, radius: 0.05), materials: [SimpleMaterial(color: .white, roughness: 0.5, isMetallic: true)])
        let anchorEntity = AnchorEntity(world: focusEntity.position)
        anchorEntity.addChild(modelEntity)
        detector = anchorEntity
        arView.scene.addAnchor(detector!)
    }
    */
    
    func removeDetector() {
        guard let detector else { return }
        arView.scene.anchors.remove(detector)
        self.detector = nil
    }
    
    func subscribeToActionStream() {
        ActionManager.shared
            .actionStream
            .sink { [weak self] action in
                
                switch action {
                    
                case .place3DModel:
                    self?.placeDetector()
                    
                case .remove3DModel:
                    self?.removeDetector()
                }
            }
            .store(in: &cancellables)
    }
}
