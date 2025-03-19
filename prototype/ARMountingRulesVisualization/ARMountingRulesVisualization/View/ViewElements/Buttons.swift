import SwiftUI

struct Buttons: View {
    @ObservedObject var arViewModel: ARViewModel
    
    var body: some View {
        VStack {
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
                        arViewModel.takeScreenshotAndSave()
                    }
                )
            }
        }
    }
}
