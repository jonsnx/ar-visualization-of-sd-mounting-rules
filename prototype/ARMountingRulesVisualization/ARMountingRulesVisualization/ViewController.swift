import RealityKit
import ARKit
import FocusEntity

class ViewController: UIViewController, ARSessionDelegate {
    private var focusEntity: FocusEntity!
    private var arView: ARView!
    
    var arManager = ARManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        arView = ARView(frame: view.bounds)
        arView.session.delegate = self
        view.addSubview(arView)
        
        arView.environment.sceneUnderstanding.options = []
        arView.environment.sceneUnderstanding.options.insert(.physics)
        //arView.debugOptions.insert(.showSceneUnderstanding)
        arView.renderOptions = [.disablePersonOcclusion, .disableDepthOfField, .disableMotionBlur]
        
        arView.automaticallyConfigureSession = false
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.sceneReconstruction = .meshWithClassification
        arView.session.run(configuration)
        focusEntity = FocusEntity.init(on: arView, focus: FocusEntityComponent.detector)
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        /*
         Task {
         await processAnchors(anchors: anchors)
         }
         */
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        /*
         Task {
         await processAnchors(anchors: anchors)
         }
         */
    }
    
    func processAnchors(anchors: [ARAnchor]) async {
        if arManager.isProcessing { return }
        arManager.toggleIsProcessing()
        
        let (addedAnchors, removedAnchors) = await arManager.process(anchors: anchors)
        
        addedAnchors.forEach({ arView.scene.addAnchor($0) })
        removedAnchors.forEach({ arView.scene.anchors.remove($0) })
        
        arManager.toggleIsProcessing()
    }
}
