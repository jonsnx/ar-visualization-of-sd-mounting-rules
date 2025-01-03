import ARKit

actor ARManager {
    @MainActor var isProcessing = false
    @MainActor var sceneAnchors = [UUID : Plane]()
    
    func process(anchors: [ARAnchor]) async -> ([Plane], [Plane]) {
        var anchorsToBeAdded = [Plane]()
        var anchorsToBeRemoved = [Plane]()
        
        let anchorsToProcess = getProcessableAnchors(anchors: anchors)
        
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
    
    private func getProcessableAnchors(anchors: [ARAnchor]) -> [ARPlaneAnchor] {
        var anchorsToProcess = [ARPlaneAnchor]()
        for anchor in anchors {
            guard let planeAnchor = anchor as? ARPlaneAnchor else { continue }
            if planeAnchor.classification == .ceiling {
                anchorsToProcess.append(planeAnchor)
            }
        }
        return anchorsToProcess
    }
    
    @MainActor
    private func createPlaneEntity(for planeAnchor: ARPlaneAnchor) -> Plane {
        let planeEntity = Plane(planeAnchor: planeAnchor)
        planeEntity.transform.matrix = planeAnchor.transform
        return planeEntity
    }
    
    @MainActor
    func toggleIsProcessing() {
        self.isProcessing = !self.isProcessing
    }
}
