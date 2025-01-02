import ARKit
import RealityKit

class RuleApplicator {
    static func applyRules(_ data: [float4x4]) -> [EntityType: float4x4] {
        var processedMatrices: [EntityType: float4x4] = [:]
        let scaleMatrix = float4x4(
            SIMD4<Float>(0.5, 0.0, 0.0, 0.0),
            SIMD4<Float>(0.0, 0.5, 0.0, 0.0),
            SIMD4<Float>(0.0, 0.0, 0.5, 0.0),
            SIMD4<Float>(0.0, 0.0, 0.0, 1.0)
        )
        
        for matrix in data {
            processedMatrices[.plane] = matrix_multiply(matrix, scaleMatrix)
        }
        return processedMatrices
    }
}

enum EntityType {
    case plane
    case detector
}
