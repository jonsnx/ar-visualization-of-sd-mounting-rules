import SwiftUI
import Foundation

struct PLYFile: Transferable {
    
    let pointCloud: PointCloud
    
    enum Error: LocalizedError {
        case cannotExport
    }
    
    func export() async throws -> Data {
        let vertices = await pointCloud.vertices
        
        var plyContent = """
        ply
        format ascii 1.0
        element vertex \(vertices.count)
        property float x
        property float y
        property float z
        property uchar red
        property uchar green
        property uchar blue
        property uchar alpha
        end_header
        """
        
        for vertex in vertices.values {
            // Convert position and color
            let x = vertex.position.x
            let y = vertex.position.y
            let z = vertex.position.z
            let r = UInt8(vertex.color.x * 255)
            let g = UInt8(vertex.color.y * 255)
            let b = UInt8(vertex.color.z * 255)
            let a = UInt8(vertex.color.w * 255)
            
            // Append the vertex data
            plyContent += "\n\(x) \(y) \(z) \(r) \(g) \(b) \(a)"
        }
        
        guard let data = plyContent.data(using: .ascii) else {
            throw Error.cannotExport
        }
        return data
    }
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .data) {
            try await $0.export()
        }.suggestedFileName("exported.ply")
    }
}
