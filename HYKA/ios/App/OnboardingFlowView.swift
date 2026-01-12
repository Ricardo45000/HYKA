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
    @State private var isUploadingGPX = false
    @State private var gpxFileName: String? = nil
    @State private var gpxFileData: Data? = nil
    
    private let totalSteps = 8
    
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
                            
                            ConnectDevicesView(onNext: nextStep, onSkip: {}, onBack: previousStep)
                                .tag(4)
                            
                            UploadGPXView(
                                onNext: nextStep,
                                onSkip: nextStep,
                                onGPXImported: { fileName, fileData, distance in
                                    gpxFileName = fileName
                                    gpxFileData = fileData
                                    // Update raceDetails.distance with GPX distance for validation
                                    raceDetails = RaceDetails(
                                        name: raceDetails.name,
                                        date: raceDetails.date,
                                        startTime: raceDetails.startTime,
                                        distance: distance, // Use GPX distance
                                        elevation: raceDetails.elevation,
                                        difficulty: raceDetails.difficulty
                                    )
                                    updateFinishDistance(distance)
                                    isUploadingGPX = false
                                },
                                onUploadStatusChange: { isUploadingGPX = $0 },
                                isContinueDisabled: isUploadingGPX
                            )
                                .tag(5)
                            
                            RaceDetailsView(
                                raceDetails: $raceDetails,
                                onNext: nextStep,
                                onBack: previousStep
                            )
                                .tag(6)
                            
                            AidStationsView(
                                aidStations: $aidStations,
                                raceDistance: raceDetails.distance,
                                onNext: nextStep,
                                onBack: previousStep
                            )
                                .tag(7)
                            
                            StrategyPreferencesView(
                                preferences: $strategyPreferences,
                                onGenerate: generateStrategy,
                                onBack: previousStep
                            )
                                .tag(8)
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
                    
                    HYKALoadingCard(
                        message: "Saving your data...",
                        backgroundColor: Color.hykaPurple
                    )
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85, blendDuration: 0), value: currentStep)
            .animation(.easeInOut(duration: 0.35), value: showStrategyResults)
            .animation(.easeInOut(duration: 0.25), value: isSavingData)
            // Note: ErrorDisplay is applied at root level (MainApp), not here to avoid duplicate overlays
            .keyboardDoneToolbar() // Apply to ZStack (NavigationView's direct content) to ensure only one toolbar
        }
        .onAppear {
            // Pre-fill user profile from OAuth data if available
            if let oauthInfo = session.oauthUserInfo {
                if let firstName = oauthInfo.firstName, !firstName.isEmpty {
                    userProfile.firstName = firstName
                }
                if let lastName = oauthInfo.lastName, !lastName.isEmpty {
                    userProfile.lastName = lastName
                }
                if let gender = oauthInfo.gender {
                    userProfile.gender = gender
                }
                print("✅ Pre-filled userProfile from OAuth: firstName=\(userProfile.firstName), lastName=\(userProfile.lastName), gender=\(userProfile.gender.rawValue)")
            }
        }
    }
    
    private var currentStepTitle: String {
        switch currentStep {
        case 1: return "Tell us who you are"
        case 2: return "Tell us who you are"
        case 3: return "Your running profile"
        case 4: return "Connect your devices"
        case 5: return "Upload your race course"
        case 6: return "Tell us about your race"
        case 7: return "Aid Stations"
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
        
        // Only auto-add Start/Finish if user hasn't added any stations yet
        // If user has already added stations, only update existing Finish station distance, don't add new ones
        if updatedStations.isEmpty {
            // User hasn't added any stations - add default Start and Finish
            updatedStations = [
                AidStation(name: "Start", distance: 0, services: []),
                AidStation(name: "Finish", distance: distanceKm, services: [])
            ]
        } else {
            // User has already added stations - only update Finish distance if it exists
            // Don't add new Start/Finish stations to avoid duplicates
            if let finishIndex = updatedStations.lastIndex(where: { $0.name.lowercased() == "finish" }) {
                let finish = updatedStations[finishIndex]
                updatedStations[finishIndex] = AidStation(name: finish.name, distance: distanceKm, services: finish.services)
            }
            // If no Finish station exists and user has stations, don't auto-add one - let user add it manually
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
                print("❌ No user ID available - isAuthenticated: \(session.isAuthenticated), currentUser: \(String(describing: session.currentUser?.id))")
                ErrorManager.shared.showError(title: "Authentication Required", message: "User not authenticated. Please sign in again.")
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
                
                // 2b. Save race date to database (same as RaceCreationFlowView)
                try await SupabaseService.updateRacePlanDate(racePlanId: racePlanId, raceDate: raceDetails.date)
                print("✅ Race date saved to database: \(raceDetails.date)")
                
                // 3. Save GPX file if one was uploaded
                if let fileName = gpxFileName, let fileData = gpxFileData {
                    _ = try await SupabaseService.saveGPXFile(
                        userId: userId,
                        racePlanId: racePlanId,
                        fileName: fileName,
                        fileData: fileData
                    )
                    print("✅ GPX file saved to database")
                }
                
                print("✅ All onboarding data saved successfully. Race plan ID: \(racePlanId)")
                
                // 4. Ensure default fuel types exist
                do {
                    try await SupabaseService.ensureDefaultFuelTypes(userId: userId)
                    print("✅ Default fuel types ensured")
                } catch {
                    print("⚠️ Failed to ensure default fuel types: \(error)")
                    // Don't block onboarding completion if this fails
                }
                
                // 5. Mark onboarding as complete
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
                
                // Show user-friendly error using ErrorManager
                ErrorManager.shared.showError(error, title: "Failed to Save Data")
                print("❌ Error saving onboarding data: \(error)")
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
