import RealityKit
import ARKit
import FocusEntity
import Combine

class ViewController: UIViewController, ARSessionDelegate {
    private var focusEntity: FocusEntity!
    private var arView: ARView!
    private var cancellables: Set<AnyCancellable> = []
    private var detector: SmokeDetector?
    private var distanceIndicators: DistanceIndicators?
    private var isCeilingPlaneVisible: Bool = false
    
    var arManager = ARManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        subscribeToActionStream()
        
        arView = ARView(frame: view.bounds)
        arView.session.delegate = self
        view.addSubview(arView)
        
        arView.environment.sceneUnderstanding.options = []
        arView.environment.sceneUnderstanding.options.insert(.physics)
        //arView.environment.sceneUnderstanding.options.insert(.occlusion)
        arView.debugOptions.insert(.showSceneUnderstanding)
        arView.renderOptions = [.disablePersonOcclusion, .disableDepthOfField, .disableMotionBlur]
        
        arView.automaticallyConfigureSession = false
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.sceneReconstruction = .meshWithClassification
        arView.session.run(configuration)
        focusEntity = .init(on: arView, focus: FocusEntityComponent.detector)
    }
    
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        if isCeilingPlaneVisible {
            Task {
                await processAnchors(anchors: anchors)
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        if isCeilingPlaneVisible {
            Task {
                await processAnchors(anchors: anchors)
            }
        }
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
        guard let focusEntity = focusEntity else { return }
        if !focusEntity.onPlane { return }
        let position = focusEntity.position
        if self.detector == nil && self.distanceIndicators == nil {
            self.detector = SmokeDetector(worldPosition: focusEntity.position)
            arView.scene.addAnchor(self.detector!)
            let raycastData = RaycastUtil.performRaycastsAroundYAxis(in: arView.session, from: position, numberOfRaycasts: 30)
            self.distanceIndicators = DistanceIndicators(from: focusEntity.position, around: raycastData)
            arView.scene.anchors.remove(self.distanceIndicators!)
            return
        }
        updateDistanceIndicators(position: position)
        self.detector?.moveTo(worldPosition: focusEntity.position)
    }
    
    func removeDetector() {
        guard let detector = self.detector else { return }
        arView.scene.anchors.remove(detector)
    }
    
    func updateDistanceIndicators(position: SIMD3<Float>) {
        guard let distanceIndicators = self.distanceIndicators else { return }
        arView.scene.anchors.remove(distanceIndicators)
        let raycastData = RaycastUtil.performRaycastsAroundYAxis(in: arView.session, from: position, numberOfRaycasts: 30)
        self.distanceIndicators = DistanceIndicators(from: focusEntity.position, around: raycastData)
        arView.scene.addAnchor(self.distanceIndicators!)
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
