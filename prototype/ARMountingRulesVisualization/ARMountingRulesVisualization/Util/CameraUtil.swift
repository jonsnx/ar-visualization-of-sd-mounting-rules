import ARKit

class CameraUtils {
    static func getCamVector(camTransform: simd_float4x4) -> (position: SIMD3<Float>, direciton: SIMD3<Float>)? {
        let camDirection = camTransform.columns.2
        return (camTransform.translation, -[camDirection.x, camDirection.y, camDirection.z])
    }
}
