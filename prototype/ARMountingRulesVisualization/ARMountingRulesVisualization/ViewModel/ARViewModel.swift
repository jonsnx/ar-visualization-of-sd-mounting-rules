import Foundation
import ARKit
import RealityKit
import Combine


class ARViewModel: NSObject, ARSessionDelegate, ObservableObject {
    private(set) var arSession: ARSession = ARSession()
    private let ruleManager: MountingRuleManager!
    
    @Published private(set) var scene: [Entity & HasAnchoring] = []
    @Published private(set) var errorType: MountingErrorType = .none
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
    
    private var focusEntity: FocusEntity!
    
    private var isProcessing: Bool = false
    private var currentFocus: ARRaycastResult?
    private var recentFocusEntityAlignments: [ARPlaneAnchor.Alignment] = []
    private var isChangingAlignment: Bool = false
    private var isFocusOnCeiling: Bool = false
    
    private var frameCount: Int = 0
    
    override init() {
        ruleManager = MountingRuleManager(
            rules: [
                CeilingRule(),
                WallRule(),
                WindowDoorRule()
            ]
        )
        super.init()
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.sceneReconstruction = .meshWithClassification
        config.frameSemantics = .sceneDepth
        arSession.run(config)
        arSession.delegate = self
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
            focusEntity.putInFrontOfCamera()
            trackingState = .initializing
            currentFocus = nil
            return
        }
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
        scene.removeAll { $0 is SmokeDetector || $0 is DistanceIndicators }
        let currentSurroundings = RaycastUtil.performRaycastsAroundYAxis(in: arSession, from: position, 30)
        let smokeDetector = SmokeDetector(worldPosition: position)
        let distanceIndicators = DistanceIndicators(from: position, around: currentSurroundings)
        scene.append(contentsOf: [smokeDetector, distanceIndicators])
    }
    
    func removeDetector() {
        scene.removeAll { $0 is SmokeDetector || $0 is DistanceIndicators }
    }
}

enum TrackingState: Equatable {
    case initializing
    case tracking(raycastResult: ARRaycastResult)
}


// TODOS:
// [ ] implement snapshot logic
// [ ] implement info modal
// [ ] implement indicator of door and window constraints
// [ ] implement "detector placed"-screen
// [ ] implement partially coloring of ring indicator
// [X] implement like a constraints framework or something
// [ ] implement TA
