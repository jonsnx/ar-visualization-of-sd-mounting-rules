import Foundation
import ARKit
import RealityKit
import Combine


class ARViewModel: NSObject, ARSessionDelegate, ObservableObject {
    private(set) var arSession: ARSession = ARSession()
    
    @Published private(set) var scene: [Entity & HasAnchoring] = []
    private var focusEntity: FocusEntity!
    private var detector: SmokeDetector?
    private var distanceIndicators: DistanceIndicators?
    private var updateCancellable: (any Cancellable)?
    
    private var isProcessing: Bool = false
    private var currentFocus: SIMD3<Float>?
    
    private var frameCount = 0
    
    override init() {
        super.init()
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.sceneReconstruction = .meshWithClassification
        config.frameSemantics = .sceneDepth
        arSession.run(config)
        arSession.delegate = self
        let focusEntityComponent: FocusEntityComponent = .init(
            onColor: .green,
            offColor: .red,
            mesh: .generateCylinder(height: 0.05, radius: 0.05)
        )
        let cameraAnchor = AnchorEntity(.camera)
        focusEntity = FocusEntity(focus: focusEntityComponent, cameraAnchor: cameraAnchor, getCurrentCameraRotation: {
            guard let currentFrame = self.arSession.currentFrame else { return simd_quatf() }
            return currentFrame.camera.transform.orientation
        })
        scene.append(contentsOf: [cameraAnchor, focusEntity])
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        processFrame()
    }
    
    func processFrame(event: SceneEvents.Update? = nil) {
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
    
    func checkIsPlaceable() async {
        guard let position = currentFocus,
              await focusEntity.isOnCeiling
        else {
            await setIsPlaceable(false)
            return
        }
        print("checking isPlaceable")
        let currentSurroundings = RaycastUtil.performRaycastsAroundYAxis(
            in: arSession,
            from: position
        )
        for data in currentSurroundings {
            let targetPosition = data.result.worldTransform.translation
            let distance: Float = simd_distance(position, targetPosition)
            print("distance: \(distance) from position: \(position) to: \(targetPosition)")
            if distance <= 0.6 {
                print("too close to wall")
                await setIsPlaceable(false)
                return
            }
            if await checkIsTooCloseToWindowOrDoor() {
                await setIsPlaceable(false)
                return
            }
        }
        await setIsPlaceable(true)
    }
    
    func checkIsTooCloseToWindowOrDoor() async -> Bool {
        guard let anchors = arSession.currentFrame?.anchors,
              let position = currentFocus else { return false }
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
                        print("too close to window or door")
                        return true
                    }
                }
            }
        }
        return false
    }
    
    public func updateFocusEntity() {
        guard let camera = arSession.currentFrame?.camera,
              case .normal = camera.trackingState,
              let (camPos, camDir) = CameraUtils.getCamVector(camTransform: camera.transform),
              let result = RaycastUtil.smartRaycast(in: arSession, from: camPos, to: camDir)
        else {
            focusEntity.putInFrontOfCamera()
            focusEntity.state = .initializing
            currentFocus = nil
            return
        }
        currentFocus = result.worldTransform.translation
        focusEntity.state = .tracking(raycastResult: result, camera: camera)
    }
    
    @MainActor
    func setIsPlaceable(_ value: Bool) {
        self.focusEntity.isPlaceable = value
    }
}
