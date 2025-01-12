import ARKit

actor ARManager {
    @MainActor var isProcessingAnchors = false
    @MainActor var isProcessingFrame = false
    @MainActor var sceneAnchors = [UUID : Plane]()
    @MainActor var specialAnchors = [UUID : ARMeshAnchor]()
    
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
                if simd_distance(position, targetPosition) <= 0.6 {
                    return false
                }
                if frame != nil {
                    // return await !isTooCloseToWindowOrDoor(for: frame!, to: targetPosition)
                }
            }
        return true
    }
    
    func isTooCloseToWindowOrDoor(for frame: ARFrame, to location: SIMD3<Float>) async -> Bool {
        var meshAnchors = frame.anchors.compactMap({ $0 as? ARMeshAnchor })
        // Sort the mesh anchors by distance to the given location and filter out
        // any anchors that are too far away (4 meters is a safe upper limit).
        let cutoffDistance: Float = 4.0
        meshAnchors.removeAll { distance($0.transform.translation, location) > cutoffDistance }
        meshAnchors.sort { distance($0.transform.translation, location) < distance($1.transform.translation, location) }
        for anchor in meshAnchors {
            for index in 0..<anchor.geometry.faces.count {
                // Get the center of the face so that we can compare it to the given location.
                let geometricCenterOfFace = anchor.geometry.centerOf(faceWithIndex: index)
                
                // Convert the face's center to world coordinates.
                var centerLocalTransform = matrix_identity_float4x4
                centerLocalTransform.columns.3 = SIMD4<Float>(geometricCenterOfFace.0, geometricCenterOfFace.1, geometricCenterOfFace.2, 1)
                let centerWorldPosition = (anchor.transform * centerLocalTransform).translation
                
                // We're interested in a classification that is sufficiently close to the given location––within 5 cm.
                let distanceToFace = distance(centerWorldPosition, location)
                if distanceToFace <= 1.5 {
                    // Get the semantic classification of the face and finish the search.
                    let classification: ARMeshClassification = anchor.geometry.classificationOf(faceWithIndex: index)
                    if classification == .window || classification == .door {
                        return true
                    }
                }
            }
        }
        return false
    }
}
