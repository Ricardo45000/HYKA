import SwiftUI

struct OnboardingStepPacingStrategyView: View {
    let onNext: () -> Void
    let onSkip: () -> Void
    
    @State private var selectedStrategy = 0
    
    private let strategies = [
        ("Start Easy", "8:30-9:00 min/km"),
        ("Steady Climb", "9:30-10:00 min/km"),
        ("Push the Pace", "8:00-8:30 min/km")
    ]

    var body: some View {
        ZStack {
            // Background gradient (placeholder for image)
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.15, blue: 0.20),
                    Color(red: 0.08, green: 0.10, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer().frame(height: 80)
                
                // Main card
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        Text("Pacing Strategy")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color.gray.opacity(0.8))
                        
                        Spacer()
                        
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color.hykaPurple)
                    }
                    
                    // Strategy options
                    VStack(spacing: 12) {
                        ForEach(0..<strategies.count, id: \.self) { index in
                            Button(action: {
                                selectedStrategy = index
                            }) {
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(selectedStrategy == index ? Color.hykaPurple : Color.gray.opacity(0.3))
                                            .frame(width: 24, height: 24)
                                        
                                        Text("\(index + 1)")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(selectedStrategy == index ? .white : .gray)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(strategies[index].0)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.black)
                                        
                                        Text(strategies[index].1)
                                            .font(.system(size: 12, weight: .regular))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 16)
                                .padding(.horizontal, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedStrategy == index ? Color.hykaPurple.opacity(0.1) : Color.clear)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedStrategy == index ? Color.hykaPurple : Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                        }
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                )
                .frame(maxWidth: 360)
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Bottom CTA section (text only - buttons moved to parent)
                VStack(spacing: 16) {
                    Text("Smart pacing strategies")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Personalized recommendations based on elevation and fitness data.")
                        .font(.system(size: 14, weight: .regular))
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color.white.opacity(0.8))
                }
                .frame(maxWidth: 360)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    OnboardingStepPacingStrategyView(onNext: {}, onSkip: {})
}
