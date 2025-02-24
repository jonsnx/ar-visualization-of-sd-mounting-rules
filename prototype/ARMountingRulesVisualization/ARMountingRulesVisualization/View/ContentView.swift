import SwiftUI
import Combine

struct ContentView: View {
    @State private var infoText: String = ""
    
    var body: some View {
        ZStack {
            ARViewWrapper(arViewModel: ARViewModel(), infoText: $infoText).edgesIgnoringSafeArea(.all)
            VStack {
                ZStack {
                    InfoCard(infoText: infoText)
                        .transition(.move(edge: .trailing))
                        .animation(.easeInOut(duration: 0.5), value: infoText)
                        .opacity(infoText.isEmpty ? 0 : 1)
                        .animation(.easeInOut(duration: 0.4), value: infoText)
                    HStack {
                        Spacer()
                        Button(action: {
                            // TODO: add action
                        }){
                            let foregroundStyle: Color = !infoText.isEmpty ? .red : .white
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
                        //TODO: add action
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
                        //TODO: add action
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
