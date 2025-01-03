import ARKit
import RealityKit

extension ARPlaneAnchor {
    func intersects(_ other: ARPlaneAnchor) -> Bool {
        // Extract boundary vertices for both planes
        let selfVertices = self.geometry.boundaryVertices
        let otherVertices = other.geometry.boundaryVertices
        
        // Check if any of the vertices of one plane are inside the other plane's boundary
        for vertex in selfVertices {
            if isPointInsideBoundary(vertex, of: other) {
                return true
            }
        }
        
        for vertex in otherVertices {
            if isPointInsideBoundary(vertex, of: self) {
                return true
            }
        }
        
        return false
    }
    
    // Helper function to check if a point is inside a polygon (plane's boundary)
    private func isPointInsideBoundary(_ point: simd_float3, of otherAnchor: ARPlaneAnchor) -> Bool {
        let boundary = otherAnchor.geometry.boundaryVertices
        
        // Use the ray-casting algorithm to check if a point is inside the polygon
        var inside = false
        var j = boundary.count - 1
        
        for i in 0..<boundary.count {
            let vi = boundary[i]
            let vj = boundary[j]
            
            // Check if the point intersects with the edge of the polygon
            if ((vi.z > point.z) != (vj.z > point.z)) &&
                (point.x < (vj.x - vi.x) * (point.z - vi.z) / (vj.z - vi.z) + vi.x) {
                inside.toggle()
            }
            
            j = i
        }
        
        return inside
    }
    
    // Comparison operator "<" (less than)
    static func < (lhs: ARPlaneAnchor, rhs: ARPlaneAnchor) -> Bool {
        let lhsArea = lhs.planeExtent.width * lhs.planeExtent.height
        let rhsArea = rhs.planeExtent.width * rhs.planeExtent.height
        return lhsArea < rhsArea
    }
    
    // Comparison operator ">" (greater than)
    static func > (lhs: ARPlaneAnchor, rhs: ARPlaneAnchor) -> Bool {
        let lhsArea = lhs.planeExtent.width * lhs.planeExtent.height
        let rhsArea = rhs.planeExtent.width * rhs.planeExtent.height
        return lhsArea > rhsArea
    }
    
    // Comparison operator "<=" (less than or equal)
    static func <= (lhs: ARPlaneAnchor, rhs: ARPlaneAnchor) -> Bool {
        let lhsArea = lhs.planeExtent.width * lhs.planeExtent.height
        let rhsArea = rhs.planeExtent.width * rhs.planeExtent.height
        return lhsArea <= rhsArea
    }
    
    // Comparison operator ">=" (greater than or equal)
    static func >= (lhs: ARPlaneAnchor, rhs: ARPlaneAnchor) -> Bool {
        let lhsArea = lhs.planeExtent.width * lhs.planeExtent.height
        let rhsArea = rhs.planeExtent.width * rhs.planeExtent.height
        return lhsArea >= rhsArea
    }
}
