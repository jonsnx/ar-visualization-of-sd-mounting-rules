import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            ARViewContainer().edgesIgnoringSafeArea(.all)
            VStack {
                Spacer()
                Button(action: {
                    ActionManager.shared.actionStream.send(.place3DModel)
                }){
                    Image(systemName: "plus")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .padding()
                        .background(.white)
                        .clipShape(Circle())
                        .padding()
                }
            }
        }
    }
}
