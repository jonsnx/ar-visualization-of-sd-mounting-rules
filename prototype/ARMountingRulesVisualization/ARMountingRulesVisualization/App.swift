import UIKit
import SwiftUI
import ARKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        guard ARWorldTrackingConfiguration.isSupported else {
            fatalError("ARKit is not available on this device.")
        }
        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) else {
            fatalError("Scene reconstruction requires a device with a LiDAR Scanner, such as the 3th-Gen iPad Pro.")
        }
        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView()
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIHostingController(rootView: contentView)
        self.window = window
        window.makeKeyAndVisible()
        return true
    }
}
