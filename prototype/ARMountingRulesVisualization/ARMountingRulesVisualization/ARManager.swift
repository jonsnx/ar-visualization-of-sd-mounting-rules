import ARKit

actor ARManager {
    @MainActor var isProcessingAnchors = false
    @MainActor var isProcessingFrame = false
    @MainActor var sceneAnchors = [UUID : Plane]()
    
    @MainActor
    private func createPlaneEntity(for planeAnchor: ARPlaneAnchor) -> Plane {
        let planeEntity = Plane(planeAnchor: planeAnchor)
        planeEntity.transform.matrix = planeAnchor.transform
        return planeEntity
    }
    
    @MainActor
    func toggleIsProcessingAnchors() {
        self.isProcessingAnchors = !self.isProcessingAnchors
    }
    
    @MainActor
    func toggleIsProcessingFrame() {
        print("toggled isProcessingFrame")
        self.isProcessingFrame = !self.isProcessingFrame
    }
    
    func processAnchors(anchors: [ARAnchor]) async -> ([Plane], [Plane]) {
        var anchorsToBeAdded = [Plane]()
        var anchorsToBeRemoved = [Plane]()
        
        let anchorsToProcess = getPlaneAnchors(anchors: anchors)
        
        if anchorsToProcess.isEmpty { return ([], []) }
        
        for a1 in anchorsToProcess {
            var isNonDominant = false
            for a2 in anchorsToProcess {
                if a1.identifier == a2.identifier { continue }
                if !a1.intersects(a2) { continue }
                if a1 <= a2 {
                    isNonDominant = true
                    guard let plane = await self.sceneAnchors[a1.identifier] else { break }
                    anchorsToBeRemoved.append(plane)
                    Task { @MainActor in
                        self.sceneAnchors.removeValue(forKey: a1.identifier)
                    }
                    break
                }
            }
            if isNonDominant { continue }
            if await self.sceneAnchors.contains(where: { $0.key == a1.identifier }) {
                await self.sceneAnchors[a1.identifier]!.didUpdate(anchor: a1)
            } else {
                let plane = await createPlaneEntity(for: a1)
                anchorsToBeAdded.append(plane)
                Task { @MainActor in
                    self.sceneAnchors.updateValue(plane, forKey: a1.identifier)
                }
            }
        }
        return (anchorsToBeAdded, anchorsToBeRemoved)
    }
    
    private func getPlaneAnchors(anchors: [ARAnchor]) -> [ARPlaneAnchor] {
        var planeAnchors = [ARPlaneAnchor]()
        for anchor in anchors {
            guard let planeAnchor = anchor as? ARPlaneAnchor else { continue }
            if planeAnchor.classification == .ceiling {
                planeAnchors.append(planeAnchor)
            }
        }
        return planeAnchors
    }
    
    func isPlaceable(at position: SIMD3<Float>, for raycastData: [RaycastData], with frame: ARFrame? = nil) async -> Bool {
            for data in raycastData {
                let targetPosition = data.result.worldTransform.translation
                let distance: Float = simd_distance(position, targetPosition)
                print("Distance for \(targetPosition) from \(position): \(distance)")
                if distance <= 0.6 {
                    return false
                }
                if frame != nil {
                    return await !isTooCloseToWindowOrDoor(for: frame!, from: position)
                }
            }
        return true
    }
    
    func isTooCloseToWindowOrDoor(for frame: ARFrame, from position: SIMD3<Float>) async -> Bool {
        var meshAnchors = frame.anchors.compactMap({ $0 as? ARMeshAnchor })
        let cutoffDistance: Float = 1.5
        meshAnchors.removeAll { distance($0.transform.translation, position) > cutoffDistance }
        for anchor in meshAnchors {
            for index in 0..<anchor.geometry.faces.count {
                let classification: ARMeshClassification = anchor.geometry.classificationOf(faceWithIndex: index)
                if classification == .window || classification == .door {
                    let geometricCenterOfFace = anchor.geometry.centerOf(faceWithIndex: index)
                    var centerLocalTransform = matrix_identity_float4x4
                    centerLocalTransform.columns.3 = SIMD4<Float>(geometricCenterOfFace.0, geometricCenterOfFace.1, geometricCenterOfFace.2, 1)
                    let centerWorldPosition = (anchor.transform * centerLocalTransform).translation
                    let distanceToFace = distance(centerWorldPosition, position)
                    if distanceToFace <= 1.5 {
                        return true
                    }
                }
            }
        }
        return false
    }
}
