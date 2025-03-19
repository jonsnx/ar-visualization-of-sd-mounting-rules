import SwiftUI

struct ContentView: View {
    @ObservedObject var arViewModel: ARViewModel = ARViewModel()
    
    var body: some View {
        ZStack {
            ARViewWrapper(arViewModel: arViewModel).edgesIgnoringSafeArea(.all)
            VStack {
                InfoCard(
                    infoText: arViewModel.errorType.message,
                    trailingPadding: 10.0
                )
                Spacer()
                ControlButton(
                    iconName: "plus",
                    action: {
                        arViewModel.addPoint()
                    }
                )
            }
        }
    }
}
