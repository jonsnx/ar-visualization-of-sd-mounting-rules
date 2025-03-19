import SwiftUI

struct ContentView: View {
    @ObservedObject var arViewModel: ARViewModel = ARViewModel()
    
    var body: some View {
        ZStack {
            ARViewWrapper(arViewModel: arViewModel).edgesIgnoringSafeArea(.all)
            UIComponents(arViewModel: arViewModel)
        }
    }
}
