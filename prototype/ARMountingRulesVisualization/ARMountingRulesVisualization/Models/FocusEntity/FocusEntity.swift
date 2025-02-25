//
//  FocusEntity.swift
//  FocusEntity
//
//  Created by Max Cobb on 8/26/19.
//  Copyright © 2019 Max Cobb. All rights reserved.
//

import Foundation
import RealityKit
import RealityFoundation
import ARKit
import Combine

public protocol HasFocusEntity: Entity {}

public extension HasFocusEntity {
    var focus: FocusEntityComponent {
        get { self.components[FocusEntityComponent.self] ?? .classic }
        set { self.components[FocusEntityComponent.self] = newValue }
    }
    var isOpen: Bool {
        get { self.focus.isOpen }
        set { self.focus.isOpen = newValue }
    }
    internal var segments: [FocusEntity.Segment] {
        get { self.focus.segments }
        set { self.focus.segments = newValue }
    }
    var allowedRaycasts: [ARRaycastQuery.Target] {
        get { self.focus.allowedRaycasts }
        set { self.focus.allowedRaycasts = newValue }
    }
}

/**
 An `Entity` which is used to provide uses with visual cues about the status of ARKit world tracking.
 */
open class FocusEntity: Entity, HasAnchoring, HasFocusEntity {
    
    /// For moving the FocusEntity to a whole new ARView
    /// - Parameter view: The destination `ARView`
    
    /// Destroy this FocusEntity and its references to any ARViews
    /// Without calling this, your ARView could stay in memory.
    public func destroy() {
        for child in children {
            child.removeFromParent()
        }
        self.removeFromParent()
    }
    
    func entityOffPlane(_ raycastResult: ARRaycastResult) {
        displayOffPlane(for: raycastResult)
    }
    
    /**
     Reduce visual size change with distance by scaling up when close and down when far away.
     
     These adjustments result in a scale of 1.0x for a distance of 0.7 m or less
     (estimated distance when looking at a table), and a scale of 1.2x
     for a distance 1.5 m distance (estimated distance when looking at the floor).
     */
    private func scaleBasedOnDistance(cameraTransform: Transform) -> Float {
        let distanceFromCamera = simd_length(self.position(relativeTo: nil) - cameraTransform.translation)
        if distanceFromCamera < 0.7 {
            return distanceFromCamera / 0.7
        } else {
            return 0.25 * distanceFromCamera + 0.825
        }
    }
    
    /// Whether FocusEntity is on a plane or not.
    public internal(set) var isOnCeiling: Bool = false
    /// Indicates if the square is currently being animated.
    public internal(set) var isAnimating = false
    /// Indicates if the square is currently changing its alignment.
    public internal(set) var isChangingAlignment = false
    
    public var isPlaceable = false
    
    /// A camera anchor used for placing the focus entity in front of the camera.
    internal var cameraAnchor: AnchorEntity?
    
    /// The focus square's current alignment.
    internal var currentAlignment: ARPlaneAnchor.Alignment?
    
    /// The focus square's most recent alignments.
    internal var recentFocusEntityAlignments: [ARPlaneAnchor.Alignment] = []
    /// Previously visited plane anchors.
    internal var anchorsOfVisitedPlanes: Set<ARAnchor> = []
    /// The focus square's most recent positions.
    internal var recentFocusEntityPositions: [SIMD3<Float>] = []
    /// The primary node that controls the position of other `FocusEntity` nodes.
    internal let positioningEntity = Entity()
    internal var detectorEntity: ModelEntity?
    internal var ringIndicatorEntity: ModelEntity?
    internal var quarterRingEntity: ModelEntity?
    
    internal var getCurrentCameraRotation: () -> simd_quatf = {
        return simd_quatf()
    }
    
    // MARK: - Initialization
    
    /// Create a new ``FocusEntity`` instance using the full ``FocusEntityComponent`` object.
    /// - Parameters:
    ///   - arView: ARView containing the scene where the FocusEntity should be added.
    ///   - focus: Main component for the ``FocusEntity``
    public required init(focus: FocusEntityComponent, cameraAnchor: AnchorEntity, getCurrentCameraRotation: @escaping () -> simd_quatf) {
        super.init()
        self.focus = focus
        self.cameraAnchor = cameraAnchor
        self.getCurrentCameraRotation = getCurrentCameraRotation
        self.name = "FocusEntity"
        self.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        self.addChild(self.positioningEntity)
        // Start the focus square as a billboard.
        displayAsBillboard()
        if let ringPlane = try? ModelEntity.loadModel(named: "flat_ring") {
            self.positioningEntity.addChild(ringPlane)
            self.ringIndicatorEntity = ringPlane
        }
        if let quarterRing = try? ModelEntity.loadModel(named: "quarter_ring") {
            self.quarterRingEntity = quarterRing
        }
        let detectorEntity = ModelEntity(mesh: focus.mesh)
        self.positioningEntity.addChild(detectorEntity)
        self.detectorEntity = detectorEntity
        self.stateChanged()
    }
    
    required public init() {
        fatalError("init() has not been implemented")
    }
    
    // MARK: - Appearance
    
    /// Displays the focus square parallel to the camera plane.
    func displayAsBillboard() {
        self.isOnCeiling = false
        self.currentAlignment = .none
        stateChangedSetup()
    }
    
    /// Places the focus entity in front of the camera instead of on a plane.
    func putInFrontOfCamera() {
        self.isOnCeiling = false
        // Works better than arView.ray()
        guard let newPosition = cameraAnchor?.convert(position: [0, 0, -1], to: nil) else { fatalError("cameraAnchor is nil!") }
        recentFocusEntityPositions.append(newPosition)
        updatePosition()
        // --//
        // Make focus entity face the camera with a smooth animation.
        var newRotation = self.getCurrentCameraRotation()
        newRotation *= simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        performAlignmentAnimation(to: newRotation)
    }
    
    /// Called when a surface has been detected.
    func displayOffPlane(for raycastResult: ARRaycastResult) {
        self.stateChangedSetup()
        let position = raycastResult.worldTransform.translation
        if self.currentAlignment != .none {
            // It is ready to move over to a new surface.
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
        self.stateChangedSetup(newPlane: !anchorsOfVisitedPlanes.contains(planeAnchor))
        anchorsOfVisitedPlanes.insert(planeAnchor)
        let position = raycastResult.worldTransform.translation
        if self.currentAlignment != .none {
            // It is ready to move over to a new surface.
            recentFocusEntityPositions.append(position)
        } else {
            putInFrontOfCamera()
        }
        updateTransform(raycastResult: raycastResult)
    }
    
    /// Called whenever the state of the focus entity changes
    ///
    /// - Parameter newPlane: If the entity is directly on a plane, is it a new plane to track
    public func stateChanged(newPlane: Bool = false) {
        var endColor: UIColor
        if self.isPlaceable {
            endColor = focus.onColor
        } else {
            endColor = focus.offColor
        }
        if self.detectorEntity?.model?.materials.count == 0 {
            self.detectorEntity?.model?.materials = [SimpleMaterial()]
        }
        if self.ringIndicatorEntity?.model?.materials.count == 0 {
            self.ringIndicatorEntity?.model?.materials = [SimpleMaterial()]
        }
        var modelMaterial = PhysicallyBasedMaterial()
        modelMaterial.baseColor = .init(tint: endColor)
        modelMaterial.emissiveColor = .init(color: endColor)
        modelMaterial.emissiveIntensity = 2
        self.detectorEntity?.model?.materials[0] = modelMaterial
        modelMaterial.blending = .transparent(opacity: 0.2)
        self.ringIndicatorEntity?.model?.materials[0] = modelMaterial
    }
    
    private func stateChangedSetup(newPlane: Bool = false) {
        guard !isAnimating else { return }
        self.stateChanged(newPlane: newPlane)
    }
}
