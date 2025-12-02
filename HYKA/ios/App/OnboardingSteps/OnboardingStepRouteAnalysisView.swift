import SwiftUI

struct OnboardingStepRouteAnalysisView: View {
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            // Background gradient (placeholder for image)
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.15, blue: 0.20),
                    Color(red: 0.10, green: 0.10, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer().frame(height: 60)
                
                // Main card
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        Text("Route Analysis")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color.gray.opacity(0.8))
                        
                        Spacer()
                        
                        Image(systemName: "mappin.circle")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color.hykaPurple)
                    }
                    
                    Divider()
                    
                    // Pale purple inner panel
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.hykaPurple)
                                .frame(width: 64, height: 64)
                            
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            }
                            
                            Text("GPX File Ready")
                                .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color.gray.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.hykaPurple.opacity(0.08))
                    )
                    
                    // 3-column stats row
                    HStack(alignment: .top, spacing: 24) {
                        VStack {
                            Text("Distance")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(Color.gray.opacity(0.8))
                            Text("50K")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Color.hykaPurple)
                        }
                        
                        Spacer()
                        
                        VStack {
                            Text("Elevation")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(Color.gray.opacity(0.8))
                            Text("2,400m")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Color.hykaPurple)
                        }
                        
                        Spacer()
                        
                        VStack {
                            Text("Difficulty")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(Color.gray.opacity(0.8))
                            Text("Hard")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Color.hykaPurple)
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
                    Text("Upload your race route")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Import GPX files and let AI analyze your course.")
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
    OnboardingStepRouteAnalysisView(onNext: {}, onSkip: {})
}
