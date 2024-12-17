
import SwiftUI

struct UIViewWrapper<V: UIView>: UIViewRepresentable {
    
    let view: UIView
    
    func makeUIView(context: Context) -> some UIView { view }
    func updateUIView(_ uiView: UIViewType, context: Context) { }
}

@main
struct PointCloudExampleApp: App {
    
    @StateObject var arManager = ARManager()
    
    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .bottom) {
                UIViewWrapper(view: arManager.sceneView).ignoresSafeArea()
                
                HStack(spacing: 30) {
                    Button {
                        arManager.isCapturing.toggle()
                    } label: {
                        Image(systemName: arManager.isCapturing ?
                                          "stop.circle.fill" :
                                          "play.circle.fill")
                    }
                    
                    ShareLink(item: PLYFile(pointCloud: arManager.pointCloud),
                                            preview: SharePreview("exported.ply")) {
                        Image(systemName: "square.and.arrow.up.circle.fill")
                    }
                }.foregroundStyle(.black, .white)
                    .font(.system(size: 50))
                    .padding(25)
            }
        }
    }
}
