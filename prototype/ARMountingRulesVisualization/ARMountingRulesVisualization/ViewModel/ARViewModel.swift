import Foundation
import ARKit
import RealityKit
import Combine


class ARViewModel: NSObject, ARSessionDelegate, ObservableObject {
    @Published private(set) var scene: [Entity & HasAnchoring] = []
    @Published private(set) var errorType: MountingErrorType = .none
    private(set) var arSession: ARSession = ARSession()
    private let ruleManager: MountingRuleManager!
    private var focusEntity: FocusEntity!
    private var currentFocus: ARRaycastResult?
    private var isProcessing: Bool = false
    private var frameCount: Int = 0
    private(set) var trackingState: TrackingState = .initializing {
        didSet {
            guard trackingState != oldValue else { return }
            switch trackingState {
            case .initializing:
                if oldValue != .initializing {
                    focusEntity.displayAsBillboard()
                }
            case let .tracking(raycastResult):
                let planeAnchor = raycastResult.anchor as? ARPlaneAnchor
                if let planeAnchor = planeAnchor {
                    focusEntity.entityOnPlane(for: raycastResult, planeAnchor: planeAnchor)
                } else {
                    focusEntity.entityOffPlane(raycastResult)
                }
            }
        }
    }
    
    override init() {
        // let variables must be initialized before super.init() call
        self.ruleManager = MountingRuleManager(
            rules: [
                CeilingRule(),
                WallRule(),
                WindowDoorRule()
            ]
        )
        super.init()
        self.arSession.run(WorldTrackingConfiguration.instance.config)
        self.arSession.delegate = self
        initScene()
    }
    
    func initScene() {
        let cameraAnchor = AnchorEntity(.camera)
        focusEntity = FocusEntity(cameraAnchor: cameraAnchor, getCurrentCameraRotation: {
            guard let currentFrame = self.arSession.currentFrame else { return simd_quatf() }
            return currentFrame.camera.transform.orientation
        })
        scene.append(contentsOf: [cameraAnchor, focusEntity])
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        processFrame()
    }
    
    private func processFrame() {
        updateFocusEntity()
        if !isProcessing && frameCount % RaycastConstants.raycastFrequency == 0 {
            isProcessing = true
            Task {
                await validateMountingRules()
            }
            isProcessing = false
        }
        frameCount += 1
    }
    
    private func validateMountingRules() async {
        guard let currentFocus else {
            await setErrorType(.ceilingRuleError)
            return
        }
        let (isValid, errorType) = await ruleManager.validateRules(for: currentFocus, in: arSession)
        if isValid {
            await setIsPlaceable(true)
        } else {
            await setIsPlaceable(false)
        }
        await setErrorType(errorType)
    }
    
    private func updateFocusEntity() {
        guard let camera = arSession.currentFrame?.camera,
              case .normal = camera.trackingState,
              let (camPos, camDir) = CameraUtils.getCamVector(camTransform: camera.transform),
              let result = RaycastUtil.smartRaycast(in: arSession, from: camPos, to: camDir)
        else {
            // Tracking is not functioning as intended
            focusEntity.distanceToDetector = -1.0
            focusEntity.putInFrontOfCamera()
            trackingState = .initializing
            currentFocus = nil
            return
        }
        // Tracking is functioning as intended
        focusEntity.distanceToDetector = calcDistanceBetweenDetectorAndFocus()
        currentFocus = result
        trackingState = .tracking(raycastResult: result)
    }
    
    @MainActor
    private func setIsPlaceable(_ value: Bool) {
        self.focusEntity.isPlaceable = value
    }
    
    @MainActor
    private func setErrorType(_ value: MountingErrorType) {
        self.errorType = value
    }
    
    func placeDetector() {
        guard let position = currentFocus?.worldTransform.translation,
              focusEntity.isPlaceable
        else { return }
        scene.removeAll { $0.name == "SmokeDetector" || $0.name == "DistanceIndicators" }
        let currentSurroundings = RaycastUtil.performRaycastsAroundYAxis(in: arSession, from: position, 30)
        let smokeDetector = SmokeDetector(worldPosition: position)
        let distanceIndicators = DistanceIndicators(from: position, around: currentSurroundings)
        scene.append(contentsOf: [smokeDetector, distanceIndicators])
    }
    
    func removeDetector() {
        scene.removeAll { $0 is SmokeDetector || $0 is DistanceIndicators }
    }
    
    func calcDistanceBetweenDetectorAndFocus() -> Float {
        guard let currentFocus,
              let smokeDetector = scene.first(where: { $0 is SmokeDetector }) as? SmokeDetector
        else { return -1.0 }
        return distance(smokeDetector.position, currentFocus.worldTransform.translation)
    }
    
    func takeScreenshotAndSave() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let view = windowScene.windows.first?.rootViewController?.view else {
            return
        }
        let renderer = UIGraphicsImageRenderer(size: view.bounds.size)
        let screenshotImage = renderer.image { context in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
        UIImageWriteToSavedPhotosAlbum(screenshotImage, self, nil, nil)
    }
}
