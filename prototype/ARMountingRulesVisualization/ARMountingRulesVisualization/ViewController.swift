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
    private var showCeilingPlane: Bool = false
    
    
    var isOnCeiling: Bool {
        return focusEntity?.isOnCeiling ?? false
    }
    
    var isPlaceable: Bool {
        return focusEntity?.isPlaceable ?? false
    }
    
    var arManager = ARManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        subscribeToActionStream()
        subscribeToFocusEntity()
        setupARView()
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.sceneReconstruction = .meshWithClassification
        arView.session.run(configuration)
        let focusEntityComponent: FocusEntityComponent = .init(
            onColor: .green,
            offColor: .red,
            mesh: .generateCylinder(height: 0.05, radius: 0.05)
        )
        focusEntity = .init(on: arView, focus: focusEntityComponent)
    }
    
    fileprivate func setupARView() {
        arView = ARView(frame: view.bounds)
        arView.session.delegate = self
        view.addSubview(arView)
        arView.environment.sceneUnderstanding.options = []
        arView.environment.sceneUnderstanding.options.insert(.physics)
        //arView.environment.sceneUnderstanding.options.insert(.occlusion)
        arView.debugOptions.insert(.showSceneUnderstanding)
        arView.renderOptions = [.disablePersonOcclusion, .disableDepthOfField, .disableMotionBlur]
        arView.automaticallyConfigureSession = false
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        if showCeilingPlane {
            Task {
                await processAnchors(anchors: anchors)
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        if showCeilingPlane {
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
        if !focusEntity.isPlaceable { return }
        let position = focusEntity.position
        if detector == nil && distanceIndicators == nil {
            detector = SmokeDetector(worldPosition: focusEntity.position)
            arView.scene.addAnchor(detector!)
            let raycastData = RaycastUtil.performRaycastsAroundYAxis(in: arView.session, from: position, numberOfRaycasts: 30)
            distanceIndicators = DistanceIndicators(from: focusEntity.position, around: raycastData)
            arView.scene.addAnchor(distanceIndicators!)
            return
        }
        updateDistanceIndicators(position: position)
        detector?.moveTo(worldPosition: focusEntity.position)
    }
    
    func removeDetector() {
        guard let detector = self.detector,
        let distanceIndicators = self.distanceIndicators else { return }
        arView.scene.anchors.remove(detector)
        self.detector = nil
        arView.scene.anchors.remove(distanceIndicators)
        self.distanceIndicators = nil
    }
    
    func updateDistanceIndicators(position: SIMD3<Float>) {
        guard let distanceIndicators = self.distanceIndicators else { return }
        arView.scene.anchors.remove(distanceIndicators)
        let raycastData = RaycastUtil.performRaycastsAroundYAxis(in: arView.session, from: position, numberOfRaycasts: 30)
        self.distanceIndicators = DistanceIndicators(from: focusEntity.position, around: raycastData)
        arView.scene.addAnchor(self.distanceIndicators!)
    }
    
    private func updateInfoCardText() {
        if !isOnCeiling && !isPlaceable {
            ActionManager.shared.actionStream.send(.showInfoText(text: "Point the camera to the ceiling!"))
        } else if isOnCeiling && !isPlaceable {
            ActionManager.shared.actionStream.send(.showInfoText(text: "Mounting of SmokeDetector is not possible here!"))
        } else {
            ActionManager.shared.actionStream.send(.hideInfoText)
        }
    }
    
    private func subscribeToFocusEntity() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.updateInfoCardText()
        }
    }
    
    func subscribeToActionStream() {
        ActionManager.shared
            .actionStream
            .sink { [weak self] action in
                switch action {
                case .placeDetector:
                    self?.placeDetector()
                case .removeDetector:
                    self?.removeDetector()
                case .showInfoText, .hideInfoText:
                    return
                }
            }
            .store(in: &cancellables)
    }
}

// TODO:
// [X] add UI-Elements (Buttons, Text, etc.)
// [ ] overhaul ARManager
// [ ] fix general Architecture
// [X] remove unnecessary FocusEntity code
// [ ] think of concept for placed detector screen
// [X] detect distance indicator touching walls
// [ ] implement classification of windows and doors
// [ ] implement distance indicator for windows and doors
// [X] fix bug where distance indicators are not visible on first placement
// [ ] reconsider mounting rules
// [ ] add infos for various actions such as placedDetector, detectorNotPlaceable
// [ ] implement partially indication of distance error
// [ ] implement transition of scale animation for crosshair when moved to ceiling
// [ ] implement reset
// [X] implement delete
// [ ] implement info screen
