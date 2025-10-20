import SwiftUI

struct SubscriptionView: View {
    let onNext: () -> Void
    let onSkip: () -> Void
    
    @EnvironmentObject var session: SessionManager
    @State private var showSignOutAlert = false
    @State private var isSigningOut = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Subscription title and Skip button
            HStack {
                HStack(spacing: HYKATheme.spacingS) {
                    Circle()
                        .fill(Color.hykaPurple)
                        .frame(width: 8, height: 8)
                    
                    Text("Subscription")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(HYKATheme.Light.foreground)
                }
                
                Spacer()
                
                Button(action: {
                    showSignOutAlert = true
                }) {
                    Text("Sign Out")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.red)
                }
                .padding(.trailing, HYKATheme.spacingM)
                
                Button(action: onSkip) {
                    Text("Skip")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.hykaPurple)
                }
            }
            .padding(.horizontal, HYKATheme.spacingXXL)
            .padding(.top, HYKATheme.spacingL)
            .padding(.bottom, HYKATheme.spacingXL)
            
            ScrollView {
                VStack(spacing: HYKATheme.spacingXXL) {
                    // Main Title
                    Text("Try the very best of HYKA. First month's on us.")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(HYKATheme.Light.foreground)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, HYKATheme.spacingXXL)
                        .padding(.top, HYKATheme.spacingL)
                    
                    // Timeline Section
                    VStack(alignment: .leading, spacing: HYKATheme.spacingXL) {
                        // Timeline Item 1: Today
                        TimelineItem(
                            timeLabel: "Today:",
                            description: "Unlock advanced pacing strategies, detailed nutrition plans, weather-integrated recommendations, and unlimited race analysis.",
                            isActive: true
                        )
                        
                        // Timeline connector line
                        Rectangle()
                            .fill(Color.hykaPurple)
                            .frame(width: 2, height: 40)
                            .padding(.leading, 4)
                        
                        // Timeline Item 2: In 28 days
                        TimelineItem(
                            timeLabel: "In 28 days:",
                            description: "Get a reminder about when your trial will end.",
                            isActive: true
                        )
                        
                        // Timeline connector line (grey)
                        Rectangle()
                            .fill(HYKATheme.Light.border)
                            .frame(width: 2, height: 40)
                            .padding(.leading, 4)
                        
                        // Timeline Item 3: In 30 days
                        TimelineItem(
                            timeLabel: "In 30 days:",
                            description: "You'll be charged the subscription amount. Cancel anytime before.",
                            isActive: false,
                            showArrow: true
                        )
                    }
                    .padding(.horizontal, HYKATheme.spacingXXL)
                    .padding(.top, HYKATheme.spacingXL)
                    
                    Spacer(minLength: HYKATheme.spacingXXL)
                    
                    // Bottom Section
                    VStack(spacing: HYKATheme.spacingL) {
                        Text("Free 30-Day Trial")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(HYKATheme.Light.foreground)
                        
                        Text("$9.99/month or $79.99/year ($6.67/mo.) after trial")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(HYKATheme.Light.mutedForeground)
                            .multilineTextAlignment(.center)
                        
                        Button(action: onNext) {
                            Text("Start free trial")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.hykaPurple)
                                .cornerRadius(HYKATheme.cornerRadiusM)
                        }
                        
                        Text("You won't be charged until the trial ends. Cancel anytime up to 24hrs before your trial ends.")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(HYKATheme.Light.mutedForeground)
                            .multilineTextAlignment(.center)
                            .padding(.top, HYKATheme.spacingS)
                    }
                    .padding(.horizontal, HYKATheme.spacingXXL)
                    .padding(.bottom, HYKATheme.spacingXXL)
                }
            }
            .background(HYKATheme.backgroundColor)
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task {
                    await handleSignOut()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    
    private func handleSignOut() async {
        isSigningOut = true
        await session.signOut()
        isSigningOut = false
    }
}

// MARK: - Timeline Item Component

struct TimelineItem: View {
    let timeLabel: String
    let description: String
    let isActive: Bool
    var showArrow: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: HYKATheme.spacingM) {
            // Dot or Arrow
            if showArrow {
                Image(systemName: "arrow.down")
                    .font(.system(size: 12))
                    .foregroundColor(HYKATheme.Light.mutedForeground)
                    .frame(width: 16, height: 16)
                    .padding(.top, 2)
            } else {
                Circle()
                    .fill(isActive ? Color.hykaPurple : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 12)
                    .padding(.top, 4)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: HYKATheme.spacingXS) {
                Text(timeLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(HYKATheme.Light.foreground)
                
                Text(description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(HYKATheme.Light.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

#Preview {
    SubscriptionView(onNext: {}, onSkip: {})
}
