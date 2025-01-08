//
//  FocusEntity.swift
//  FocusEntity
//
//  Created by Max Cobb on 8/26/19.
//  Copyright © 2019 Max Cobb. All rights reserved.
//

import RealityKit
#if !os(macOS)
import ARKit
#endif

public struct FocusEntityComponent: Component {
    /// Color when tracking the surface of a known plane
    let onColor: MaterialColorParameter
    /// Color when tracking an estimated plane
    let offColor: MaterialColorParameter
    let mesh: MeshResource
    
    /// Default color of FocusEntity
    public static let defaultColor = #colorLiteral(red: 1, green: 0.8, blue: 0, alpha: 1)
    /// Default style of FocusEntity, using the FocusEntityComponent.Style.classic with the color FocusEntityComponent.defaultColor.
    public static let classic = FocusEntityComponent(
        onColor: .color(.green),
        offColor: .color(.red),
        mesh: MeshResource.generatePlane(width: 0.1, depth: 0.1)
    )
    
    public internal(set) var isOpen = false
    
    internal var segments: [FocusEntity.Segment] = []
    
    #if !os(macOS)
    public var allowedRaycasts: [ARRaycastQuery.Target] = [.existingPlaneGeometry, .estimatedPlane]
    #endif
}
