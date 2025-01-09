import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            ARViewContainer().edgesIgnoringSafeArea(.all)
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        // TODO
                    }){
                        Image(systemName: "info.circle.fill")
                            .imageScale(.large)
                            .foregroundStyle(.white)
                            .padding()
                    }
                }
                Spacer()
                HStack {
                    Button(action: {
                        // TODO
                    }){
                        Image(systemName: "arrow.clockwise")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .padding()
                            .background(.white)
                            .clipShape(Circle())
                            .padding()
                    }
                    Button(action: {
                        ActionManager.shared.actionStream.send(.placeDetector)
                    }){
                        Image(systemName: "plus")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .padding()
                            .background(.white)
                            .clipShape(Circle())
                            .padding()
                    }
                    Button(action: {
                        ActionManager.shared.actionStream.send(.removeDetector)
                    }){
                        Image(systemName: "trash")
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
}
