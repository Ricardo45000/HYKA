import SwiftUI

struct SplashView: View {
    @State private var appear = false

    var body: some View {
        ZStack {
            // Brand purple background
            Color.hykaPurple
                .ignoresSafeArea()

            VStack(spacing: 32) {
                // HYKA wordmark
                Text("HYKA")
                    .font(.system(size: 61, weight: .heavy, design: .default))
                                        .fontWidth(.condensed)
                                        .modifier(ForwardSlant(degrees: 10)) // <-- custom fake italic
                                        .kerning(0.5)
                                        .foregroundColor(.white)
                                        .textCase(.uppercase)
                                        .scaleEffect(appear ? 1.0 : 0.92)
                                        .opacity(appear ? 1 : 0)
                                        .animation(.easeOut(duration: 0.45), value: appear)

                // Tagline
                Text("Plan smarter. Go farther.")
                    .font(.system(size: 17, weight: .regular, design: .default))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color.white.opacity(0.8))
                    // subtle entrance, but less dramatic than HYKA
                    .offset(y: appear ? 0 : 16)
                    .opacity(appear ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.15), value: appear)
            }
        
        }
        .preferredColorScheme(.dark)
        .onAppear {
            appear = true
        }
    }
}





