import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            ARViewContainer().edgesIgnoringSafeArea(.all)
            VStack {
                Spacer()
                Button(action: {
                  // Place Model
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
