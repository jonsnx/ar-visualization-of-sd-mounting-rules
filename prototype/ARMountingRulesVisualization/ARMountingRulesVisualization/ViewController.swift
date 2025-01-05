import RealityKit
import ARKit
import FocusEntity
import Combine

class ViewController: UIViewController, ARSessionDelegate {
    private var focusEntity: FocusEntity!
    private var arView: ARView!
    private var cancellables: Set<AnyCancellable> = []
    private var detector: SmokeDetector?
    
    var arManager = ARManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        subscribeToActionStream()
        
        arView = ARView(frame: view.bounds)
        arView.session.delegate = self
        view.addSubview(arView)
        
        arView.environment.sceneUnderstanding.options = []
        arView.environment.sceneUnderstanding.options.insert(.physics)
        arView.environment.sceneUnderstanding.options.insert(.occlusion)
        //arView.debugOptions.insert(.showSceneUnderstanding)
        arView.renderOptions = [.disablePersonOcclusion, .disableDepthOfField, .disableMotionBlur]
        
        arView.automaticallyConfigureSession = false
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.sceneReconstruction = .meshWithClassification
        arView.session.run(configuration)
        focusEntity = .init(on: arView, focus: FocusEntityComponent.detector)
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
    */
    
    func placeDetector() {
        guard let focusEntity = focusEntity else { return }
        if !focusEntity.onPlane { return }
        if self.detector == nil {
            self.detector = SmokeDetector(worldPosition: focusEntity.position)
            arView.scene.addAnchor(self.detector!)
            return
        }
        self.detector?.moveTo(worldPosition: focusEntity.position)
    }
    
    func removeDetector() {
        if self.detector == nil { return }
        guard let detector = self.detector else { return }
        arView.scene.anchors.remove(detector)
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
