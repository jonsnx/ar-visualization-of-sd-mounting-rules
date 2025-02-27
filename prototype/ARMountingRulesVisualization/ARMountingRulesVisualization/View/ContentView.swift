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
                HStack {
                    ControlButton(
                        iconName: "plus",
                        action: {
                            arViewModel.placeDetector()
                        }
                    )
                    ControlButton(
                        iconName: "trash",
                        action: {
                            arViewModel.removeDetector()
                        }
                    )
                    ControlButton(
                        iconName: "camera.fill",
                        action: {
                            //TODO: add action
                        }
                    )
                }
            }
        }
    }
}
