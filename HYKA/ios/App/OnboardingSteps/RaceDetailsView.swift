import SwiftUI

struct RaceDetailsView: View {
    @Binding var raceDetails: RaceDetails
    let onNext: () -> Void
    let onBack: () -> Void
    
    @EnvironmentObject var session: SessionManager
    @State private var raceName: String = "UTMB"
    @State private var raceDate: Date = RaceDetails.mock.date
    @State private var startTime: Date = RaceDetails.mock.startTime
    @State private var showSignOutAlert = false
    @State private var isSigningOut = false
    @FocusState private var raceNameFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: HYKATheme.spacingXXL) {
                    VStack(spacing: HYKATheme.spacingS) {
                        Text("Tell us about your race")
                            .font(HYKATheme.h2)
                            .foregroundColor(HYKATheme.Light.foreground)
                            .multilineTextAlignment(.center)
                        
                        Text("Add details to help us create the best strategy for your race day")
                            .font(HYKATheme.body)
                            .foregroundColor(HYKATheme.Light.mutedForeground)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, HYKATheme.spacingXXL)
                    .padding(.top, HYKATheme.spacingXXL)
                    .padding(.bottom, HYKATheme.spacingL)
                    
                    VStack(spacing: HYKATheme.spacingXXL) {
                        VStack(spacing: HYKATheme.spacingXL) {
                            // Race Name
                            VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                                HYKAUILabel(text: "Race name", isRequired: true)
                                HYKAUIInput(
                                    placeholder: "e.g. UTMB",
                                    text: $raceName,
                                    icon: "flag.checkered"
                                )
                                .focused($raceNameFocused)
                            }
                            
                            // Race Date
                            VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                                HYKAUILabel(text: "Race date", isRequired: true)
                                DatePicker("", selection: $raceDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .tint(Color.hykaPurple)
                                    .padding(HYKATheme.spacingM)
                                    .background(HYKATheme.Light.inputBackground)
                                    .cornerRadius(HYKATheme.cornerRadiusM)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                                            .stroke(HYKATheme.Light.border, lineWidth: 1)
                                    )
                            }
                            
                            // Start Time
                            VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                                HYKAUILabel(text: "Start time", isRequired: true)
                                DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.compact)
                                    .tint(Color.hykaPurple)
                                    .padding(HYKATheme.spacingM)
                                    .background(HYKATheme.Light.inputBackground)
                                    .cornerRadius(HYKATheme.cornerRadiusM)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                                            .stroke(HYKATheme.Light.border, lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.horizontal, HYKATheme.spacingXXL)
                        .padding(.top, HYKATheme.spacingXXL)
                        
                        Spacer(minLength: HYKATheme.spacingXXL)
                        
                        // Buttons
                        VStack(spacing: HYKATheme.spacingM) {
                            HYKAButton(title: "Continue", style: .primary) {
                                raceDetails = RaceDetails(
                                    name: raceName,
                                    date: raceDate,
                                    startTime: startTime,
                                    distance: raceDetails.distance,
                                    elevation: raceDetails.elevation,
                                    difficulty: raceDetails.difficulty
                                )
                                raceNameFocused = false
                                onNext()
                            }
                            
                            HYKAButton(title: "Back", style: .outline, action: onBack)
                        }
                        .padding(.horizontal, HYKATheme.spacingXXL)
                        .padding(.bottom, HYKATheme.spacingXXL)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneToolbar()
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
        .preferredColorScheme(.light)
        .onAppear {
            raceName = raceDetails.name
            raceDate = raceDetails.date
            startTime = raceDetails.startTime
        }
    }
    
    private func handleSignOut() async {
        isSigningOut = true
        await session.signOut()
        isSigningOut = false
    }
}

#Preview {
    RaceDetailsView(raceDetails: .constant(.mock), onNext: {}, onBack: {})
}


