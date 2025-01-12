import RealityKit
import ARKit
import FocusEntity
import Combine

class ViewController: UIViewController, ARSessionDelegate {
    private var focusEntity: FocusEntity!
    private var arView: ARView!
    private var actionCancellables: Set<AnyCancellable> = []
    private var updateCancellable: (any Cancellable)?
    private var detector: SmokeDetector?
    private var distanceIndicators: DistanceIndicators?
    private var showCeilingPlane: Bool = false
    private var currentSurroundings = [RaycastData]()
    
    
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
        arView.session.run(WorldTrackingConfiguration.instance.config)
        let focusEntityComponent: FocusEntityComponent = .init(
            onColor: .green,
            offColor: .red,
            mesh: .generateCylinder(height: 0.05, radius: 0.05)
        )
        let cameraAnchor = AnchorEntity(.camera)
        arView.scene.addAnchor(cameraAnchor)
        focusEntity = .init(focus: focusEntityComponent, cameraAnchor: cameraAnchor, getCurrentCameraRotation: {
            return self.arView.cameraTransform.rotation
        })
        arView.scene.addAnchor(focusEntity)
        self.updateCancellable = arView.scene.subscribe(
            to: SceneEvents.Update.self, self.processFrame
        )
    }
    
    fileprivate func setupARView() {
        arView = ARView(frame: view.bounds)
        arView.session.delegate = self
        view.addSubview(arView)
        arView.environment.sceneUnderstanding.options = []
        arView.environment.sceneUnderstanding.options.insert(.physics)
        // arView.environment.sceneUnderstanding.options.insert(.occlusion)
        arView.debugOptions.insert(.showSceneUnderstanding)
        arView.renderOptions = [.disablePersonOcclusion, .disableDepthOfField, .disableMotionBlur]
        arView.automaticallyConfigureSession = false
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        Task {
            await processAnchors(anchors)
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        Task {
            await processAnchors(anchors)
        }
    }
    
    public func updateFocusEntity() {
        guard let camera = self.arView?.session.currentFrame?.camera,
              case .normal = camera.trackingState,
              let (camPos, camDir) = self.getCamVector(),
              let session = self.arView?.session,
              let result = RaycastUtil.smartRaycast(in: session, from: camPos, to: camDir)
        else {
            focusEntity.putInFrontOfCamera()
            focusEntity.state = .initializing
            return
        }
        focusEntity.state = .tracking(raycastResult: result, camera: camera)
    }
    
    func getCamVector() -> (position: SIMD3<Float>, direciton: SIMD3<Float>)? {
        let camTransform = self.arView.cameraTransform
        let camDirection = camTransform.matrix.columns.2
        return (camTransform.translation, -[camDirection.x, camDirection.y, camDirection.z])
    }
    
    func processAnchors(_ anchors: [ARAnchor]) async {
        if !arManager.isProcessingAnchors && showCeilingPlane {
            arManager.toggleIsProcessingAnchors()
            let (addedAnchors, removedAnchors) = await arManager.processAnchors(anchors: anchors)
            addedAnchors.forEach({ arView.scene.addAnchor($0) })
            removedAnchors.forEach({ arView.scene.anchors.remove($0) })
            arManager.toggleIsProcessingAnchors()
        }
    }
    
    func processFrame(event: SceneEvents.Update? = nil) {
        print("In processFrame now...")
        updateFocusEntity()
        Task {
            print("Executing Task now...")
            self.currentSurroundings = await RaycastUtil.performRaycastsAroundYAxis(in: arView.session, from: focusEntity.position, numberOfRaycasts: 30)
            if !arManager.isProcessingFrame && focusEntity.isOnCeiling {
                arManager.toggleIsProcessingFrame()
                focusEntity.isPlaceable = await arManager.isPlaceable(at: focusEntity.position, for: self.currentSurroundings, with: arView.session.currentFrame)
                print("isPlaceable was called: isPlaceable now \(focusEntity.isPlaceable)")
                arManager.toggleIsProcessingFrame()
            }
        }
    }
    
    func placeDetector() {
        guard let focusEntity = focusEntity else { return }
        if !focusEntity.isPlaceable { return }
        let position = focusEntity.position
        Task {
            if detector == nil && distanceIndicators == nil {
                detector = SmokeDetector(worldPosition: focusEntity.position)
                arView.scene.addAnchor(detector!)
                if self.currentSurroundings.isEmpty {
                    self.currentSurroundings = await RaycastUtil.performRaycastsAroundYAxis(in: arView.session, from: position, numberOfRaycasts: 30)
                }
                distanceIndicators = DistanceIndicators(from: focusEntity.position, around: self.currentSurroundings)
                arView.scene.addAnchor(distanceIndicators!)
                return
            }
            await updateDistanceIndicators(position: position)
            detector?.moveTo(worldPosition: focusEntity.position)
        }
    }
    
    func removeDetector() {
        guard let detector = self.detector,
              let distanceIndicators = self.distanceIndicators else { return }
        arView.scene.anchors.remove(detector)
        self.detector = nil
        arView.scene.anchors.remove(distanceIndicators)
        self.distanceIndicators = nil
    }
    
    func updateDistanceIndicators(position: SIMD3<Float>) async {
        guard let distanceIndicators = self.distanceIndicators else { return }
        arView.scene.anchors.remove(distanceIndicators)
        if self.currentSurroundings.isEmpty {
            self.currentSurroundings = await RaycastUtil.performRaycastsAroundYAxis(in: arView.session, from: position, numberOfRaycasts: 30)
        }
        self.distanceIndicators = DistanceIndicators(from: focusEntity.position, around: self.currentSurroundings)
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
            .store(in: &actionCancellables)
    }
}

// TODO:
// [X] add UI-Elements (Buttons, Text, etc.)
// [ ] fix rotation of distance indicator text
// [ ] overhaul ARManager
// [ ] fix general Architecture
// [X] remove unnecessary FocusEntity code
// [ ] think of concept for placed detector screen
// [X] detect distance indicator touching walls
// [X] implement classification of windows and doors
// [ ] implement distance indicator for windows and doors
// [X] fix bug where distance indicators are not visible on first placement
// [ ] reconsider mounting rules
// [X] add infos for various actions such as placedDetector, detectorNotPlaceable
// [ ] implement partially indication of distance error
// [X] implement transition of scale animation for crosshair when moved to ceiling
// [ ] implement reset
// [X] implement delete
// [ ] implement info screen
// [ ] implement coaching overlay
