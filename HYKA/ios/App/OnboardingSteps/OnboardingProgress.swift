import SwiftUI

struct OnboardingProgress: View {
    let currentStep: Int
    let totalSteps: Int
    var showSignOut: Bool = false
    var onSignOut: (() -> Void)? = nil
    
    @EnvironmentObject var session: SessionManager
    
    private var percentage: Double {
        Double(currentStep) / Double(totalSteps) * 100
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Step \(currentStep) of \(totalSteps)")
                    .font(HYKATheme.caption)
                    .foregroundColor(HYKATheme.Light.mutedForeground)
                
                Spacer()
                
                if showSignOut {
                    Button(action: {
                        onSignOut?()
                    }) {
                        Text("Sign Out")
                            .font(HYKATheme.caption)
                            .foregroundColor(.red)
                    }
                    .padding(.trailing, HYKATheme.spacingM)
                }
                
                Text("\(Int(percentage))%")
                    .font(HYKATheme.caption)
                    .foregroundColor(.hykaPurple)
            }
            .padding(.horizontal, HYKATheme.spacingXXL)
            .padding(.vertical, HYKATheme.spacingL)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    // Progress fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.hykaPurple)
                        .frame(width: geometry.size.width * (percentage / 100), height: 8)
                        .animation(.easeOut(duration: 0.3), value: percentage)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, HYKATheme.spacingXXL)
            .padding(.bottom, HYKATheme.spacingL)
        }
        .background(Color.white)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(HYKATheme.Light.border),
            alignment: .bottom
        )
    }
}

#Preview {
    VStack {
        OnboardingProgress(currentStep: 4, totalSteps: 8)
        Spacer()
    }
}

