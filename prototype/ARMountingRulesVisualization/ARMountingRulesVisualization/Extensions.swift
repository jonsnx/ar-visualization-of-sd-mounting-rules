import ARKit

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
            
            if ((vi.z > point.z) != (vj.z > point.z)) &&
                (point.x < (vj.x - vi.x) * (point.z - vi.z) / (vj.z - vi.z) + vi.x) {
                inside.toggle()
            }
            
            j = i
        }
        
        return inside
    }
    
    static func < (lhs: ARPlaneAnchor, rhs: ARPlaneAnchor) -> Bool {
        let lhsArea = lhs.planeExtent.width * lhs.planeExtent.height
        let rhsArea = rhs.planeExtent.width * rhs.planeExtent.height
        return lhsArea < rhsArea
    }
    
    static func > (lhs: ARPlaneAnchor, rhs: ARPlaneAnchor) -> Bool {
        let lhsArea = lhs.planeExtent.width * lhs.planeExtent.height
        let rhsArea = rhs.planeExtent.width * rhs.planeExtent.height
        return lhsArea > rhsArea
    }
    
    static func <= (lhs: ARPlaneAnchor, rhs: ARPlaneAnchor) -> Bool {
        let lhsArea = lhs.planeExtent.width * lhs.planeExtent.height
        let rhsArea = rhs.planeExtent.width * rhs.planeExtent.height
        return lhsArea <= rhsArea
    }
    
    static func >= (lhs: ARPlaneAnchor, rhs: ARPlaneAnchor) -> Bool {
        let lhsArea = lhs.planeExtent.width * lhs.planeExtent.height
        let rhsArea = rhs.planeExtent.width * rhs.planeExtent.height
        return lhsArea >= rhsArea
    }
    
    func calculateNormalVetor() -> simd_float3 {
        let transform = self.transform
        let localNormal = SIMD3<Float>(0, 1, 0)
        let worldNormal = simd_mul(transform, SIMD4<Float>(localNormal.x, localNormal.y, localNormal.z, 0))
        return SIMD3<Float>(worldNormal.x, worldNormal.y, worldNormal.z)
    }
}


//
//  float4x4+Extension.swift
//  FocusEntity
//
//  Created by Max Cobb on 8/26/19.
//  Copyright © 2019 Max Cobb. All rights reserved.
//

import simd

internal extension float4x4 {
    /**
     Treats matrix as a (right-hand column-major convention) transform matrix
     and factors out the translation component of the transform.
     */
    var translation: SIMD3<Float> {
        get {
            let translation = columns.3
            return SIMD3<Float>(translation.x, translation.y, translation.z)
        }
        set(newValue) {
            columns.3 = SIMD4<Float>(newValue.x, newValue.y, newValue.z, columns.3.w)
        }
    }

    /**
     Factors out the orientation component of the transform.
     */
    var orientation: simd_quatf {
        return simd_quaternion(self)
    }
}
