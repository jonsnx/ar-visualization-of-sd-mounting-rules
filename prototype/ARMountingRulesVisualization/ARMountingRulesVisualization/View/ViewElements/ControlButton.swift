import SwiftUI

struct ControlButton: View {
    var iconName: String
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.headline)
                .foregroundStyle(.black)
                .padding()
                .background(.white)
                .clipShape(Circle())
                .padding()
        }
    }
}
