import ARKit

enum TrackingState: Equatable {
    case initializing
    case tracking(raycastResult: ARRaycastResult)
}
