struct MountingRules {
    // 1 Float equals 1 Meter in ARKit
    static let minDistanceToWalls: Float = 0.6
    static let minDistanceToObjects: Float = 0.6
    static let minDistanceToWindows: Float = 1
}

struct RaycastConstants {
    static let raycastOffset: Float = 0.5
}
