import SwiftUI
import Auth

struct OnboardingFlowView: View {
    @EnvironmentObject var session: SessionManager
    @State private var currentStep = 1
    @State private var userProfile = UserProfile()
    @State private var raceDetails = RaceDetails.mock
    @State private var aidStations = AidStation.mock
    @State private var strategyPreferences = StrategyPreferences()
    @State private var showStrategyResults = false
    @State private var isSavingData = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isUploadingGPX = false
    
    private let totalSteps = 9
    
    var body: some View {
        NavigationView {
            ZStack {
                HYKATheme.backgroundColor
                    .ignoresSafeArea()
                
                if showStrategyResults {
                    StrategyResultsView()
                } else {
                    // Content
                    TabView(selection: $currentStep) {
                            OnboardingStepProfileDetailsView(
                                userProfile: $userProfile,
                                onNext: nextStep,
                                onBack: previousStep
                            )
                                .tag(1)
                            
                            OnboardingStepGenderView(
                                userProfile: $userProfile,
                                onNext: nextStep,
                                onBack: previousStep
                            )
                                .tag(2)
                            
                            RunningProfileView(
                                userProfile: $userProfile,
                                onNext: nextStep,
                                onBack: previousStep
                            )
                                .tag(3)
                            
                            SubscriptionView(onNext: nextStep, onSkip: nextStep)
                                .tag(4)
                            
                            ConnectDevicesView(onNext: nextStep, onSkip: nextStep, onBack: previousStep)
                                .tag(5)
                            
                            UploadGPXView(
                                onNext: nextStep,
                                onSkip: nextStep,
                                onGPXImported: { _, distance in
                                    updateFinishDistance(distance)
                                    isUploadingGPX = false
                                },
                                onUploadStatusChange: { isUploadingGPX = $0 },
                                isContinueDisabled: isUploadingGPX
                            )
                                .tag(6)
                            
                            RaceDetailsView(
                                raceDetails: $raceDetails,
                                onNext: nextStep,
                                onBack: previousStep
                            )
                                .tag(7)
                            
                            AidStationsView(
                                aidStations: $aidStations,
                                onNext: nextStep,
                                onBack: previousStep
                            )
                                .tag(8)
                            
                            StrategyPreferencesView(
                                preferences: $strategyPreferences,
                                onGenerate: generateStrategy,
                                onBack: previousStep
                            )
                                .tag(9)
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        ))
                }
                
                // Loading overlay
                if isSavingData {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: HYKATheme.spacingL) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text("Saving your data...")
                            .font(HYKATheme.h4)
                            .foregroundColor(.white)
                    }
                    .padding(HYKATheme.spacingXXL)
                    .background(
                        RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusL)
                            .fill(Color.hykaPurple)
                    )
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85, blendDuration: 0), value: currentStep)
            .animation(.easeInOut(duration: 0.35), value: showStrategyResults)
            .animation(.easeInOut(duration: 0.25), value: isSavingData)
            .alert("Error Saving Data", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .keyboardDoneToolbar()
    }
    
    private var currentStepTitle: String {
        switch currentStep {
        case 1: return "Tell us who you are"
        case 2: return "Tell us who you are"
        case 3: return "Your running profile"
        case 4: return "Subscription"
        case 5: return "Connect your devices"
        case 6: return "Upload your race course"
        case 7: return "Tell us about your race"
        case 8: return "Strategy Preferences"
        default: return "Onboarding"
        }
    }
    
    private func nextStep() {
        if currentStep < totalSteps {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85, blendDuration: 0)) {
                currentStep += 1
            }
        }
    }
    
    private func previousStep() {
        if currentStep > 1 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85, blendDuration: 0)) {
                currentStep -= 1
            }
        }
    }
    
    private func updateFinishDistance(_ distanceKm: Double) {
        guard distanceKm > 0 else { return }
        var updatedStations = aidStations
        if updatedStations.isEmpty {
            updatedStations = [
                AidStation(name: "Start", distance: 0, services: []),
                AidStation(name: "Finish", distance: distanceKm, services: [])
            ]
        } else {
            if let finishIndex = updatedStations.lastIndex(where: { $0.name.lowercased() == "finish" }) {
                let finish = updatedStations[finishIndex]
                updatedStations[finishIndex] = AidStation(name: finish.name, distance: distanceKm, services: finish.services)
            } else {
                updatedStations.append(AidStation(name: "Finish", distance: distanceKm, services: []))
            }
        }
        aidStations = updatedStations.sorted { $0.distance < $1.distance }
    }
    
    private func generateStrategy() {
        Task { @MainActor in
            // Get user ID from currentUser or fallback to UserDefaults
            var userId: UUID?
            
            if let user = session.currentUser {
                userId = user.id
            } else if session.isAuthenticated {
                // Fallback: Check UserDefaults for user ID (set during OAuth fallback)
                if let userIdString = UserDefaults.standard.string(forKey: "hyka.user.id"),
                   let id = UUID(uuidString: userIdString) {
                    userId = id
                    print("✅ Using user ID from UserDefaults for onboarding completion: \(userIdString)")
                }
            }
            
            guard let userId = userId else {
                print("❌ No user ID available - isAuthenticated: \(session.isAuthenticated), currentUser: \(session.currentUser?.id ?? nil)")
                errorMessage = "User not authenticated. Please sign in again."
                showErrorAlert = true
                return
            }
            
            isSavingData = true
            
            do {
                // 1. Save user profile to Supabase
                try await SupabaseService.saveUserProfile(userProfile, userId: userId)
                
                // 2. Save race plan with aid stations and preferences
                let racePlanId = try await SupabaseService.saveRacePlan(
                    userId: userId,
                    raceDetails: raceDetails,
                    aidStations: aidStations,
                    preferences: strategyPreferences
                )
                
                print("✅ All onboarding data saved successfully. Race plan ID: \(racePlanId)")
                
                // 3. Mark onboarding as complete
                await session.completeOnboarding()
                
                // Hide loading overlay before showing results
                isSavingData = false
                
                // 4. Show strategy results
                withAnimation(.easeInOut(duration: 0.35)) {
                    showStrategyResults = true
                }
                
            } catch {
                // Always hide loading overlay on error
                isSavingData = false
                
                // Get detailed error information
                var detailedError = error.localizedDescription
                if let supabaseError = error as? DecodingError {
                    detailedError = "Data encoding error: \(supabaseError)"
                } else if let urlError = error as? URLError {
                    detailedError = "Network error: \(urlError.localizedDescription)"
                } else {
                    // Try to get more details from the error
                    let errorDescription = String(describing: error)
                    detailedError = errorDescription
                }
                
                errorMessage = "Failed to save data: \(detailedError)"
                showErrorAlert = true
                print("❌ Error saving onboarding data: \(error)")
                print("❌ Error details: \(detailedError)")
                if let nsError = error as NSError? {
                    print("❌ Error domain: \(nsError.domain), code: \(nsError.code)")
                    print("❌ Error userInfo: \(nsError.userInfo)")
                }
            }
        }
    }
}

// MARK: - Strategy Results View

struct StrategyResultsView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HYKAHeader(
                title: "Your Race Strategy",
                showProgress: false,
                currentStep: 1,
                totalSteps: 1
            )
            
            // Tab Selector
            Picker("Strategy View", selection: $selectedTab) {
                Text("Summary").tag(0)
                Text("Calendar").tag(1)
                Text("Fueling").tag(2)
                Text("Conditions").tag(3)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Content
            TabView(selection: $selectedTab) {
                RaceStrategySummaryView()
                    .tag(0)
                
                RaceStrategyCalendarView()
                    .tag(1)
                
                RaceStrategyFuelingView()
                    .tag(2)
                
                RaceDayConditionsView()
                    .tag(3)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
    }
}

#Preview {
    OnboardingFlowView()
}
