import SwiftUI

struct InfoCard: View {
    var infoText: String
    var trailingPadding: CGFloat
    var body: some View {
        ZStack {
            InfoText(infoText: infoText)
                .transition(.move(edge: .trailing))
                .animation(.easeInOut(duration: 0.5), value: infoText)
                .opacity(infoText.isEmpty ? 0 : 1)
                .animation(.easeInOut(duration: 0.4), value: infoText)
            InfoButton(foregroundStyle: infoText.isEmpty ? .white : .red)
        }.padding(.trailing, trailingPadding)
    }
    
    struct InfoText: View {
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
    
    struct InfoButton: View {
        var foregroundStyle: Color
        
        var body: some View {
            HStack {
                Spacer()
                Button(action: {
                    // TODO: add action
                }){
                    Image(systemName: "info.circle.fill")
                        .imageScale(.large)
                        .font(.system(size: 40))
                        .foregroundStyle(foregroundStyle)
                        .clipShape(Circle())
                }
            }
        }
    }
}
