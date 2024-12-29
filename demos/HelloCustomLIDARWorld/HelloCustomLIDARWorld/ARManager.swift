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
            
            // 1. Find the extreme points
            var minXMaxYMinZ: (SCNVector3, simd_float4) = (SCNVector3(Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude), simd_float4(1.0, 0.0, 0.0, 1.0)) // Red
            var maxXMaxYMinZ: (SCNVector3, simd_float4) = (SCNVector3(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude), simd_float4(0.0, 1.0, 0.0, 1.0)) // Green
            var minXMaxYMaxZ: (SCNVector3, simd_float4) = (SCNVector3(Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude), simd_float4(0.0, 0.0, 1.0, 1.0)) // Blue
            var maxXMaxYMaxZ: (SCNVector3, simd_float4) = (SCNVector3(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude), simd_float4(1.0, 1.0, 0.0, 1.0)) // Yellow

            // 2. Iterate through point cloud to find the extreme points
            for vertex in await pointCloud.vertices.values {
                let position = vertex.position
                print("Vertex position: \(position)")
                
                if position.x < minXMaxYMinZ.0.x && position.y > minXMaxYMinZ.0.y && position.z < minXMaxYMinZ.0.z {
                    minXMaxYMinZ.0 = position
                    print("NewMinXMaxYMinZ Vertex position: \(minXMaxYMinZ.0)")
                }
                if position.x > maxXMaxYMinZ.0.x && position.y > maxXMaxYMinZ.0.y && position.z < maxXMaxYMinZ.0.z {
                    maxXMaxYMinZ.0 = position
                    print("NewMaxXMaxYMinZ Vertex position: \(maxXMaxYMinZ.0)")
                }
                if position.x < minXMaxYMaxZ.0.x && position.y > minXMaxYMaxZ.0.y && position.z > minXMaxYMaxZ.0.z {
                    minXMaxYMaxZ.0 = position
                    print("NewMinXMaxYMaxZ Vertex position: \(minXMaxYMaxZ.0)")
                }
                if position.x > maxXMaxYMaxZ.0.x && position.y > maxXMaxYMaxZ.0.y && position.z > maxXMaxYMaxZ.0.z {
                    maxXMaxYMaxZ.0 = position
                    print("NewMaxXMaxYMaxZ Vertex position: \(maxXMaxYMaxZ.0)")
                }
            }

            // 3. Collect the extreme points
            let extremePoints = [
                minXMaxYMinZ,
                maxXMaxYMinZ,
                minXMaxYMaxZ,
                maxXMaxYMaxZ
            ]

            // 4. Create a geometry for these extreme points
            let vertices = extremePoints.map { $0.0 }
            let colors = extremePoints.map { $0.1 }

            // Create a vertex source for geometry
            let vertexSource = SCNGeometrySource(vertices: vertices)

            // Create a color source
            let colorData = Data(bytes: colors.map { $0 }, count: MemoryLayout<simd_float4>.size * colors.count)
            let colorSource = SCNGeometrySource(data: colorData,
                                                semantic: .color,
                                                vectorCount: colors.count,
                                                usesFloatComponents: true,
                                                componentsPerVector: 4,
                                                bytesPerComponent: MemoryLayout<Float>.size,
                                                dataOffset: 0,
                                                dataStride: MemoryLayout<SIMD4<Float>>.size)

            // Create indices for the extreme points (we're visualizing each one individually)
            let pointIndices: [UInt32] = Array(0..<UInt32(vertices.count))
            let element = SCNGeometryElement(indices: pointIndices, primitiveType: .point)

            // Customize the size of the point, rendered in ARView
            element.maximumPointScreenSpaceRadius = 15

            // Create the geometry
            let geometry = SCNGeometry(sources: [vertexSource, colorSource], elements: [element])
            geometry.firstMaterial?.isDoubleSided = true
            geometry.firstMaterial?.lightingModel = .constant

            // Apply the geometry to the geometry node
            Task { @MainActor in
                geometryNode.geometry = geometry
            }

            /*
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
            */
        }
}
