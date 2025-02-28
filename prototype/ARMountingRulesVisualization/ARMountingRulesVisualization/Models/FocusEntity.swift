//
//  FocusEntity.swift
//  FocusEntity
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

class FocusEntity: Entity, HasAnchoring {
    internal var isPlaceable = false
    internal var distanceToDetector: Float = -1.0
    private var isOnCeiling: Bool = false
    private var isAnimating = false
    private var isChangingAlignment = false
    private var cameraAnchor: AnchorEntity?
    private var currentAlignment: ARPlaneAnchor.Alignment?
    private var recentFocusEntityAlignments: [ARPlaneAnchor.Alignment] = []
    private var recentFocusEntityPositions: [SIMD3<Float>] = []
    private let positioningEntity = Entity()
    private var detectorEntity: ModelEntity?
    private var ringIndicatorEntity: ModelEntity?
    private let onColor: UIColor = .green
    private let offColor: UIColor = .red
    private var getCurrentCameraRotation: () -> simd_quatf = {
        return simd_quatf()
    }
    
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
        displayAsBillboard()
        self.stateChanged()
    }
    
    required init() {
        fatalError("init() has not been implemented")
    }
    
    func entityOffPlane(_ raycastResult: ARRaycastResult) {
        displayOffPlane(for: raycastResult)
    }
    
    func displayAsBillboard() {
        self.isOnCeiling = false
        self.currentAlignment = .none
        stateChangedSetup()
    }
    
    func putInFrontOfCamera() {
        self.isOnCeiling = false
        guard let newPosition = cameraAnchor?.convert(position: [0, 0, -1], to: nil) else { fatalError("cameraAnchor is nil!") }
        recentFocusEntityPositions.append(newPosition)
        updatePosition()
        var newRotation = self.getCurrentCameraRotation()
        newRotation *= simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        performAlignmentAnimation(to: newRotation)
    }
    
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
    
    private func getMaterialOpacity() -> Float {
        var opacity: Float = 1.0
        if self.distanceToDetector != -1.0 && self.distanceToDetector < 0.5 {
            let normalizedDistance = max(0.0, min(self.distanceToDetector, 1.0))
            let t = normalizedDistance / 0.5
            opacity = (t * t * (3 - 2 * t))
        }
        return opacity
    }
    
    private func stateChangedSetup() {
        guard !isAnimating else { return }
        self.stateChanged()
    }
}

extension FocusEntity {
    private func updatePosition() {
        recentFocusEntityPositions = Array(recentFocusEntityPositions.suffix(10))
        let average = recentFocusEntityPositions.reduce(
            SIMD3<Float>.zero, { $0 + $1 }
        ) / Float(recentFocusEntityPositions.count)
        self.position = average
        if self.isOnCeiling && self.ringIndicatorEntity?.transform.scale != SIMD3<Float>(1.0, 1.0, 1.0) {
            self.ringIndicatorEntity?.scaleAnimated(with: SIMD3<Float>(1.0, 1.0, 1.0), duration: 0.5)
        } else if !self.isOnCeiling && self.ringIndicatorEntity?.transform.scale != SIMD3<Float>(0.12, 0.12, 0.12) {
            self.ringIndicatorEntity?.scaleAnimated(with: SIMD3<Float>(0.12, 0.12, 0.12), duration: 0.5)
        }
    }
    
    private func updateTransform(raycastResult: ARRaycastResult) {
        self.updatePosition()
        updateAlignment(for: raycastResult)
    }
    
    private func updateAlignment(for raycastResult: ARRaycastResult) {
        var targetAlignment = raycastResult.worldTransform.orientation
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
        if alignment != nil {
            self.recentFocusEntityAlignments.append(alignment!)
        }
        self.recentFocusEntityAlignments = Array(self.recentFocusEntityAlignments.suffix(20))
        let alignCount = self.recentFocusEntityAlignments.count
        let horizontalHistory = recentFocusEntityAlignments.filter({ $0 == .horizontal }).count
        let verticalHistory = recentFocusEntityAlignments.filter({ $0 == .vertical }).count
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
            return
        }
        if isChangingAlignment {
            performAlignmentAnimation(to: targetAlignment)
        } else {
            orientation = targetAlignment
        }
    }
    
    private func performAlignmentAnimation(to newOrientation: simd_quatf) {
        orientation = simd_slerp(orientation, newOrientation, 0.15)
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
