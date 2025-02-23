import ARKit
import RealityKit

class RaycastUtil {
    static private let allowedRaycasts: [ARRaycastQuery.Target] = [.existingPlaneGeometry, .estimatedPlane]
    
    static func smartRaycast(in session: ARSession, from position: SIMD3<Float>, to direction: SIMD3<Float>) -> ARRaycastResult? {
        for target in self.allowedRaycasts {
            let rcQuery = ARRaycastQuery(
                origin: position, direction: direction,
                allowing: target, alignment: .any
            )
            let results = session.raycast(rcQuery)
            
            // Check for a result matching target
            if let result = results.first(
                where: { $0.target == target }
            ) { return result }
        }
        return nil
    }
    
    static func performRaycastsAroundYAxis(in session: ARSession, from position: SIMD3<Float>) -> [RaycastData] {
        var results: [RaycastData] = []
        let numberOfRays = RaycastConstants.numberOfRaycasts
        let angleIncrement: Float = 2 * Float.pi / Float(numberOfRays)
        var origin = position
        origin.y -= RaycastConstants.raycastOffset
        for i in 0..<numberOfRays {
            let angle = angleIncrement * Float(i)
            let direction = SIMD3<Float>(cos(angle), 0, sin(angle))
            guard let raycastResult = self.smartRaycast(in: session, from: origin, to: direction) else { continue }
            if raycastResult.anchor as? ARPlaneAnchor == nil { continue }
            results.append(RaycastData(origin: origin, direction: direction, result: raycastResult))
        }
        return results
    }
}

class CameraUtils {
    static func getCamVector(camTransform: simd_float4x4) -> (position: SIMD3<Float>, direciton: SIMD3<Float>)? {
        let camDirection = camTransform.columns.2
        return (camTransform.translation, -[camDirection.x, camDirection.y, camDirection.z])
    }
}

struct RaycastData {
    let origin: SIMD3<Float>
    let direction: SIMD3<Float>
    let result: ARRaycastResult
}
