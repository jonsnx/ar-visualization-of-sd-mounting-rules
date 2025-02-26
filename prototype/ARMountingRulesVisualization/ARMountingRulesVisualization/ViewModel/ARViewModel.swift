import Foundation
import ARKit
import RealityKit
import Combine


class ARViewModel: NSObject, ARSessionDelegate, ObservableObject {
    private(set) var arSession: ARSession = ARSession()
    
    @Published private(set) var scene: [Entity & HasAnchoring] = []
    @Published private(set) var mountingState: MountingState = .notOnCeiling
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
    private var smokeDetector: SmokeDetector?
    private var distanceIndicators: DistanceIndicators?
    
    private var isProcessing: Bool = false
    private var currentFocus: ARRaycastResult?
    private var recentFocusEntityAlignments: [ARPlaneAnchor.Alignment] = []
    private var isChangingAlignment: Bool = false
    private var isFocusOnCeiling: Bool = false
    
    private var frameCount: Int = 0
    
    override init() {
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
                await checkIsPlaceable()
            }
            isProcessing = false
        }
        frameCount += 1
    }
    
    private func checkIsPlaceable() async {
        guard let currentFocus = currentFocus,
              await focusEntity.isOnCeiling
        else {
            await setMountingState(.notOnCeiling)
            await setIsPlaceable(false)
            return
        }
        let currentSurroundings = RaycastUtil.performRaycastsAroundYAxis(
            in: arSession,
            from: currentFocus.worldTransform.translation
        )
        for data in currentSurroundings {
            let targetPosition = data.result.worldTransform.translation
            let distance: Float = simd_distance(currentFocus.worldTransform.translation, targetPosition)
            if distance <= 0.6 {
                await setMountingState(.constraintsNeglected)
                await setIsPlaceable(false)
                return
            }
            if await checkIsTooCloseToWindowOrDoor() {
                await setMountingState(.constraintsNeglected)
                await setIsPlaceable(false)
                return
            }
        }
        await setMountingState(.constraintsSatisfied)
        await setIsPlaceable(true)
    }
    
    private func checkIsTooCloseToWindowOrDoor() async -> Bool {
        guard let anchors = arSession.currentFrame?.anchors,
              let position = currentFocus?.worldTransform.translation
        else { return false }
        var meshAnchors = anchors.compactMap({ $0 as? ARMeshAnchor })
        let cutoffDistance: Float = 1.5
        meshAnchors.removeAll { distance($0.transform.translation, position) > cutoffDistance }
        for anchor in meshAnchors {
            for index in 0..<anchor.geometry.faces.count {
                let classification: ARMeshClassification = anchor.geometry.classificationOf(faceWithIndex: index)
                if classification == .window || classification == .door {
                    let geometricCenterOfFace = anchor.geometry.centerOf(faceWithIndex: index)
                    var centerLocalTransform = matrix_identity_float4x4
                    centerLocalTransform.columns.3 = SIMD4<Float>(geometricCenterOfFace.0, geometricCenterOfFace.1, geometricCenterOfFace.2, 1)
                    let centerWorldPosition = (anchor.transform * centerLocalTransform).translation
                    let distanceToFace = distance(centerWorldPosition, position)
                    if distanceToFace <= 1.5 {
                        return true
                    }
                }
            }
        }
        return false
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
    private func setMountingState(_ value: MountingState) {
        self.mountingState = value
    }
    
    func placeDetector() {
        guard let position = currentFocus?.worldTransform.translation,
              focusEntity.isPlaceable
        else { return }
        scene.removeAll { $0 is SmokeDetector || $0 is DistanceIndicators }
        let currentSurroundings = RaycastUtil.performRaycastsAroundYAxis(in: arSession, from: position, 30)
        smokeDetector = SmokeDetector(worldPosition: position)
        distanceIndicators = DistanceIndicators(from: position, around: currentSurroundings)
        scene.append(contentsOf: [smokeDetector!, distanceIndicators!])
    }
    
    func removeDetector() {
        scene.removeAll { $0 is SmokeDetector || $0 is DistanceIndicators }
    }
}

enum MountingState: Equatable {
    case constraintsSatisfied
    case constraintsNeglected
    case notOnCeiling
    
    var message: String {
        switch self {
        case .constraintsSatisfied:
            return ""
        case .constraintsNeglected:
            return "Rauchmelder kann hier nicht platziert werden!"
        case .notOnCeiling:
            return "Richten Sie die Kamera auf die Decke!"
        }
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
// [ ] implement like a constraints framework or something
// [ ] implement TA
