
import SwiftUI

struct UIViewWrapper<V: UIView>: UIViewRepresentable {
    
    let view: UIView
    
    func makeUIView(context: Context) -> some UIView { view }
    func updateUIView(_ uiView: UIViewType, context: Context) { }
}

@main
struct HelloCustomLIDARWorldApp: App {
    
    @StateObject var arManager = ARManager()
    
    var body: some Scene {
        WindowGroup {
            UIViewWrapper(view: arManager.sceneView).ignoresSafeArea()
        }
    }
}
