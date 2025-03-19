//
//  This code is strongly inspired by Max Cobb's FocusEntity implementation,
//  which can be found at:
//  https://github.com/maxxfrazer/FocusEntity
//
//  The original implementation by Max Cobb is licensed under the MIT License:
//
//  MIT License
//
//  Copyright (c) 2019 Max Fraser Cobb
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import RealityKit
import ARKit

/**
 An `Entity` which is used to provide uses with visual cues about the status of ARKit world tracking.
 */
class FocusEntity: Entity, HasAnchoring {
    /// True if current position is a valid position for the smoke detector
    internal var isPlaceable = false
    /// Current distance to a smoke detector: -1.0 if there is no smoke detector placed
    internal var distanceToDetector: Float = -1.0
    /// Whether FocusEntity is on the ceiling or not.
    private var isOnCeiling: Bool = false
    /// Indicates if the square is currently being animated.
    private var isAnimating = false
    /// Indicates if the square is currently changing its alignment.
    private var isChangingAlignment = false
    /// A camera anchor used for placing the focus entity in front of the camera.
    private var cameraAnchor: AnchorEntity?
    /// The focus square's current alignment.
    private var currentAlignment: ARPlaneAnchor.Alignment?
    /// The focus square's most recent alignments.
    private var recentFocusEntityAlignments: [ARPlaneAnchor.Alignment] = []
    /// The focus square's most recent positions.
    private var recentFocusEntityPositions: [SIMD3<Float>] = []
    /// The primary node that controls the position of other `FocusEntity` nodes.
    private let positioningEntity = Entity()
    /// `ModelEntity` of a smoke detector used as the model of the `FocusEntity`.
    private var detectorEntity: ModelEntity?
    /// `ModelEntity` of a ring used to show the minimum distance to walls.
    private var ringIndicatorEntity: ModelEntity?
    /// Color when `FocusEntity` is on valid position.
    private let onColor: UIColor = .green
    /// Color when `FocusEntity` is  on invalid position.
    private let offColor: UIColor = .red
    /// Callback-function to get the current rotation of the camera.
    private var getCurrentCameraRotation: () -> simd_quatf = {
        return simd_quatf()
    }
    
    /// Create a new ``FocusEntity`` instance.
    /// - Parameters:
    ///   - cameraAnchor: Anchor of the camera in the scene.
    ///   - getCurrentCameraRotation: Callback function to get the current camera rotation.
    required init(cameraAnchor: AnchorEntity, getCurrentCameraRotation: @escaping () -> simd_quatf) {
        super.init()
        self.name = "FocusEntity"
        self.cameraAnchor = cameraAnchor
        self.getCurrentCameraRotation = getCurrentCameraRotation
        self.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        self.addChild(self.positioningEntity)
        if let ringPlane = try? ModelEntity.loadModel(named: "flat_ring") {
            self.positioningEntity.addChild(ringPlane)
            self.ringIndicatorEntity = ringPlane
        }
        self.detectorEntity = ModelEntity(mesh: .generateCylinder(height: 0.05, radius: 0.05))
        self.positioningEntity.addChild(detectorEntity!)
        // Start the focus square as a billboard.
        displayAsBillboard()
        self.stateChanged()
    }
    
    required init() {
        fatalError("init() has not been implemented")
    }
    
    /// Displays the focus square parallel to the camera plane.
    func displayAsBillboard() {
        self.isOnCeiling = false
        self.currentAlignment = .none
        stateChangedSetup()
    }
    
    /// Places the focus entity in front of the camera instead of on a plane.
    func putInFrontOfCamera() {
        self.isOnCeiling = false
        guard let newPosition = cameraAnchor?.convert(position: [0, 0, -1], to: nil) else { fatalError("cameraAnchor is nil!") }
        recentFocusEntityPositions.append(newPosition)
        updatePosition()
        updateScaleOfRingIndicator()
        var newRotation = self.getCurrentCameraRotation()
        newRotation *= simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        performAlignmentAnimation(to: newRotation)
    }
    
    /// Called when a surface has been detected.
    private func displayOffPlane(for raycastResult: ARRaycastResult) {
        self.stateChangedSetup()
        let position = raycastResult.worldTransform.translation
        if self.currentAlignment != .none {
            recentFocusEntityPositions.append(position)
            performAlignmentAnimation(to: raycastResult.worldTransform.orientation)
        } else {
            putInFrontOfCamera()
        }
        updateTransform(raycastResult: raycastResult)
    }
    
    /// Called when a plane has been detected.
    func entityOnPlane(
        for raycastResult: ARRaycastResult, planeAnchor: ARPlaneAnchor
    ) {
        self.isOnCeiling = planeAnchor.classification == .ceiling
        self.stateChangedSetup()
        let position = raycastResult.worldTransform.translation
        if self.currentAlignment != .none {
            recentFocusEntityPositions.append(position)
        } else {
            putInFrontOfCamera()
        }
        updateTransform(raycastResult: raycastResult)
    }
    
    /// Called when no plane has been detected.
    func entityOffPlane(_ raycastResult: ARRaycastResult) {
        displayOffPlane(for: raycastResult)
    }
    
    /// Called whenever the state of the focus entity changes
    private func stateChanged() {
        var endColor: UIColor
        if self.isPlaceable {
            endColor = self.onColor
        } else {
            endColor = self.offColor
        }
        if self.detectorEntity?.model?.materials.count == 0 {
            self.detectorEntity?.model?.materials = [PhysicallyBasedMaterial()]
        }
        if self.ringIndicatorEntity?.model?.materials.count == 0 {
            self.ringIndicatorEntity?.model?.materials = [PhysicallyBasedMaterial()]
        }
        var modelMaterial = PhysicallyBasedMaterial()
        modelMaterial.baseColor = .init(tint: endColor)
        modelMaterial.emissiveColor = .init(color: endColor)
        modelMaterial.emissiveIntensity = 0.5
        let pbOpacity: PhysicallyBasedMaterial.Opacity = .init(floatLiteral: getMaterialOpacity())
        modelMaterial.blending = .transparent(opacity: pbOpacity)
        self.detectorEntity?.model?.materials[0] = modelMaterial
        self.ringIndicatorEntity?.model?.materials[0] = modelMaterial
    }
    
    /// Returns an opacity value based on the distance to a placed smoke detector.
    private func getMaterialOpacity() -> Float {
        var opacity: Float = 1.0
        if self.distanceToDetector != -1.0 && self.distanceToDetector < MinDistances.minDistanceToWalls {
            let normalizedDistance = max(0.0, min(self.distanceToDetector, 1.0))
            opacity = normalizedDistance / MinDistances.minDistanceToWalls
        }
        return opacity
    }
    
    private func stateChangedSetup() {
        guard !isAnimating else { return }
        self.stateChanged()
    }
}

extension FocusEntity {
    
    /// Update the position of the focus entity.
    private func updatePosition() {
        recentFocusEntityPositions = Array(recentFocusEntityPositions.suffix(10))
        let average = recentFocusEntityPositions.reduce(
            SIMD3<Float>.zero, { $0 + $1 }
        ) / Float(recentFocusEntityPositions.count)
        self.position = average
    }
    
    /// Update the scale of the ring indicator.
    private func updateScaleOfRingIndicator() {
        if isOnCeiling && ringIndicatorEntity?.transform.scale != SIMD3<Float>(1.0, 1.0, 1.0) {
            ringIndicatorEntity?.scaleAnimated(with: SIMD3<Float>(1.0, 1.0, 1.0), duration: 0.5)
        } else if !isOnCeiling && ringIndicatorEntity?.transform.scale != SIMD3<Float>(0.12, 0.12, 0.12) {
            ringIndicatorEntity?.scaleAnimated(with: SIMD3<Float>(0.12, 0.12, 0.12), duration: 0.5)
        }
    }
    
    /// Update the transform of the focus square to be aligned with the camera.
    private func updateTransform(raycastResult: ARRaycastResult) {
        self.updatePosition()
        self.updateScaleOfRingIndicator()
        updateAlignment(for: raycastResult)
    }
    
    /// Update the alignment based on the raycast result.
    private func updateAlignment(for raycastResult: ARRaycastResult) {
        var targetAlignment = raycastResult.worldTransform.orientation
        // Determine current alignment
        var alignment: ARPlaneAnchor.Alignment?
        if let planeAnchor = raycastResult.anchor as? ARPlaneAnchor {
            alignment = planeAnchor.alignment
            if planeAnchor.classification == .ceiling {
                targetAlignment *= simd_quatf(angle: .pi, axis: [0, 1, 0])
            }
        } else if raycastResult.targetAlignment == .horizontal {
            alignment = .horizontal
        } else if raycastResult.targetAlignment == .vertical {
            alignment = .vertical
        }
        // Add to list of recent alignments
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
        if isChangingAlignment {
            // Needs to be called on every frame that the animation is desired, Not just the first frame.
            performAlignmentAnimation(to: targetAlignment)
        } else {
            orientation = targetAlignment
        }
    }
    
    /// Uses interpolation between orientations to create a smooth `easeOut` orientation adjustment animation.
    private func performAlignmentAnimation(to newOrientation: simd_quatf) {
        // Interpolate between current and target orientations.
        orientation = simd_slerp(orientation, newOrientation, 0.15)
        // This length creates a normalized vector (of length 1) with all 3 components being equal.
        self.isChangingAlignment = self.shouldContinueAlignAnim(to: newOrientation)
    }
    
    private func shouldContinueAlignAnim(to newOrientation: simd_quatf) -> Bool {
        let testVector = simd_float3(repeating: 1 / sqrtf(3))
        let point1 = orientation.act(testVector)
        let point2 = newOrientation.act(testVector)
        let vectorsDot = simd_dot(point1, point2)
        return vectorsDot < 0.999
    }
}
