import ARKit

//struct for storing CVPixelBuffer resolution
struct Size {
    let width: Int
    let height: Int
    
    var asFloat: simd_float2 {
        simd_float2(Float(width), Float(height))
    }
}

final class PixelBuffer<T> {
    
    let size: Size
    let bytesPerRow: Int

    private let pixelBuffer: CVPixelBuffer
    private let baseAddress: UnsafeMutableRawPointer
    
    init?(pixelBuffer: CVPixelBuffer) {
        self.pixelBuffer = pixelBuffer

        // lock the buffer while we are getting its values
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        
        guard let baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            return nil
        }
        self.baseAddress = baseAddress
        
        size = Size(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        bytesPerRow =  CVPixelBufferGetBytesPerRow(pixelBuffer)
    }
    
    // obtain value from pixel buffer in specified coordinates
    func value(x: Int, y: Int) -> T {

        // move to the specified address and get the value bounded to our type
        let rowPtr = baseAddress.advanced(by: y * bytesPerRow)
        return rowPtr.assumingMemoryBound(to: T.self)[x]
    }
    
    deinit {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
    }
}

final class YCBCRBuffer {
    
    let size: Size
    
    private let pixelBuffer: CVPixelBuffer
    private let yPlane: UnsafeMutableRawPointer
    private let cbCrPlane: UnsafeMutableRawPointer
    private let ySize: Size
    private let cbCrSize: Size
    
    init?(pixelBuffer: CVPixelBuffer) {
        self.pixelBuffer = pixelBuffer
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        
        guard let yPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0),
                let cbCrPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1) else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            return nil
        }
        
        self.yPlane = yPlane
        self.cbCrPlane = cbCrPlane
 
        size = Size(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        
        ySize = Size(width: CVPixelBufferGetWidthOfPlane(pixelBuffer, 0), height: CVPixelBufferGetHeightOfPlane(pixelBuffer, 0))
        
        cbCrSize = Size(width: CVPixelBufferGetWidthOfPlane(pixelBuffer, 1), height: CVPixelBufferGetHeightOfPlane(pixelBuffer, 1))
    }
    
    func color(x: Int, y: Int) -> simd_float4 {
        let yIndex = y * CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0) + x
        let uvIndex = y / 2 * CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1) + x / 2 * 2
        
        // Extract the Y, Cb, and Cr values
        let yValue = yPlane.advanced(by: yIndex).assumingMemoryBound(to: UInt8.self).pointee

        let cbValue = cbCrPlane.advanced(by: uvIndex).assumingMemoryBound(to: UInt8.self).pointee

        let crValue = cbCrPlane.advanced(by: uvIndex + 1).assumingMemoryBound(to: UInt8.self).pointee
        
        // Convert YCbCr to RGB
        let y = Float(yValue) - 16
        let cb = Float(cbValue) - 128
        let cr = Float(crValue) - 128
        
        let r = 1.164 * y + 1.596 * cr
        let g = 1.164 * y - 0.392 * cb - 0.813 * cr
        let b = 1.164 * y + 2.017 * cb
        
        // normalize rgb components
        return simd_float4(
            max(0, min(255, r)) / 255.0,
            max(0, min(255, g)) / 255.0,
            max(0, min(255, b)) / 255.0, 1.0)
    }
    
    deinit {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
    }
}
