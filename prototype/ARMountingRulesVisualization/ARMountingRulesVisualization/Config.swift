import ARKit

struct MinDistances {
    // 1.0f equals 1m in ARKit
    static let minDistanceToWalls: Float = 0.6
    static let minDistanceToWindowOrDoor: Float = 1.5
}

struct RaycastConstants {
    static let raycastOffset: Float = 0
    static let numberOfRaycasts: Int = 9
    static let raycastFrequency: Int = 10
}

class WorldTrackingConfiguration {
    static let instance = WorldTrackingConfiguration()
    let config = ARWorldTrackingConfiguration()
    
    private init() {
        config.planeDetection = [.horizontal, .vertical]
        config.sceneReconstruction = .meshWithClassification
        config.frameSemantics = .sceneDepth
    }
}

class EntityConstants {
    static let smokeDetectorSize: Float = 0.05
    static let angleThreshold: Float = 0.005
}
