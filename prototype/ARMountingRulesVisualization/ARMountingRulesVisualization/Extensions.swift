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

extension ModelEntity {
    func scaleAnimated(with value: SIMD3<Float>, duration: CGFloat) {
        var scaleTransform = Transform()
        scaleTransform.rotation = self.orientation
        scaleTransform.scale = value
        self.move(to: scaleTransform, relativeTo: self.parent, duration: duration)
        
    }
    
}

extension ARMeshGeometry {
    func vertex(at index: UInt32) -> (Float, Float, Float) {
        assert(vertices.format == MTLVertexFormat.float3, "Expected three floats (twelve bytes) per vertex.")
        let vertexPointer = vertices.buffer.contents().advanced(by: vertices.offset + (vertices.stride * Int(index)))
        let vertex = vertexPointer.assumingMemoryBound(to: (Float, Float, Float).self).pointee
        return vertex
    }
    
    func classificationOf(faceWithIndex index: Int) -> ARMeshClassification {
        guard let classification = classification else { return .none }
        assert(classification.format == MTLVertexFormat.uchar, "Expected one unsigned char (one byte) per classification")
        let classificationPointer = classification.buffer.contents().advanced(by: classification.offset + (classification.stride * index))
        let classificationValue = Int(classificationPointer.assumingMemoryBound(to: CUnsignedChar.self).pointee)
        return ARMeshClassification(rawValue: classificationValue) ?? .none
    }
    
    func vertexIndicesOf(faceWithIndex faceIndex: Int) -> [UInt32] {
        assert(faces.bytesPerIndex == MemoryLayout<UInt32>.size, "Expected one UInt32 (four bytes) per vertex index")
        let vertexCountPerFace = faces.indexCountPerPrimitive
        let vertexIndicesPointer = faces.buffer.contents()
        var vertexIndices = [UInt32]()
        vertexIndices.reserveCapacity(vertexCountPerFace)
        for vertexOffset in 0..<vertexCountPerFace {
            let vertexIndexPointer = vertexIndicesPointer.advanced(by: (faceIndex * vertexCountPerFace + vertexOffset) * MemoryLayout<UInt32>.size)
            vertexIndices.append(vertexIndexPointer.assumingMemoryBound(to: UInt32.self).pointee)
        }
        return vertexIndices
    }
    
    func verticesOf(faceWithIndex index: Int) -> [(Float, Float, Float)] {
        let vertexIndices = vertexIndicesOf(faceWithIndex: index)
        let vertices = vertexIndices.map { vertex(at: $0) }
        return vertices
    }
    
    func centerOf(faceWithIndex index: Int) -> (Float, Float, Float) {
        let vertices = verticesOf(faceWithIndex: index)
        let sum = vertices.reduce((0, 0, 0)) { ($0.0 + $1.0, $0.1 + $1.1, $0.2 + $1.2) }
        let geometricCenter = (sum.0 / 3, sum.1 / 3, sum.2 / 3)
        return geometricCenter
    }
}
