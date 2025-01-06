//
//  FocusEntity.swift
//  FocusEntity
//
//  Created by Max Cobb on 8/26/19.
//  Copyright © 2019 Max Cobb. All rights reserved.
//

import RealityKit
#if canImport(ARKit)
import ARKit
#endif
import Combine

extension FocusEntity {
    
    // MARK: Helper Methods
    
    /// Update the position of the focus square.
    internal func updatePosition() {
        // Average using several most recent positions.
        recentFocusEntityPositions = Array(recentFocusEntityPositions.suffix(10))
        
        // Move to average of recent positions to avoid jitter.
        let average = recentFocusEntityPositions.reduce(
            SIMD3<Float>.zero, { $0 + $1 }
        ) / Float(recentFocusEntityPositions.count)
        self.position = average
    }
    
#if canImport(ARKit)
    /// Update the transform of the focus square to be aligned with the camera.
    internal func updateTransform(raycastResult: ARRaycastResult) {
        self.updatePosition()
        
        if state != .initializing {
            updateAlignment(for: raycastResult)
        }
        
        if self.onPlane {
            var position = self.position
            position.y -= 0.2 // Adjust position slightly downward
            let raycastDistanceThreshold: Float = 0.6 // Distance threshold for blocking placement
            let numberOfRays = 9 // Number of rays around 360 degrees
            let angleIncrement = 2 * Float.pi / Float(numberOfRays) // 360 degrees divided by the number of rays
            var closestPlanes: [UUID: RaycastInfo] = [:]
            for i in 0..<numberOfRays {
                let angle = angleIncrement * Float(i)
                
                // Create direction based on angle
                let direction = SIMD3<Float>(cos(angle), 0, sin(angle)) // In XZ plane
                
                // Perform the raycast
                if let raycastResult = self.smartRaycast(position, direction) {
                    let distance = simd_distance(position, raycastResult.worldTransform.translation)
                    
                    // If too close, we can't place the smoke detector
                    if distance < raycastDistanceThreshold {
                        guard let targetPlane = raycastResult.anchor as? ARPlaneAnchor else { continue }
                        
                        if closestPlanes[targetPlane.identifier] == nil {
                            closestPlanes[targetPlane.identifier] = RaycastInfo(distance: distance, target: raycastResult.worldTransform.translation)
                        } else if closestPlanes[targetPlane.identifier]!.distance < distance {
                            print("new closest distance to \(targetPlane.identifier): \(distance)")
                            closestPlanes[targetPlane.identifier] = RaycastInfo(distance: distance, target: raycastResult.worldTransform.translation)
                        }
                    }
                }
            }
            
            closestPlanes.forEach({
                var targetPosition = $1.target
                targetPosition.y += 0.2
                drawLine(from: self.position, to: targetPosition)
            })
        }
    }
    
    func drawLine(from start: SIMD3<Float>, to end: SIMD3<Float>) {
        let midPosition = SIMD3(
            x:(start.x + end.x) / 2,
            y:(start.y + end.y) / 2,
            z:(start.z + end.z) / 2
        )
        
        let anchor = AnchorEntity()
        anchor.position = midPosition
        anchor.look(at: start, from: midPosition, relativeTo: nil)
        
        let meters = simd_distance(start, end)
        
        let lineMaterial = UnlitMaterial.init(color: .red)
        
        let bottomLineMesh = MeshResource.generateBox(width:0.025,
                                                      height: 0,
                                                      depth: meters)
        
        let bottomLineEntity = ModelEntity(mesh: bottomLineMesh,
                                           materials: [lineMaterial])
        
        bottomLineEntity.position = .init(0, 0.025, 0)
        anchor.addChild(bottomLineEntity)
        
        // Add the anchor to the AR scene
        arView?.scene.addAnchor(anchor)
    }
    
    internal func updateAlignment(for raycastResult: ARRaycastResult) {
        
        var targetAlignment = raycastResult.worldTransform.orientation
        
        // Determine current alignment
        var alignment: ARPlaneAnchor.Alignment?
        if let planeAnchor = raycastResult.anchor as? ARPlaneAnchor {
            alignment = planeAnchor.alignment
            // Catching case when looking at ceiling
            if targetAlignment.act([0, 1, 0]).y < -0.9 {
                targetAlignment *= simd_quatf(angle: .pi, axis: [0, 1, 0])
            }
        } else if raycastResult.targetAlignment == .horizontal {
            alignment = .horizontal
        } else if raycastResult.targetAlignment == .vertical {
            alignment = .vertical
        }
        
        // add to list of recent alignments
        if alignment != nil {
            self.recentFocusEntityAlignments.append(alignment!)
        }
        
        // Average using several most recent alignments.
        self.recentFocusEntityAlignments = Array(self.recentFocusEntityAlignments.suffix(20))
        
        let alignCount = self.recentFocusEntityAlignments.count
        let horizontalHistory = recentFocusEntityAlignments.filter({ $0 == .horizontal }).count
        let verticalHistory = recentFocusEntityAlignments.filter({ $0 == .vertical }).count
        
        // Alignment is same as most of the history - change it
        if alignment == .horizontal && horizontalHistory > alignCount * 3/4 ||
            alignment == .vertical && verticalHistory > alignCount / 2 ||
            raycastResult.anchor is ARPlaneAnchor {
            if alignment != self.currentAlignment ||
                (alignment == .vertical && self.shouldContinueAlignAnim(to: targetAlignment)
                ) {
                isChangingAlignment = true
                self.currentAlignment = alignment
            }
        } else {
            // Alignment is different than most of the history - ignore it
            return
        }
        
        // Change the focus entity's alignment
        if isChangingAlignment {
            // Uses interpolation.
            // Needs to be called on every frame that the animation is desired, Not just the first frame.
            performAlignmentAnimation(to: targetAlignment)
        } else {
            orientation = targetAlignment
        }
    }
#endif
    
    internal func normalize(_ angle: Float, forMinimalRotationTo ref: Float) -> Float {
        // Normalize angle in steps of 90 degrees such that the rotation to the other angle is minimal
        var normalized = angle
        while abs(normalized - ref) > .pi / 4 {
            if angle > ref {
                normalized -= .pi / 2
            } else {
                normalized += .pi / 2
            }
        }
        return normalized
    }
    
    internal func getCamVector() -> (position: SIMD3<Float>, direciton: SIMD3<Float>)? {
        guard let camTransform = self.arView?.cameraTransform else {
            return nil
        }
        let camDirection = camTransform.matrix.columns.2
        return (camTransform.translation, -[camDirection.x, camDirection.y, camDirection.z])
    }
    
#if canImport(ARKit)
    /// - Parameters:
    /// - Returns: ARRaycastResult if an existing plane geometry or an estimated plane are found, otherwise nil.
    internal func smartRaycast(_ customPos: SIMD3<Float>? = nil, _ customDir: SIMD3<Float>? = nil) -> ARRaycastResult? {
        // Perform the hit test.
        guard let (camPos, camDir) = self.getCamVector() else {
            return nil
        }
        let origin = customPos ?? camPos
        let direction = customDir ?? camDir
        for target in self.allowedRaycasts {
            let rcQuery = ARRaycastQuery(
                origin: origin, direction: direction,
                allowing: target, alignment: .any
            )
            let results = self.arView?.session.raycast(rcQuery) ?? []
            
            // Check for a result matching target
            if let result = results.first(
                where: { $0.target == target }
            ) { return result }
        }
        return nil
    }
#endif
    
    /// Uses interpolation between orientations to create a smooth `easeOut` orientation adjustment animation.
    internal func performAlignmentAnimation(to newOrientation: simd_quatf) {
        // Interpolate between current and target orientations.
        orientation = simd_slerp(orientation, newOrientation, 0.15)
        // This length creates a normalized vector (of length 1) with all 3 components being equal.
        self.isChangingAlignment = self.shouldContinueAlignAnim(to: newOrientation)
    }
    
    func shouldContinueAlignAnim(to newOrientation: simd_quatf) -> Bool {
        let testVector = simd_float3(repeating: 1 / sqrtf(3))
        let point1 = orientation.act(testVector)
        let point2 = newOrientation.act(testVector)
        let vectorsDot = simd_dot(point1, point2)
        // Stop interpolating when the rotations are close enough to each other.
        return vectorsDot < 0.999
    }
    
#if canImport(ARKit)
    /**
     Reduce visual size change with distance by scaling up when close and down when far away.
     
     These adjustments result in a scale of 1.0x for a distance of 0.7 m or less
     (estimated distance when looking at a table), and a scale of 1.2x
     for a distance 1.5 m distance (estimated distance when looking at the floor).
     */
    internal func scaleBasedOnDistance(camera: ARCamera?) -> Float {
        guard let camera = camera else { return 1.0 }
        
        let distanceFromCamera = simd_length(self.convert(position: .zero, to: nil) - camera.transform.translation)
        if distanceFromCamera < 0.7 {
            return distanceFromCamera / 0.7
        } else {
            return 0.25 * distanceFromCamera + 0.825
        }
    }
#endif
}

struct RaycastInfo {
    let distance: Float
    let target: SIMD3<Float>
}
