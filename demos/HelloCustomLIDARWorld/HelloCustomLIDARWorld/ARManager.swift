import ARKit

actor ARManager: NSObject, ARSessionDelegate, ObservableObject {
    
    @MainActor let sceneView = ARSCNView()
    @MainActor private var isProcessing = false
    @MainActor @Published var isCapturing = false
    @MainActor let geometryNode = SCNNode()
    
    let pointCloud = PointCloud()
    
    @MainActor
    override init() {
        super.init()
        
        sceneView.session.delegate = self

        // start session
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = .sceneDepth
        sceneView.session.run(configuration)
        sceneView.scene.rootNode.addChildNode(geometryNode)
    }
        
    // an ARSessionDelegate function for receiving an ARFrame instances
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        Task { await process(frame: frame) }
    }
        
    // process a frame and skip frames that arrive while processing
    @MainActor
        private func process(frame: ARFrame) async {
            guard !isProcessing && isCapturing else { return }
            
            isProcessing = true
            await pointCloud.process(frame: frame)
            await updateGeometry() // <- add here the geometry update
            isProcessing = false
        }

        func updateGeometry() async {
            // make an array of every 10th point
            let vertices = await pointCloud.vertices.values.enumerated().filter { index, _ in
                    index % 10 == 9
                }.map { $0.element }
            
            // create a vertex source for geometry
            let vertexSource = SCNGeometrySource(vertices: vertices.map { $0.position } )
            
            // create a color source
            let colorData = Data(bytes: vertices.map { $0.color },
                                 count: MemoryLayout<simd_float4>.size * vertices.count)

            let colorSource = SCNGeometrySource(data: colorData,
                                                semantic: .color,
                                                vectorCount: vertices.count,
                                                usesFloatComponents: true,
                                                componentsPerVector: 4,
                                                bytesPerComponent: MemoryLayout<Float>.size,
                                                dataOffset: 0,
                                                dataStride: MemoryLayout<SIMD4<Float>>.size)

            // as we don't use proper geometry, we can pass just an array of
            // indices to our geometry element
            let pointIndices: [UInt32] = Array(0..<UInt32(vertices.count))
            let element = SCNGeometryElement(indices: pointIndices, primitiveType: .point)
            
            // here we can customize the size of the point, rendered in ARView
            element.maximumPointScreenSpaceRadius = 15
            
            let geometry = SCNGeometry(sources: [vertexSource, colorSource],
                                       elements: [element])
            geometry.firstMaterial?.isDoubleSided = true
            geometry.firstMaterial?.lightingModel = .constant
            
            Task { @MainActor in
                geometryNode.geometry = geometry
            }
        }
}
