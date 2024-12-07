//
//  ContentView.swift
//  HelloCustomARWorld
//
//  Created by Julian Armbruster on 05.12.24.
//

import SwiftUI
import RealityKit

struct ContentView : View {
    
    var body: some View {
        RealityView { content in
            setupBasicARWorld(content)
            content.camera = .spatialTracking
        }
    }
    
    func radFromDegrees(_ degrees: Float) -> Float {
        return degrees * .pi / 180
    }
    
    func setupBasicARWorld(_ content: RealityViewCameraContent) {
        let mesh = MeshResource.generatePlane(width: 1, height: 1)
        
        let material = SimpleMaterial(color: .red, roughness: 0.5, isMetallic: true)
        
        let model = ModelEntity(mesh: mesh, materials: [material])
            
        let anchor = AnchorEntity(
            .plane(
                .horizontal,
                classification: .ceiling,
                minimumBounds: SIMD2<Float>(1, 1)
            )
        )
        
        anchor.addChild(model)
        anchor.orientation = simd_quatf(angle: radFromDegrees(90), axis: [1, 0, 0])
        
        content.add(anchor)
    }
    
    func setupARWorldWithCustomAnchor(_ content: RealityViewCameraContent) {
        let mesh = MeshResource.generateSphere(radius: 0.2)
        let material = SimpleMaterial(color: .green, roughness: 0.5, isMetallic: true)
        let model = ModelEntity(mesh: mesh, materials: [material])
        let anchor = AnchorEntity(.)
        
        
    }
}
