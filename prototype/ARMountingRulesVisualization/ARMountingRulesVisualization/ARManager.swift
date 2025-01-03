import UIKit
import RealityKit
import ARKit

actor ARManager {
    @MainActor var isProcessing = false
    @MainActor var sceneAnchors = [UUID : Plane]()

    func process(anchors: [ARAnchor]) async -> ([ARPlaneAnchor], [ARPlaneAnchor], [ARPlaneAnchor]) {
        var anchorsToBeAdded = [ARPlaneAnchor]()
        var anchorsToBeUpdated = [ARPlaneAnchor]()
        var anchorsToBeRemoved = [ARPlaneAnchor]()
        
        var anchorsToProcess = getProcessableAnchors(anchors: anchors)
        
        if anchorsToProcess.isEmpty { return ([], [], []) }
        
        for a1 in anchorsToProcess {
            var isNonDominant = false
            for a2 in anchorsToProcess {
                if a1.identifier == a2.identifier { continue }
                if !a1.intersects(a2) { continue }
                if a1 < a2 {
                    isNonDominant = true
                    anchorsToBeRemoved.append(a1)
                    break
                }
            }
            if isNonDominant { continue }
            if await self.sceneAnchors.contains(where: { $0.key == a1.identifier }) {
                anchorsToBeUpdated.append(a1)
            } else {
                anchorsToBeAdded.append(a1)
            }
        }
        
        return (anchorsToBeAdded, anchorsToBeUpdated, anchorsToBeRemoved)
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
}
