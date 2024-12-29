import ARKit
import CoreVideo

actor PointCloud {
    
    struct GridKey: Hashable {
        
        static let density: Float = 100
        
        private let id: Int
        
        init(_ position: SCNVector3) {
            var hasher = Hasher()
            for component in [position.x, position.y, position.z] {
                hasher.combine(Int(round(component * Self.density)))
            }
            id = hasher.finalize()
        }
    }
    
    struct Vertex {
        let position: SCNVector3
        let color: simd_float4
    }
    
    private(set) var vertices: [GridKey: Vertex] = [:]
    
    
    func process(frame: ARFrame) async {
        
        let rotateToARCamera = makeRotateToARCameraMatrix(orientation: .portrait)
        let cameraTransform = frame.camera.viewMatrix(for: .portrait).inverse * rotateToARCamera
        
        // iterate through pixels in depth buffer
        for row in 0..<depthBuffer.size.height {
            for col in 0..<depthBuffer.size.width {
                // get confidence value
                let confidenceRawValue = Int(confidenceBuffer.value(x: col, y: row))
                guard let confidence = ARConfidenceLevel(rawValue: confidenceRawValue) else {
                    continue
                }
                
                // filter by confidence
                if confidence != .high { continue }
                
                // get distance value from
                let depth = depthBuffer.value(x: col, y: row)
                
                // filter points by distance
                if depth > 2 { return }
                
                let normalizedCoord = simd_float2(Float(col) / Float(depthBuffer.size.width), Float(row) / Float(depthBuffer.size.height))
                
                let imageSize = imageBuffer.size.asFloat
                let screenPoint = simd_float3(normalizedCoord * imageSize, 1)
                
                // Transform the 2D screen point into local 3D camera space
                let localPoint = simd_inverse(frame.camera.intrinsics) * screenPoint * depth
                
                // Converts the local camera space 3D point into world space.
                let worldPoint = cameraTransform * simd_float4(localPoint, 1)
                
                // Normalizes the result.
                let resulPosition = (worldPoint / worldPoint.w)
                
                let pointPosition = SCNVector3(x: resulPosition.x, y: resulPosition.y, z: resulPosition.z)
                
                let key = PointCloud.GridKey(pointPosition)
                
                if vertices[key] == nil {
                    let pixelRow = Int(round(normalizedCoord.y * imageSize.y))
                    let pixelColumn = Int(round(normalizedCoord.x * imageSize.x))
                    let color = imageBuffer.color(x: pixelColumn, y: pixelRow)
                    
                    
                    vertices[key] = PointCloud.Vertex(position: pointPosition, color: color)
                }
            }
        }
    }
    
    func makeRotateToARCameraMatrix(orientation: UIInterfaceOrientation) -> matrix_float4x4 {
        // Flip Y and Z axes to align with ARKit's camera coordinate system
        let flipYZ = matrix_float4x4(
            [1, 0, 0, 0],
            [0, -1, 0, 0],
            [0, 0, -1, 0],
            [0, 0, 0, 1]
        )
        // Get rotation angle in radians based on the display orientation
        let rotationAngle: Float = switch orientation {
        case .landscapeLeft: .pi
        case .portrait: .pi / 2
        case .portraitUpsideDown: -.pi / 2
        default: 0
        }
        // Create a rotation matrix around the Z-axis
        let quaternion = simd_quaternion(rotationAngle, simd_float3(0, 0, 1))
        let rotationMatrix = matrix_float4x4(quaternion)
        // Combine flip and rotation matrices
        return flipYZ * rotationMatrix
    }
}
