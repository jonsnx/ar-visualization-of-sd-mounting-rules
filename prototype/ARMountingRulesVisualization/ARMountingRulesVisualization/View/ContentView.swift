import SwiftUI
import Combine

struct ContentView: View {
    @ObservedObject var arViewModel: ARViewModel = ARViewModel()
    
    var body: some View {
        ZStack {
            ARViewWrapper(arViewModel: arViewModel).edgesIgnoringSafeArea(.all)
            VStack {
                ZStack {
                    InfoCard(infoText: arViewModel.mountingState.rawValue)
                        .transition(.move(edge: .trailing))
                        .animation(.easeInOut(duration: 0.5), value: arViewModel.mountingState.rawValue)
                        .opacity(arViewModel.mountingState.rawValue.isEmpty ? 0 : 1)
                        .animation(.easeInOut(duration: 0.4), value: arViewModel.mountingState.rawValue)
                    HStack {
                        Spacer()
                        Button(action: {
                            // TODO: add action
                        }){
                            let foregroundStyle: Color = arViewModel.mountingState.rawValue.isEmpty ? .white : .red
                            Image(systemName: "info.circle.fill")
                                .imageScale(.large)
                                .font(.system(size: 40))
                                .foregroundStyle(foregroundStyle)
                                .clipShape(Circle())
                        }
                    }
                }.padding(.trailing, 10.0)
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
                        arViewModel.placeDetector()
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
                        arViewModel.removeDetector()
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

struct InfoCard: View {
    var infoText: String
    
    var body: some View {
        HStack {
            Spacer()
            Text(infoText)
                .font(.footnote)
                .foregroundColor(.black)
                .padding(.trailing, 50.0)
                .padding()
                .background(Color.white)
                .cornerRadius(25)
                .shadow(radius: 5)
                .padding(5)
        }
    }
}
