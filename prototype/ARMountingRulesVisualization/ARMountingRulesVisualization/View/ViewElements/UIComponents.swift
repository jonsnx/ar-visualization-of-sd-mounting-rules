import SwiftUI

struct UIComponents: View {
    @ObservedObject var arViewModel: ARViewModel
    
    var body: some View {
        VStack {
            InfoCard(
                infoText: arViewModel.errorType.message,
                trailingPadding: 10.0
            )
            Spacer()
            Buttons(arViewModel: arViewModel)
        }
    }
}


