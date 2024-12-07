import ARKit
import CoreVideo

actor PointCloud {
    
    func process(frame: ARFrame) async {
        guard let depth = (frame.smoothedSceneDepth ?? frame.sceneDepth),
              let depthBuffer = PixelBuffer<Float32>(pixelBuffer: depth.depthMap),
              let confidenceMap = depth.confidenceMap,
              let confidenceBuffer = PixelBuffer<UInt8>(pixelBuffer: confidenceMap),
              let imageBuffer = YCBCRBuffer(pixelBuffer: frame.capturedImage) else { return }
           
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
                            
                let normalizedCoord = simd_float2(Float(col) / Float(depthBuffer.size.width),
                                                  Float(row) / Float(depthBuffer.size.height))
                            
                let imageSize = imageBuffer.size.asFloat
                            
                let pixelRow = Int(round(normalizedCoord.y * imageSize.y))
                let pixelColumn = Int(round(normalizedCoord.x * imageSize.x))
                            
                let color = imageBuffer.color(x: pixelColumn, y: pixelRow)
            }
        }
    }
}
