import SwiftUI

struct HandwrittenTextView: View {
    let text: String
    @State private var displayedText = ""
    @State private var opacity: Double = 0
    
    var body: some View {
        Text(displayedText)
            .font(.custom("Zapfino", size: 22))
            .italic()
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeIn(duration: 0.3)) {
                    opacity = 1.0
                }
                
                for (index, character) in text.enumerated() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.03) {
                        displayedText += String(character)
                    }
                }
            }
    }
}

struct MagicalResponseView: View {
    let text: String
    @State private var isAnimating = false
    
    var body: some View {
        HandwrittenTextView(text: text)
            .modifier(SparkleEffect(isAnimating: isAnimating))
            .onAppear {
                isAnimating = true
            }
    }
}

struct SparkleEffect: ViewModifier {
    let isAnimating: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    ForEach(0..<20) { index in
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 4, height: 4)
                            .offset(x: randomPosition(in: geometry.size.width),
                                    y: randomPosition(in: geometry.size.height))
                            .opacity(isAnimating ? 0 : 1)
                            .animation(
                                Animation.easeInOut(duration: 0.5)
                                    .repeatForever()
                                    .delay(Double(index) * 0.1),
                                value: isAnimating
                            )
                    }
                }
            )
    }
    
    private func randomPosition(in range: CGFloat) -> CGFloat {
        CGFloat.random(in: 0...range)
    }
}
