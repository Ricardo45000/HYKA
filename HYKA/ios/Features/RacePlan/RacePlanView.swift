import SwiftUI
import Auth
import PDFKit
import UIKit
import Supabase
import PostgREST

// MARK: - Supporting Models

struct PacingSegment: Identifiable {
    let id = UUID()
    let from: String
    let to: String
    let fromDistance: Double
    let toDistance: Double
    let segmentDistance: Double
    let duration: String
    let effortLevel: EffortLevel
    let effortBars: [EffortBar]
    let heartRate: String
    let effortLabel: String
    let estimatedPace: String
    let elevationGain: Int
    let elevationLoss: Int
    
    var borderColor: Color {
        switch effortLevel {
        case .conservative: return .green
        case .build: return .blue
        case .moderate: return .orange
        case .hard: return .red
        }
    }
    
    enum EffortLevel {
        case conservative
        case build
        case moderate
        case hard
    }
    
    enum EffortBar {
        case green
        case orange
        case grey
        
        var color: Color {
            switch self {
            case .green: return .green
            case .orange: return .orange
            case .grey: return Color.gray.opacity(0.3)
            }
        }
    }
}

struct FuelingStation {
    let name: String
    let time: String
    let elapsed: String
    let carbs: Int
    let sodium: Int
    let water: Int
    let recommendations: [String]
    let hydrationNote: String
}

struct AthleteAnalytics {
    let averageHeartRate: Double?
    let maxHeartRate: Double?
    let basePaceMinutesPerKilometer: Double?
    let fatigueRatePerHour: Double
    let caloriesPerHour: Double
    let weightKg: Double?
}

private struct SectionPlan {
    let pacingSegment: PacingSegment
    let sectionHours: Double
}

private extension Array where Element == Double {
    func averageValue() -> Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}

struct RacePlanView: View {
    @EnvironmentObject var session: SessionManager
    @State private var selectedTab = 0 // 0 = Calendar, 1 = Conditions
    @State private var raceDetails: RaceDetails?
    @State private var racePlanId: UUID?
    @State private var isLoading = false
    @State private var aidStations: [AidStation] = []
    @State private var showEditAidStations = false
    @State private var fuelTypes: [FuelType] = []
    @State private var showEditFuelTypeReference = false
    @State private var pacingSegments: [PacingSegment] = []
    @State private var fuelingStations: [FuelingStation] = []
    @State private var weatherLocation: String = "Dublin, Ireland"
    @State private var weatherCoordinates: WeatherCoordinates?
    @State private var showLocationPicker = false
    @State private var weatherData: WeatherData?
    @State private var isLoadingWeather = false
    @State private var racePlans: [RacePlanSummary] = []
    @State private var selectedRace: RacePlanSummary?
    @State private var isProcessingGPX = false
    @State private var trackPoints: [TrackPoint] = []
    @State private var aidStationMetrics: [Int: AidStationSegmentMetrics] = [:]
    @State private var showRaceCreation = false
    @State private var raceMetadata: RacePlanMetadata?
    private let defaultPaceSecondsPerKm = 300
    @State private var raceToDelete: RacePlanSummary?
    @State private var isDeletingRace = false
    @State private var athleteAnalytics: AthleteAnalytics?
    @State private var showEditRaceModal = false
    @State private var editingRaceName = ""
    @State private var editingRaceDate = Date()
    @State private var connectedProvider: String?
    @State private var pdfURL: URL?
    @State private var showShareSheet = false
    @State private var isSyncingDevice = false
    
    // Fuel Type Model
    struct FuelType: Identifiable {
        let id: UUID
        var name: String
        var category: String
        var carbs: Int
        var sodium: Int
        var isCustom: Bool // To distinguish between default and custom fuel types
    }
    
    // Weather Data Model
    struct WeatherData {
        let temperature: String
        let conditions: String
        let wind: String
        let humidity: String
    }

    var body: some View {
        ZStack {
            HYKATheme.Light.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    raceSelectorSection
                    
                    if let currentRace = selectedRace {
                        // Header Section
                        VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                    HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Your Race Strategy")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(HYKATheme.Light.foreground)
                                    
                                    Text("Personalized plan for \(currentRace.title)")
                                        .font(.system(size: 15, weight: .regular))
                                        .foregroundColor(HYKATheme.Light.mutedForeground)
                                }
                                
                        Spacer()
                                
                                // Edit pencil icon
                                Button {
                                    editingRaceName = selectedRace?.title ?? ""
                                    editingRaceDate = raceMetadata?.raceDate ?? Date()
                                    showEditRaceModal = true
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color.hykaPurple)
                                            .frame(width: 32, height: 32)
                                        
                                        Image(systemName: "pencil")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .padding(.horizontal, HYKATheme.spacingXXL)
                            .padding(.top, HYKATheme.spacingL)
                            .padding(.bottom, HYKATheme.spacingM)
                        }
                        
                        // Race Details Card
                        VStack(spacing: HYKATheme.spacingM) {
                    HStack {
                                Text(currentRace.title)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(HYKATheme.Light.foreground)
                        Spacer()
                            }
                            
                            // 2x2 Grid Layout with icons outside - aligned vertically
                            HStack(alignment: .top, spacing: HYKATheme.spacingL) {
                                // Left Column
                                VStack(alignment: .leading, spacing: HYKATheme.spacingL) {
                                    // Race Date
                                    HStack(alignment: .top, spacing: HYKATheme.spacingS) {
                                        Image(systemName: "calendar")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color.hykaPurple)
                                            .frame(width: 16, height: 16)
                                            .fixedSize()
                                        
                                        VStack(alignment: .leading, spacing: HYKATheme.spacingXS) {
                                            Text("Race Date")
                                                .font(.system(size: 12, weight: .regular))
                                                .foregroundColor(HYKATheme.Light.mutedForeground)
                                            Text(formattedMetadataDate())
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(HYKATheme.Light.foreground)
                                        }
                                    }
                                    
                                    // Elevation Gain
                                    HStack(alignment: .top, spacing: HYKATheme.spacingS) {
                                        Image(systemName: "mountain.2.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color.hykaPurple)
                                            .frame(width: 16, height: 16)
                                            .fixedSize()
                                        
                                        VStack(alignment: .leading, spacing: HYKATheme.spacingXS) {
                                            Text("Elevation Gain")
                                                .font(.system(size: 12, weight: .regular))
                                                .foregroundColor(HYKATheme.Light.mutedForeground)
                                            Text(formattedMetadataElevation())
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(HYKATheme.Light.foreground)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Right Column
                                VStack(alignment: .leading, spacing: HYKATheme.spacingL) {
                                    // Distance
                                    HStack(alignment: .top, spacing: HYKATheme.spacingS) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color.hykaPurple)
                                            .frame(width: 16, height: 16)
                                            .fixedSize()
                                        
                                        VStack(alignment: .leading, spacing: HYKATheme.spacingXS) {
                                            Text("Distance")
                                                .font(.system(size: 12, weight: .regular))
                                                .foregroundColor(HYKATheme.Light.mutedForeground)
                                            Text(formattedRaceDistance())
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(HYKATheme.Light.foreground)
                                        }
                                    }
                                    
                                    // Est. Time
                                    HStack(alignment: .top, spacing: HYKATheme.spacingS) {
                                        Image(systemName: "clock.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color.hykaPurple)
                                            .frame(width: 16, height: 16)
                                            .fixedSize()
                                        
                                        VStack(alignment: .leading, spacing: HYKATheme.spacingXS) {
                                            Text("Est. Time")
                                                .font(.system(size: 12, weight: .regular))
                                                .foregroundColor(HYKATheme.Light.mutedForeground)
                                            Text(formattedEstimatedDuration())
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(HYKATheme.Light.foreground)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.top, HYKATheme.spacingS)
                            
                            if let notes = raceMetadata?.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                                VStack(alignment: .leading, spacing: HYKATheme.spacingXS) {
                                    Text("Race Notes")
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(HYKATheme.Light.mutedForeground)
                                    Text(notes)
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(HYKATheme.Light.foreground)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, HYKATheme.spacingS)
                            }
                            
                            // Download and Sync buttons
                            VStack(spacing: HYKATheme.spacingS) {
                                Text("Download your strategy or connect to \(connectedProvider?.capitalized ?? "your device") for real-time guidance on race day.")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(HYKATheme.Light.mutedForeground)
                                    .multilineTextAlignment(.center)
                                
                                HStack(spacing: HYKATheme.spacingM) {
                                    Button {
                                        Task {
                                            await generateRaceStrategyPDF()
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: "arrow.down.circle.fill")
                                                .font(.system(size: 14, weight: .semibold))
                                            Text("Download")
                                                .font(.system(size: 12, weight: .semibold))
                                                .lineLimit(1)
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 40)
                                        .background(Color.hykaPurple)
                                        .cornerRadius(HYKATheme.cornerRadiusM)
                                    }
                                    
                                    // Sync with device button - triggers historical backfill
                                    Button {
                                        Task {
                                            await syncWithDevice()
                                        }
                                    } label: {
                                        HStack {
                                            if isSyncingDevice {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    .scaleEffect(0.8)
                                            } else {
                                                Image(systemName: "arrow.triangle.2.circlepath")
                                                    .font(.system(size: 14, weight: .semibold))
                                            }
                                            Text(isSyncingDevice ? "Syncing..." : "Sync with \(connectedProvider?.capitalized ?? "Device")")
                                                .font(.system(size: 12, weight: .semibold))
                                                .lineLimit(1)
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 40)
                                        .background(isSyncingDevice ? Color.gray : Color.hykaPurple)
                                        .cornerRadius(HYKATheme.cornerRadiusM)
                                    }
                                    .disabled(isSyncingDevice || connectedProvider == nil)
                                }
                            }
                            .padding(.top, HYKATheme.spacingM)
                        }
                        .padding(HYKATheme.spacingXXL)
                        .background(Color.hykaPurple.opacity(0.05))
                        .cornerRadius(HYKATheme.cornerRadiusL)
                        .overlay(
                            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusL)
                                .stroke(Color.hykaPurple.opacity(0.3), lineWidth: 2)
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
                        .padding(.horizontal, HYKATheme.spacingXXL)
                        .padding(.bottom, HYKATheme.spacingL)
                        
                        // Segmented Control
                        Picker("View Type", selection: $selectedTab) {
                            Text("Race Plan")
                                .font(.system(size: 15, weight: .medium))
                                .tag(0)
                            
                            Text("Conditions")
                                .font(.system(size: 15, weight: .medium))
                                .tag(1)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .onAppear {
                            UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.black], for: .normal)
                            UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
                            UISegmentedControl.appearance().selectedSegmentTintColor = .white
                            UISegmentedControl.appearance().backgroundColor = .lightGray
                        }
                        .padding(.horizontal, HYKATheme.spacingXXL)
                        .padding(.bottom, HYKATheme.spacingL)
                        
                        // Content based on selected tab
                        if selectedTab == 0 {
                            calendarView
                        } else {
                            conditionsView
                        }
                    } else {
                        emptyRaceDetails
                            .padding(.horizontal, HYKATheme.spacingXXL)
                            .padding(.top, HYKATheme.spacingXL)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .task {
            await loadRacePlans()
            await fetchConnectedProvider()
        }
        .sheet(isPresented: $showRaceCreation) {
            RaceCreationFlowView { newRaceId, metadata in
                Task {
                    await MainActor.run {
                        raceMetadata = metadata
                        isProcessingGPX = true
                    }
                    RacePlanMetadataStore.save(metadata, for: newRaceId)
                    await loadRacePlans(selecting: newRaceId, forceRefresh: true)
                    await MainActor.run {
                        isProcessingGPX = false
                        showRaceCreation = false
                    }
                }
            }
            .environmentObject(session)
        }
        .sheet(isPresented: $showEditAidStations) {
            EditAidStationsModal(
                aidStations: $aidStations,
                onSave: {
                    Task {
                        await saveAidStations()
                    }
                    showEditAidStations = false
                }
            )
        }
        .sheet(isPresented: $showEditFuelTypeReference) {
            EditFuelTypeReferenceModal(
                fuelTypes: $fuelTypes,
                onSave: {
                    showEditFuelTypeReference = false
                }
            )
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerModal(
                location: $weatherLocation,
                onSave: {
                    showLocationPicker = false
                    Task {
                        await fetchWeather(location: weatherLocation)
                        // Save location to race plan if we have one
                        if let racePlanId = racePlanId {
                            await saveLocationToRacePlan(racePlanId: racePlanId, location: weatherLocation)
                        }
                    }
                },
                onCancel: {
                    showLocationPicker = false
                }
            )
        }
        .sheet(isPresented: $showEditRaceModal) {
            EditRaceModal(
                raceName: $editingRaceName,
                raceDate: $editingRaceDate,
                onSave: {
                    Task {
                        await saveRaceNameAndDate()
                        showEditRaceModal = false
                    }
                },
                onCancel: {
                    showEditRaceModal = false
                }
            )
        }
        .confirmationDialog(
            "Delete this race?",
            isPresented: Binding(
                get: { raceToDelete != nil },
                set: { if !$0 { raceToDelete = nil } }
            ),
            presenting: raceToDelete
        ) { plan in
            Button("Delete", role: .destructive) {
                raceToDelete = nil
                Task { await deleteRacePlan(plan) }
            }
            Button("Cancel", role: .cancel) { raceToDelete = nil }
        } message: { plan in
            Text("This will remove \(plan.title) and its associated data.")
        }
        .sheet(isPresented: $showShareSheet) {
            if let pdfURL = pdfURL {
                ShareSheet(items: [pdfURL])
            }
        }
        .overlay(alignment: .center) {
            if isLoading || isDeletingRace {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                VStack(spacing: HYKATheme.spacingM) {
                    ProgressView()
                    Text(isDeletingRace ? "Deleting race…" : "Fetching race data…")
                        .font(HYKATheme.body)
                        .foregroundColor(.white)
                }
                .padding(HYKATheme.spacingXXL)
                .background(Color.hykaPurple)
                .cornerRadius(HYKATheme.cornerRadiusL)
            }
        }
    }
    
    // MARK: - Race Selection
    
    private var raceSelectorSection: some View {
        VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
            HStack(alignment: .center, spacing: HYKATheme.spacingM) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your races")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(HYKATheme.Light.foreground)
                    
                    Text("Import GPX files to build personalized race strategies.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(HYKATheme.Light.mutedForeground)
                }
                
                Spacer()
                
                if isProcessingGPX {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.hykaPurple))
                        .padding(.trailing, HYKATheme.spacingM)
                }
                
                Button {
                    showRaceCreation = true
                } label: {
                    Label("Add race", systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, HYKATheme.spacingM)
                        .padding(.vertical, HYKATheme.spacingS)
                        .background(Color.hykaPurple)
                        .foregroundColor(.white)
                        .cornerRadius(HYKATheme.cornerRadiusM)
                }
                .disabled(isProcessingGPX)
            }
            
            if racePlans.isEmpty {
                emptyRaceListState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: HYKATheme.spacingM) {
                        ForEach(racePlans) { plan in
                            raceCardItem(for: plan)
                        }
                    }
                    .padding(.vertical, HYKATheme.spacingS)
                }
            }
        }
        .padding(.horizontal, HYKATheme.spacingXXL)
        .padding(.vertical, HYKATheme.spacingXL)
    }
    
    private var emptyRaceListState: some View {
        VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
            Text("No races yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(HYKATheme.Light.foreground)
            
            Text("Tap 'Add race' to import a GPX file and generate your first race strategy.")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(HYKATheme.Light.mutedForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(HYKATheme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                .fill(HYKATheme.Light.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                .stroke(HYKATheme.Light.border, lineWidth: 1)
        )
    }
    
    private var emptyRaceDetails: some View {
        VStack(spacing: HYKATheme.spacingM) {
            Image(systemName: "map")
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(Color.hykaPurple)
            
            if racePlans.isEmpty {
                Text("Import a GPX file to create your first race plan.")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(HYKATheme.Light.foreground)
            } else {
                Text("Select a race from your list to view its strategy.")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(HYKATheme.Light.foreground)
            }
            
            Button {
                showRaceCreation = true
            } label: {
                Label("Import GPX", systemImage: "square.and.arrow.down")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, HYKATheme.spacingL)
                    .padding(.vertical, HYKATheme.spacingS)
                    .background(Color.hykaPurple)
                    .foregroundColor(.white)
                    .cornerRadius(HYKATheme.cornerRadiusM)
            }
            .disabled(isProcessingGPX)
        }
        .frame(maxWidth: .infinity)
        .padding(HYKATheme.spacingXXL)
    }
    
    @ViewBuilder
    private func raceCardItem(for plan: RacePlanSummary) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                if selectedRace?.id != plan.id {
                    Task { await selectRace(plan) }
                }
            } label: {
                raceCard(for: plan, isSelected: selectedRace?.id == plan.id)
            }
            .buttonStyle(PlainButtonStyle())
            
            Button {
                raceToDelete = plan
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.red.opacity(0.85))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .padding(8)
        }
    }
    
    private func raceCard(for plan: RacePlanSummary, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: HYKATheme.spacingXS) {
            Text(plan.title.isEmpty ? "Untitled Race" : plan.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isSelected ? .white : HYKATheme.Light.foreground)
                .lineLimit(1)
            
            Text(formattedRaceDate(plan.createdAt))
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(isSelected ? .white.opacity(0.85) : HYKATheme.Light.mutedForeground)
        }
        .padding(HYKATheme.spacingM)
        .frame(width: 160, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                .fill(isSelected ? Color.hykaPurple : HYKATheme.Light.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                .stroke(isSelected ? Color.hykaPurple : HYKATheme.Light.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isSelected ? 0.15 : 0.05), radius: isSelected ? 8 : 4, x: 0, y: 3)
    }
    
    private func formattedRaceDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formattedMetadataDate() -> String {
        guard let date = raceMetadata?.raceDate else { return "—" }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formattedMetadataElevation() -> String {
        let totalGain: Int
        if let gain = raceMetadata?.elevationGain {
            totalGain = gain
        } else if !trackPoints.isEmpty {
            // Calculate cumulative elevation gain from all track points
            var cumulativeGain: Double = 0
            for i in 1..<trackPoints.count {
                let delta = trackPoints[i].ele - trackPoints[i - 1].ele
                if delta > 0 {
                    cumulativeGain += delta
                }
            }
            totalGain = Int(round(cumulativeGain))
        } else {
            let aggregate = aidStationMetrics.values.reduce(0.0) { $0 + $1.elevationGainM }
            totalGain = Int(round(aggregate))
        }
        guard totalGain > 0 else { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let value = formatter.string(from: NSNumber(value: totalGain)) ?? "\(totalGain)"
        return "\(value)m"
    }
    
    // MARK: - Calendar View
    
    private var calendarView: some View {
        VStack(alignment: .leading, spacing: HYKATheme.spacingXL) {
            // Your Race Calendar Card - Contains all sections
            VStack(alignment: .leading, spacing: HYKATheme.spacingXL) {
                // Title and Subtitle
                VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                    Text("Your Race Calendar")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(HYKATheme.Light.foreground)
                    
                    Text("Comprehensive pacing and nutrition strategy for each section")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(HYKATheme.Light.mutedForeground)
                }
                
                // Pacing and Fueling Cards
                ForEach(Array(pacingSegments.enumerated()), id: \.element.id) { index, segment in
                    VStack(spacing: HYKATheme.spacingL) {
                        // Pacing Card
                        pacingCard(segment: segment)
                        
                        // Fueling Card (if available for this segment)
                        if index < fuelingStations.count {
                            fuelingCard(station: fuelingStations[index])
                        }
                    }
                    .padding(.top, index == 0 ? 0 : HYKATheme.spacingXL)
                }
                
                // Pacing Tips and Nutrition Tips Cards
                VStack(spacing: HYKATheme.spacingM) {
                    pacingTipsCard
                    nutritionTipsCard
                }
                .padding(.top, HYKATheme.spacingL)
                
                // Aid Stations Section
                aidStationsSection
                    .padding(.top, HYKATheme.spacingXL)
                
                // Fuel Type Reference Section
                fuelTypeReferenceSection
                    .padding(.top, HYKATheme.spacingXL)
            }
            .padding(HYKATheme.spacingXXL)
            .background(HYKATheme.Light.card)
            .cornerRadius(HYKATheme.cornerRadiusL)
            .overlay(
                RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusL)
                    .stroke(HYKATheme.Light.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
            .padding(.horizontal, HYKATheme.spacingXXL)
        }
        .padding(.top, HYKATheme.spacingL)
            .onChange(of: weatherData?.temperature) { _ in
                Task { @MainActor in
                    recalculateStrategy()
                }
            }
    }
    
    private func pacingCard(segment: PacingSegment) -> some View {
        VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
            HStack {
                // Elevation icon
                ZStack {
                    Circle()
                        .fill(segment.borderColor.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(segment.borderColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Pacing: \(segment.from) → \(segment.to)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(HYKATheme.Light.foreground)
                        
                        Spacer()
                        
                        Button {
                            // Info action
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14))
                                .foregroundColor(HYKATheme.Light.mutedForeground)
                        }
                    }
                    
                    Text("\(String(format: "%.0f", segment.fromDistance))K - \(String(format: "%.0f", segment.toDistance))K (\(String(format: "%.1f", segment.segmentDistance))K) • \(segment.duration)")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(HYKATheme.Light.mutedForeground)
                }
            }
            
            // Effort indicator bars
            HStack(spacing: 4) {
                ForEach(Array(segment.effortBars.enumerated()), id: \.offset) { _, barType in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barType.color)
                        .frame(height: 8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HYKATheme.spacingXS)
            
            // Heart rate and effort label
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(segment.heartRate)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(segment.borderColor)
                    
                    Text(segment.effortLabel)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(HYKATheme.Light.mutedForeground)
                }
            }
            
            // Separator
            Divider()
                .background(HYKATheme.Light.border)
                .padding(.vertical, HYKATheme.spacingS)
            
            // Metrics row
            HStack(spacing: HYKATheme.spacingXL) {
                // Est. Pace
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(HYKATheme.Light.mutedForeground)
                        Text("Est. Pace")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(HYKATheme.Light.mutedForeground)
                    }
                    Text(segment.estimatedPace)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(HYKATheme.Light.foreground)
                }
                
                Spacer()
                
                // Gain
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                        Text("Gain")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(HYKATheme.Light.mutedForeground)
                    }
                    Text("+\(segment.elevationGain)m")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(HYKATheme.Light.foreground)
                }
                
                Spacer()
                
                // Loss
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.right")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                        Text("Loss")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(HYKATheme.Light.mutedForeground)
                    }
                    Text("-\(segment.elevationLoss)m")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(HYKATheme.Light.foreground)
                }
            }
            .padding(.top, HYKATheme.spacingS)
        }
        .padding(HYKATheme.spacingXXL)
        .background(segment.borderColor.opacity(0.1))
        .cornerRadius(HYKATheme.cornerRadiusL)
        .overlay(
            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusL)
                .stroke(segment.borderColor, lineWidth: 2)
        )
    }
    
    private func fuelingCard(station: FuelingStation) -> some View {
        VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
            HStack {
                // Pin icon
                ZStack {
                    Circle()
                        .fill(Color.hykaPurple.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    ZStack {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color.hykaPurple)
                        
                        Text("ψq")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .offset(y: 2)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Fueling at \(station.name)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(HYKATheme.Light.foreground)
                        
                        Spacer()
                        
                        Button {
                            // Info action
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14))
                                .foregroundColor(HYKATheme.Light.mutedForeground)
                        }
                    }
                    
                    HStack(spacing: HYKATheme.spacingL) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                            Text(station.time)
                                .font(.system(size: 13, weight: .regular))
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "stopwatch")
                                .font(.system(size: 12))
                            Text(station.elapsed)
                                .font(.system(size: 13, weight: .regular))
                        }
                    }
                    .foregroundColor(HYKATheme.Light.mutedForeground)
                }
            }
            
            // Nutrients
            HStack(spacing: HYKATheme.spacingXL) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Carbs")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(HYKATheme.Light.mutedForeground)
                    Text("\(station.carbs)g")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color.hykaPurple)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sodium")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(HYKATheme.Light.mutedForeground)
                    Text("\(station.sodium)mg")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Water")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(HYKATheme.Light.mutedForeground)
                    Text("\(station.water)ml")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.blue)
                }
            }
            .padding(.top, HYKATheme.spacingS)
            
            // Separator
            Divider()
                .background(HYKATheme.Light.border)
                .padding(.vertical, HYKATheme.spacingS)
            
            // Recommended Fueling
            VStack(alignment: .leading, spacing: HYKATheme.spacingXS) {
                Text("Recommended Fueling:")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.hykaPurple)
                
                ForEach(station.recommendations, id: \.self) { rec in
                    Text("• \(rec)")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(HYKATheme.Light.foreground)
                }
            }
            .padding(.top, HYKATheme.spacingS)
            
            // Hydration Plan
            VStack(alignment: .leading, spacing: HYKATheme.spacingXS) {
                Text("Hydration Plan:")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.blue)
                
                Text(station.hydrationNote)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(HYKATheme.Light.foreground)
            }
            .padding(.top, HYKATheme.spacingS)
        }
        .padding(HYKATheme.spacingXXL)
        .background(Color.hykaPurple.opacity(0.1))
        .cornerRadius(HYKATheme.cornerRadiusL)
        .overlay(
            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusL)
                .stroke(Color.hykaPurple, lineWidth: 2)
        )
    }
    
    // MARK: - Pacing Tips Card
    
    private var pacingTipsCard: some View {
        VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.blue)
                }
                
                Text("Pacing Tips")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(HYKATheme.Light.foreground)
            }
            
            VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                HStack(alignment: .top, spacing: HYKATheme.spacingS) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                        .padding(.top, 2)
                    Text("Start slower than you think - the first 25% sets up your entire race")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(HYKATheme.Light.foreground)
                }
                
                HStack(alignment: .top, spacing: HYKATheme.spacingS) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                        .padding(.top, 2)
                    Text("Walk the uphills strategically to conserve energy")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(HYKATheme.Light.foreground)
                }
                
                HStack(alignment: .top, spacing: HYKATheme.spacingS) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                        .padding(.top, 2)
                    Text("Monitor your effort level, not just pace on varied terrain")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(HYKATheme.Light.foreground)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(HYKATheme.spacingXXL)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(HYKATheme.cornerRadiusL)
        .overlay(
            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusL)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Nutrition Tips Card
    
    private var nutritionTipsCard: some View {
        VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "fork.knife")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.orange)
                }
                
                Text("Nutrition Tips")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(HYKATheme.Light.foreground)
            }
            
            VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                HStack(alignment: .top, spacing: HYKATheme.spacingS) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                        .padding(.top, 2)
                    Text("Test all nutrition during training - never try anything new on race day")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(HYKATheme.Light.foreground)
                }
                
                HStack(alignment: .top, spacing: HYKATheme.spacingS) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                        .padding(.top, 2)
                    Text("Eat before you're hungry - stay ahead of your calorie deficit")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(HYKATheme.Light.foreground)
                }
                
                HStack(alignment: .top, spacing: HYKATheme.spacingS) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                        .padding(.top, 2)
                    Text("Bring extra calories - it's better to have too much than too little")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(HYKATheme.Light.foreground)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(HYKATheme.spacingXXL)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(HYKATheme.cornerRadiusL)
        .overlay(
            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusL)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Aid Stations Section
    
    private var aidStationsSection: some View {
        VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
            HStack {
                Text("Aid Stations & Services")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(HYKATheme.Light.foreground)
                
                Spacer()
                
                Button {
                    showEditAidStations = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.hykaPurple.opacity(0.3))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundColor(Color.hykaPurple)
                    }
                }
            }
            
            VStack(spacing: HYKATheme.spacingS) {
                let orderedStations = aidStations.sorted { $0.distance < $1.distance }
                ForEach(Array(orderedStations.enumerated()), id: \.element.id) { index, station in
                    HStack(alignment: .top, spacing: HYKATheme.spacingM) {
                        ZStack {
                            Circle()
                                .fill(Color.hykaPurple.opacity(0.12))
                                .frame(width: 40, height: 40)
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color.hykaPurple)
                        }
                        
                        VStack(alignment: .leading, spacing: HYKATheme.spacingXS) {
                            HStack {
                                Text(station.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(HYKATheme.Light.foreground)
                                Spacer()
                                Text("\(String(format: "%.0f", station.distance))K")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(HYKATheme.Light.mutedForeground)
                            }
                            
                            let activeServices = station.services.filter { $0.isAvailable }
                            if !activeServices.isEmpty {
                                HStack(alignment: .center, spacing: HYKATheme.spacingS * 0.5) {
                                    ForEach(activeServices, id: \.type.rawValue) { service in
                                        aidStationServiceBadge(for: service.type)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(HYKATheme.spacingM)
                    .background(HYKATheme.Light.card)
                    .cornerRadius(HYKATheme.cornerRadiusM)
                }
            }
        }
    }
    
    private func aidStationServiceBadge(for type: AidService.ServiceType) -> some View {
        let color = aidStationServiceColor(for: type)
        return HStack(spacing: 4) {
            Image(systemName: type.icon)
                .font(.system(size: 10, weight: .semibold))
            Text(type.rawValue)
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(color)
        .background(
            Capsule()
                .fill(color.opacity(0.18))
        )
        .overlay(
            Capsule()
                .stroke(color.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.12), radius: 3, x: 0, y: 1)
    }
    
    private func aidStationServiceColor(for type: AidService.ServiceType) -> Color {
        switch type {
        case .hydration: return Color.blue
        case .gels: return Color.purple
        case .food: return Color.green
        case .crew: return Color.orange
        }
    }
    
    private func metricChip(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(HYKATheme.Light.mutedForeground)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(HYKATheme.Light.foreground)
        }
        .padding(.horizontal, HYKATheme.spacingM)
        .padding(.vertical, HYKATheme.spacingS)
        .background(HYKATheme.Light.inputBackground)
        .cornerRadius(HYKATheme.cornerRadiusS)
    }
    
    private func formattedDuration(seconds: Double) -> String {
        guard seconds > 0 else { return "—" }
        let totalMinutes = Int(round(seconds / 60.0))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h\(String(format: "%02d", minutes))m"
        } else {
            return "\(minutes)m"
        }
    }
    
    // MARK: - Fuel Type Reference Section
    
    private var fuelTypeReferenceSection: some View {
        VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
            HStack {
                Text("Fuel Type Reference")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(HYKATheme.Light.foreground)
                
                Spacer()
                
                Button {
                    showEditFuelTypeReference = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.hykaPurple.opacity(0.3))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundColor(Color.hykaPurple)
                    }
                }
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: HYKATheme.spacingM) {
                ForEach(fuelTypes) { fuel in
                    fuelTypeCard(name: fuel.name, type: fuel.category, carbs: fuel.carbs, sodium: fuel.sodium)
                }
            }
        }
    }
    
    private func fuelTypeCard(name: String, type: String, carbs: Int, sodium: Int) -> some View {
        VStack(spacing: HYKATheme.spacingS) {
            // Title - centered, 2 lines
            Text(name)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(HYKATheme.Light.foreground)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
            
            // Subtitle - centered
            Text(type)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color.hykaPurple)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            
            // 2x2 Grid for carbs and sodium
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: HYKATheme.spacingXS) {
                // 50g
                Text("\(carbs)g")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(HYKATheme.Light.foreground)
                
                // carbs
                Text("carbs")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(HYKATheme.Light.foreground)
                
                // 200mg
                Text("\(sodium)mg")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.orange)
                
                // Na
                Text("Na")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(HYKATheme.Light.foreground)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(HYKATheme.spacingM)
        .background(Color.hykaPurple.opacity(0.05))
        .cornerRadius(HYKATheme.cornerRadiusM)
        .overlay(
            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                .stroke(Color.hykaPurple.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Pre-Race Preparation Section
    
    private var preRacePreparationSection: some View {
        VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
            Text("Pre-Race Preparation")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(HYKATheme.Light.foreground)
            
            VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
                preRaceItem(title: "3 Days Before", description: "Taper training, increase carbs, stay hydrated")
                preRaceItem(title: "Night Before", description: "Lay out all gear, familiar carb-rich dinner, early to bed")
                preRaceItem(title: "Race Morning", description: "Eat 2-3 hours before start, coffee if you normally drink it")
                preRaceItem(title: "At Start Line", description: "Stay warm, light warm-up, positive mindset")
            }
        }
        .padding(HYKATheme.spacingXXL)
        .background(Color.green.opacity(0.1))
        .cornerRadius(HYKATheme.cornerRadiusL)
        .overlay(
            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusL)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func preRaceItem(title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: HYKATheme.spacingM) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(HYKATheme.Light.foreground)
                
                Text(description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(HYKATheme.Light.mutedForeground)
            }
        }
    }
    
    // MARK: - Conditions View
    
    private var conditionsView: some View {
        VStack(alignment: .leading, spacing: HYKATheme.spacingXL) {
            // Race Day Conditions Card - Contains all sections
            VStack(alignment: .leading, spacing: HYKATheme.spacingXL) {
                // Title and Subtitle
                VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                    Text("Race Day Conditions")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(HYKATheme.Light.foreground)
                    
                    Text("Weather forecast and terrain conditions for race day")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(HYKATheme.Light.mutedForeground)
                }
                
                // Weather Forecast Section
                VStack(alignment: .leading, spacing: HYKATheme.spacingL) {
                    // Header with Weather Forecast title
                    HStack(spacing: HYKATheme.spacingS) {
                        Image(systemName: "cloud.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.blue)
                        
                        Text("Weather Forecast")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(HYKATheme.Light.foreground)
                    }
                    
                    // Location subtitle (clickable)
                    Button(action: {
                        showLocationPicker = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                            Text("Location:")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(HYKATheme.Light.mutedForeground)
                            Text(weatherLocation)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(HYKATheme.Light.mutedForeground)
                            Image(systemName: "pencil")
                                .font(.system(size: 12))
                                .foregroundColor(.blue.opacity(0.7))
                        }
                    }
                    .padding(.top, -HYKATheme.spacingS)
                    
                    // Weather details grid - 2x2 (Temperature, Conditions, Wind, Humidity)
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: HYKATheme.spacingM) {
                        // Temperature
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "thermometer")
                                    .font(.system(size: 14))
                                    .foregroundColor(.red)
                                Text("Temperature")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(HYKATheme.Light.mutedForeground)
                            }
                            if isLoadingWeather {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text(weatherData?.temperature ?? "N/A")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(HYKATheme.Light.foreground)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(HYKATheme.spacingM)
                        .background(HYKATheme.Light.background)
                        .cornerRadius(HYKATheme.cornerRadiusM)
                        
                        // Conditions
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "cloud.sun.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yellow)
                                Text("Conditions")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(HYKATheme.Light.mutedForeground)
                            }
                            if isLoadingWeather {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text(weatherData?.conditions ?? "N/A")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(HYKATheme.Light.foreground)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(HYKATheme.spacingM)
                        .background(HYKATheme.Light.background)
                        .cornerRadius(HYKATheme.cornerRadiusM)
                        
                        // Wind
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "wind")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                                Text("Wind")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(HYKATheme.Light.mutedForeground)
                            }
                            if isLoadingWeather {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text(weatherData?.wind ?? "N/A")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(HYKATheme.Light.foreground)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(HYKATheme.spacingM)
                        .background(HYKATheme.Light.background)
                        .cornerRadius(HYKATheme.cornerRadiusM)
                        
                        // Humidity
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                                Text("Humidity")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(HYKATheme.Light.mutedForeground)
                            }
                            if isLoadingWeather {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text(weatherData?.humidity ?? "N/A")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(HYKATheme.Light.foreground)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(HYKATheme.spacingM)
                        .background(HYKATheme.Light.background)
                        .cornerRadius(HYKATheme.cornerRadiusM)
                    }
                    .padding(.top, HYKATheme.spacingM)
                    
                    // Separator
                    Rectangle()
                        .fill(HYKATheme.Light.border)
                        .frame(height: 1)
                        .padding(.vertical, HYKATheme.spacingM)
                    
                    // Pro Tip
                    HStack(alignment: .top, spacing: HYKATheme.spacingS) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.yellow)
                        
                        Text("Pro tip: Pack extra layers for elevation changes. Temperature can drop 6-8°C per 1000m gained.")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(HYKATheme.Light.mutedForeground)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(HYKATheme.spacingXXL)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(HYKATheme.cornerRadiusL)
                .overlay(
                    RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusL)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                )
                
                // Elevation Profile Section (no frame)
                VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
                    Text("Elevation Profile")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(HYKATheme.Light.foreground)
                    
                    Text("Total elevation gain: 3,200m")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(HYKATheme.Light.mutedForeground)
                }
                
                // Climbing Strategy Section
                climbingStrategySection
                
                // Descent Tactics Section
                descentTacticsSection
                
                // Energy Conservation Section
                energyConservationSection
            }
            .padding(HYKATheme.spacingXXL)
            .background(HYKATheme.Light.card)
            .cornerRadius(HYKATheme.cornerRadiusL)
            .overlay(
                RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusL)
                    .stroke(HYKATheme.Light.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
            .padding(.horizontal, HYKATheme.spacingXXL)
        }
        .padding(.top, HYKATheme.spacingL)
    }
    
    
    // MARK: - Climbing Strategy Section
    
    private var climbingStrategySection: some View {
        VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
            Text("Climbing Strategy")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(HYKATheme.Light.foreground)
            
            VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
                climbingStrategyItem(title: "Gentle Grades (<10%)", description: "Maintain running with shortened stride")
                climbingStrategyItem(title: "Moderate Climbs (10-15%)", description: "Power hike - hands on knees for leverage")
                climbingStrategyItem(title: "Steep Sections (>15%)", description: "Steady hiking pace - focus on rhythm and breathing")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(HYKATheme.spacingXXL)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(HYKATheme.cornerRadiusL)
        .overlay(
            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusL)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func climbingStrategyItem(title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: HYKATheme.spacingM) {
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 16))
                .foregroundColor(Color.purple)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(HYKATheme.Light.foreground)
                
                Text(description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(HYKATheme.Light.mutedForeground)
            }
        }
    }
    
    // MARK: - Descent Tactics Section
    
    private var descentTacticsSection: some View {
        VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
            Text("Descent Tactics")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(HYKATheme.Light.foreground)
            
            VStack(spacing: HYKATheme.spacingM) {
                descentTacticCard(title: "Technical Descents", description: "Quick, light steps - let gravity work for you but stay controlled")
                descentTacticCard(title: "Runnable Descents", description: "Open up stride but protect quads - they'll need to last")
                descentTacticCard(title: "Late-Race Descents", description: "Caution on fatigued legs - avoid falls when you're tired")
            }
        }
    }
    
    private func descentTacticCard(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: HYKATheme.spacingXS) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(HYKATheme.Light.foreground)
            
            Text(description)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(HYKATheme.Light.mutedForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(HYKATheme.spacingM)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(HYKATheme.cornerRadiusM)
        .overlay(
            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Energy Conservation Section
    
    private var energyConservationSection: some View {
        VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
            Text("Energy Conservation")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(HYKATheme.Light.foreground)
            
            VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
                energyConservationItem(text: "Don't be afraid to walk uphills - you'll save energy for the runnable sections")
                energyConservationItem(text: "Use trekking poles if allowed - they reduce leg fatigue significantly")
                energyConservationItem(text: "Make up time on the flats and gentle rollers, not the climbs")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(HYKATheme.spacingXXL)
        .background(Color.green.opacity(0.1))
        .cornerRadius(HYKATheme.cornerRadiusL)
        .overlay(
            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusL)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func energyConservationItem(text: String) -> some View {
        HStack(alignment: .top, spacing: HYKATheme.spacingS) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.green)
            
            Text(text)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(HYKATheme.Light.foreground)
        }
    }
    
    // MARK: - Functions
    
    private func fetchConnectedProvider() async {
        guard let userId = await resolveUserId() else { return }
        
        do {
            let connections = try await SupabaseService.fetchOAuthConnections(userId: userId)
            await MainActor.run {
                // Get the first connected provider (Garmin, Coros, Suunto, or Polar)
                connectedProvider = connections.first?.provider
            }
        } catch {
            print("⚠️ Failed to fetch connected provider: \(error)")
        }
    }
    
    @MainActor
    // REMOVED: syncWithGarmin() function
    // Garmin data is now synced automatically via backend webhooks
    // This function is no longer needed
    /*
    private func syncWithGarmin() async {
        guard let userId = await resolveUserId() else {
            ErrorManager.shared.showError(NSError(domain: "Sync", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]), title: "Sync Failed")
            return
        }
        
        // Check if Garmin is connected
        let connections = (try? await SupabaseService.fetchOAuthConnections(userId: userId)) ?? []
        guard let garminConnection = connections.first(where: { $0.provider.lowercased() == "garmin" }) else {
            ErrorManager.shared.showError(NSError(domain: "Sync", code: 2, userInfo: [NSLocalizedDescriptionKey: "Garmin is not connected. Please connect Garmin first."]), title: "Sync Failed")
            return
        }
        
        isSyncingGarmin = true
        
        do {
            print("🔄 Starting Garmin sync...")
            print("📋 User ID: \(userId.uuidString)")
            print("📋 Access Token: \(garminConnection.accessToken.prefix(20))...")
            
            // Fetch fresh workout data from Garmin and store in Supabase
            // Uses OAuth 2.0 PKCE Bearer token authentication
            let service = WorkoutDataFetchingService()
            
            // Full historical sync - fetch ALL activities when user clicks "Sync with device"
            // This gives users access to all their historical activities
            // For automatic/background syncs, use incremental sync instead
            let workoutsFetched = try await service.fetchAndStoreWorkouts(
                userId: userId,
                provider: "garmin",
                accessToken: garminConnection.accessToken,
                tokenSecret: nil, // OAuth 2.0 doesn't use token secret
                after: nil, // nil = use full historical sync (fetch all activities)
                useIncrementalSync: false // false = fetch ALL historical activities
            )
            
            print("✅ Synced \(workoutsFetched) new workouts from Garmin")
            
            if workoutsFetched == 0 {
                print("ℹ️ No new workouts found (they may already be synced)")
            }
            
            // Reload race details to recalculate with fresh data
            if let currentRace = selectedRace {
                print("🔄 Reloading race plan with fresh data...")
                try await loadRaceDetails(for: currentRace, userId: userId, forceRefresh: true)
            }
            
            // Show success message
            await MainActor.run {
                isSyncingGarmin = false
            }
            
            print("✅ Garmin sync completed successfully")
            
            // Show success message to user
            if workoutsFetched > 0 {
                await MainActor.run {
                    // You could show a success toast here if you have one
                    print("✅ Successfully synced \(workoutsFetched) workouts")
                }
            }
            
        } catch {
            print("❌ Garmin sync failed: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("❌ Error domain: \(nsError.domain)")
                print("❌ Error code: \(nsError.code)")
                print("❌ Error userInfo: \(nsError.userInfo)")
            }
            await MainActor.run {
                isSyncingGarmin = false
            }
            ErrorManager.shared.showError(error, title: "Sync Failed")
        }
    }
    */
    
    private func loadRacePlans(selecting preferredRaceId: UUID? = nil, forceRefresh: Bool = false) async {
        guard let userId = await resolveUserId() else {
            await MainActor.run {
                racePlans = []
                selectedRace = nil
                clearRaceDetailState()
            }
            return
        }
        
        await MainActor.run { isLoading = true }
        
        do {
            if forceRefresh {
                await RacePlanListCache.shared.clear(for: userId)
            }
            let cachedPlans = await RacePlanListCache.shared.plans(for: userId)
            let plans: [RacePlanSummary]
            if let cached = cachedPlans, !cached.isEmpty, !forceRefresh {
                plans = cached
            } else {
                plans = try await SupabaseService.fetchRacePlans(userId: userId)
                await RacePlanListCache.shared.save(plans: plans, for: userId)
            }
            var planToLoad: RacePlanSummary?
            
            await MainActor.run {
                racePlans = plans
                
                if let preferredId = preferredRaceId, let matching = plans.first(where: { $0.id == preferredId }) {
                    selectedRace = matching
                    planToLoad = matching
                } else if let current = selectedRace, let refreshed = plans.first(where: { $0.id == current.id }) {
                    selectedRace = refreshed
                    planToLoad = refreshed
                } else {
                    selectedRace = plans.first
                    planToLoad = selectedRace
                }
            }
            
            if let plan = planToLoad {
                try await loadRaceDetails(for: plan, userId: userId, forceRefresh: forceRefresh)
            } else {
                await MainActor.run {
                    clearRaceDetailState()
                }
            }
        } catch {
            print("❌ Error loading race plans: \(error)")
            ErrorManager.shared.showError(error, title: "Failed to Load Race Plans")
            
            do {
                let fuelTypesFromDB = try await SupabaseService.fetchFuelTypes(userId: userId)
                await MainActor.run {
                    fuelTypes = makeFuelTypes(from: fuelTypesFromDB)
                    weatherLocation = "Dublin, Ireland"
                    weatherCoordinates = nil
                }
                await fetchWeather(location: weatherLocation)
            } catch {
                // Ignore cancellation errors (these happen when views are dismissed)
                if let urlError = error as? URLError, urlError.code == .cancelled {
                    print("ℹ️ Fuel types request was cancelled (likely view dismissed)")
                    return
                }
                let errorString = String(describing: error)
                if errorString.contains("Code=-999") || errorString.contains("cancelled") {
                    print("ℹ️ Fuel types request was cancelled (likely view dismissed)")
                    return
                }
                print("❌ Error loading fallback fuel types: \(error)")
                ErrorManager.shared.showError(error, title: "Failed to Load Fuel Types")
            }
        }
        
        await MainActor.run { isLoading = false }
    }
    
    private func loadRaceDetails(for plan: RacePlanSummary, userId: UUID, forceRefresh: Bool = false) async throws {
        if !forceRefresh,
           let cachedDetail = await RacePlanDetailCache.shared.detail(for: plan.id),
           cachedDetail.lastUpdated == plan.updatedAt {
            await MainActor.run {
                applyCachedDetail(cachedDetail)
            }
            await fetchWeather(location: cachedDetail.weatherLocation, coordinates: cachedDetail.weatherCoordinates)
            return
        }
        let segments = try await SupabaseService.fetchRacePlanSegments(racePlanId: plan.id)
        let fuelTypesFromDB = try await SupabaseService.fetchFuelTypes(userId: userId)
        let trackPointsFromDB = try await SupabaseService.fetchRacePlanTrackPoints(racePlanId: plan.id)
        let totalDistanceMeters = trackPointsFromDB.last?.distFromStart ?? 0
        let computedDistanceKm = totalDistanceMeters / 1000.0
        
        // Calculate cumulative elevation gain from all track points
        // This is the proper way to calculate total elevation gain: sum all positive elevation changes
        var cumulativeElevationGain: Double = 0
        if trackPointsFromDB.count > 1 {
            for i in 1..<trackPointsFromDB.count {
                let delta = trackPointsFromDB[i].ele - trackPointsFromDB[i - 1].ele
                if delta > 0 {
                    cumulativeElevationGain += delta
                }
            }
            print("📊 Calculated cumulative elevation gain: \(String(format: "%.2f", cumulativeElevationGain))m from \(trackPointsFromDB.count) track points")
        }
        
        var updatedMetadata = RacePlanMetadataStore.load(for: plan.id) ?? RacePlanMetadata(raceDate: nil, startTime: nil, elevationGain: nil, distance: nil, notes: nil)
        if computedDistanceKm > 0 {
            updatedMetadata.distance = computedDistanceKm
        }
        // Always update elevation gain from calculated cumulative value
        if cumulativeElevationGain > 0 {
            let roundedGain = Int(round(cumulativeElevationGain))
            updatedMetadata.elevationGain = roundedGain
            print("✅ Updated elevation gain in metadata: \(roundedGain)m")
        }
        
        let sortedSegments = segments.sorted { $0.index < $1.index }
        let aidStationsFromDB = sortedSegments.map { segment in
            AidStation(
                name: segment.notes ?? "Station \(segment.index)",
                distance: segment.distanceM / 1000.0,
                services: segment.services.compactMap { $0.toAidService() }
            )
        }
        let metricsFromDB = sortedSegments.enumerated().map { index, segment -> AidStationSegmentMetrics in
            AidStationSegmentMetrics(
                segmentDistanceM: segment.segmentDistanceM,
                elevationGainM: segment.elevationGainM,
                elevationLossM: segment.elevationLossM,
                estimatedTimeSeconds: segment.estimatedTimeSeconds,
                averageHeartRate: segment.averageHeartRate
            )
        }
        
        let storedLocation = UserDefaults.standard.string(forKey: "race_plan_location_\(plan.id.uuidString)")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedCoordinates = loadWeatherCoordinates(for: plan.id)
        let midpointCoords = midpointCoordinate(from: trackPointsFromDB)
        
        let coordinatesForWeather: WeatherCoordinates?
        let baseLocation: String?
        
        if let storedLocation, !storedLocation.isEmpty {
            baseLocation = storedLocation
            coordinatesForWeather = storedCoordinates ?? midpointCoords
        } else if let midpointCoords {
            baseLocation = "Course midpoint"
            coordinatesForWeather = midpointCoords
        } else {
            baseLocation = "Dublin, Ireland"
            coordinatesForWeather = nil
        }
        
        let (locationDisplay, finalCoordinates) = await formatWeatherLocation(base: baseLocation, coordinates: coordinatesForWeather)
        
        if let finalCoordinates {
            persistWeatherCoordinates(finalCoordinates, for: plan.id)
        } else {
            clearWeatherCoordinates(for: plan.id)
        }
        
        let metricsDictionary = Dictionary(uniqueKeysWithValues: metricsFromDB.enumerated().map { ($0.offset, $0.element) })
        let finalAidStations: [AidStation]
        if !aidStationsFromDB.isEmpty {
            finalAidStations = aidStationsFromDB
        } else {
            let totalDistanceKm = (segments.last?.distanceM ?? 0) / 1000.0
            finalAidStations = [
                AidStation(name: "Start", distance: 0, services: []),
                AidStation(name: "Finish", distance: totalDistanceKm, services: [])
            ]
        }
        
        await MainActor.run {
            racePlanId = plan.id
            selectedRace = plan
            raceMetadata = updatedMetadata
            
            fuelTypes = makeFuelTypes(from: fuelTypesFromDB)
            trackPoints = trackPointsFromDB
            
            aidStations = finalAidStations
            
            athleteAnalytics = nil
            pacingSegments = []
            fuelingStations = []
            aidStationMetrics = metricsDictionary
            
            weatherLocation = locationDisplay
            weatherCoordinates = finalCoordinates
            
            recalculateStrategy()
        }
        
        let workouts = try await SupabaseService.fetchWorkouts(userId: userId)
        print("📊 RacePlanView: Fetched \(workouts.count) workouts")
        if !workouts.isEmpty {
            print("   First workout: \(workouts.first?.distanceM ?? 0)m, HR: \(workouts.first?.avgHR ?? 0)/\(workouts.first?.maxHR ?? 0) bpm")
        }
        
        let now = Date()
        let historyStart = Calendar.current.date(byAdding: .day, value: -90, to: now) ?? now
        let healthHistory = try await SupabaseService.fetchHealthMetrics(userId: userId, startDate: historyStart, endDate: now)
        let latestHealthMetric = healthHistory.first
        let analytics = await buildAthleteAnalytics(userId: userId, workouts: workouts, healthMetric: latestHealthMetric)
        
        print("📊 RacePlanView: Analytics calculated:")
        print("   basePace: \(analytics.basePaceMinutesPerKilometer?.description ?? "nil") min/km")
        print("   maxHR: \(analytics.maxHeartRate?.description ?? "nil") bpm")
        print("   avgHR: \(analytics.averageHeartRate?.description ?? "nil") bpm")
        print("   caloriesPerHour: \(analytics.caloriesPerHour) kcal/h")
        let baseDistance = computedDistanceKm > 0 ? computedDistanceKm : (finalAidStations.last?.distance ?? 0)
        let sectionPlans = buildSectionPlans(
            aidStations: finalAidStations,
            metrics: metricsDictionary,
            analytics: analytics,
            totalDistanceKm: baseDistance,
            temperatureC: parseTemperatureCelsius(from: weatherData)
        )
        let fuelingPlan = buildFuelingStations(
            sectionPlans: sectionPlans,
            analytics: analytics,
            temperatureC: parseTemperatureCelsius(from: weatherData)
        )
        
        let cachedDetail = CachedRacePlanDetail(
            metadata: updatedMetadata,
            aidStations: finalAidStations,
            pacingSegments: sectionPlans.map { $0.pacingSegment },
            fuelingStations: fuelingPlan,
            trackPoints: trackPointsFromDB,
            aidStationMetrics: metricsDictionary,
            weatherLocation: locationDisplay,
            weatherCoordinates: finalCoordinates,
            lastUpdated: plan.updatedAt
        )
        await RacePlanDetailCache.shared.save(detail: cachedDetail, for: plan.id)
        
        // Save metadata if we have distance or elevation gain
        if computedDistanceKm > 0 || updatedMetadata.elevationGain != nil {
            RacePlanMetadataStore.save(updatedMetadata, for: plan.id)
        }
        
        await MainActor.run {
            athleteAnalytics = analytics
            pacingSegments = sectionPlans.map { $0.pacingSegment }
            fuelingStations = fuelingPlan
        }
        
        await fetchWeather(location: locationDisplay, coordinates: coordinatesForWeather)
    }
    
    private func selectRace(_ plan: RacePlanSummary) async {
        guard let userId = await resolveUserId() else { return }
        
        await MainActor.run { isLoading = true }
        
        do {
            try await loadRaceDetails(for: plan, userId: userId)
        } catch {
            print("❌ Error loading race details: \(error)")
            await MainActor.run {
                ErrorManager.shared.showError(error, title: "Failed to Load Race Details")
            }
        }
        
        await MainActor.run { isLoading = false }
    }
    
    @MainActor
    private func clearRaceDetailState() {
        racePlanId = nil
        selectedRace = nil
        raceDetails = nil
        raceMetadata = nil
        aidStations = []
        pacingSegments = []
        fuelingStations = []
        weatherData = nil
        trackPoints = []
        aidStationMetrics = [:]
        weatherCoordinates = nil
    }
    
    private func resolveUserId() async -> UUID? {
        await MainActor.run {
            if let user = session.currentUser {
                return user.id
            } else if session.isAuthenticated,
                      let userIdString = UserDefaults.standard.string(forKey: "hyka.user.id"),
                      let id = UUID(uuidString: userIdString) {
                return id
            } else {
                return nil
            }
        }
    }
    
    private func formattedRaceDistance() -> String {
        if let metadataDistance = raceMetadata?.distance, metadataDistance > 0 {
            return formattedDistanceValue(metadataDistance)
        }
        if let trackDistanceMeters = trackPoints.last?.distFromStart, trackDistanceMeters > 0 {
            return formattedDistanceValue(trackDistanceMeters / 1000.0)
        }
        if let aidStationDistance = aidStations.last?.distance, aidStationDistance > 0 {
            return formattedDistanceValue(aidStationDistance)
        }
        return "—"
    }
    
    private func formattedEstimatedDuration() -> String {
        let distanceKm = aidStations.last?.distance ?? 0
        guard distanceKm > 0 else { return "—" }
        
        // If we have calculated pacing segments, sum their durations
        if !pacingSegments.isEmpty {
            // Calculate total hours from existing section plans
            // We need to parse the duration strings or use a cached total
            // For now, use a simple approach: sum section hours if available
            if let analytics = athleteAnalytics {
                let totalDistance = raceMetadata?.distance ?? distanceKm
                let temperature = parseTemperatureCelsius(from: weatherData) ?? 15.0
                let sectionPlans = buildSectionPlans(
                    aidStations: aidStations,
                    metrics: aidStationMetrics,
                    analytics: analytics,
                    totalDistanceKm: totalDistance,
                    temperatureC: temperature
                )
                let totalHours = sectionPlans.reduce(0) { $0 + $1.sectionHours }
                if totalHours > 0 {
                    return String(format: "%.1f hours", totalHours)
                }
            }
        }
        
        // Fallback to simple calculation if no provider data or no segments calculated yet
        let paceMinutesPerKm = 10.0
        let totalMinutes = distanceKm * paceMinutesPerKm
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60.0
            return String(format: "%.1f hours", hours)
        } else {
            return String(format: "%.0f min", totalMinutes)
        }
    }
    
    private func formattedDistanceValue(_ distanceKm: Double) -> String {
        if distanceKm >= 100 {
            return String(format: "%.0fK", distanceKm)
        } else if distanceKm >= 10 {
            return String(format: "%.0fK", distanceKm)
        } else {
            return String(format: "%.1fK", distanceKm)
        }
    }
    
    // MARK: - Weather API
    
    private func fetchWeather(location: String, coordinates overrideCoordinates: WeatherCoordinates? = nil) async {
        isLoadingWeather = true
        
        let resolvedCoordinates: WeatherCoordinates?
        if let overrideCoordinates {
            resolvedCoordinates = overrideCoordinates
        } else if let parsed = parseCoordinateString(location) {
            resolvedCoordinates = parsed
        } else {
            resolvedCoordinates = await geocodeLocation(location)
        }
        
        // First, ensure we have coordinates
        guard let coordinates = resolvedCoordinates else {
            print("⚠️ Failed to geocode location: \(location)")
            isLoadingWeather = false
            return
        }
        
        let currentLocation = await MainActor.run { weatherLocation }
        let (formattedLocation, _) = await formatWeatherLocation(base: currentLocation, coordinates: coordinates)
        
        await MainActor.run {
            weatherCoordinates = coordinates
            weatherLocation = formattedLocation
        }
        
        if let planId = await MainActor.run(body: { racePlanId }) {
            persistWeatherCoordinates(coordinates, for: planId)
        }
        
        // Use Tomorrow.io API with coordinates
        let apiKey = Config.tomorrowIOAPIKey
        let locationParam = "\(coordinates.latitude),\(coordinates.longitude)"
        let urlString = "https://api.tomorrow.io/v4/weather/forecast?location=\(locationParam)&apikey=\(apiKey)&units=metric"
        
        guard let url = URL(string: urlString) else {
            print("⚠️ Invalid weather API URL")
            isLoadingWeather = false
            return
        }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                if let httpResponse = response as? HTTPURLResponse {
                    print("⚠️ Weather API error: Status \(httpResponse.statusCode)")
                    if let errorData = String(data: data, encoding: .utf8) {
                        print("⚠️ Error response: \(errorData)")
                    }
                }
                isLoadingWeather = false
                return
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let timelines = json["timelines"] as? [String: Any],
               let dailyTimeline = timelines["daily"] as? [[String: Any]],
               let firstDay = dailyTimeline.first,
               let values = firstDay["values"] as? [String: Any] {
                
                // Extract temperature data
                let tempMin = values["temperatureMin"] as? Double ?? 0
                let tempMax = values["temperatureMax"] as? Double ?? 0
                
                // Extract weather condition
                let weatherCode = values["weatherCode"] as? Int ?? 1000
                let conditions = getWeatherCondition(from: weatherCode)
                
                // Extract wind speed (in m/s, convert to km/h)
                let windSpeed = values["windSpeedAvg"] as? Double ?? 0
                
                // Extract humidity
                let humidity = values["humidityAvg"] as? Double ?? 0
                
                await MainActor.run {
                    weatherData = WeatherData(
                        temperature: "\(Int(tempMin))-\(Int(tempMax))°C",
                        conditions: conditions,
                        wind: "\(Int(windSpeed * 3.6)) km/h",
                        humidity: "\(Int(humidity))%"
                    )
                    recalculateStrategy()
                }
                
                print("✅ Weather data loaded from Tomorrow.io: \(conditions)")
            } else {
                // Try hourly timeline as fallback
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let timelines = json["timelines"] as? [String: Any],
                   let hourlyTimeline = timelines["hourly"] as? [[String: Any]],
                   let currentHour = hourlyTimeline.first,
                   let values = currentHour["values"] as? [String: Any] {
                    
                    let temp = values["temperature"] as? Double ?? 0
                    let weatherCode = values["weatherCode"] as? Int ?? 1000
                    let conditions = getWeatherCondition(from: weatherCode)
                    let windSpeed = values["windSpeed"] as? Double ?? 0
                    let humidity = values["humidity"] as? Double ?? 0
                    
                    await MainActor.run {
                        weatherData = WeatherData(
                            temperature: "\(Int(temp))°C",
                            conditions: conditions,
                            wind: "\(Int(windSpeed * 3.6)) km/h",
                            humidity: "\(Int(humidity))%"
                        )
                        recalculateStrategy()
                    }
                    
                    print("✅ Weather data loaded from Tomorrow.io (hourly): \(conditions)")
                } else {
                    print("⚠️ Could not parse Tomorrow.io weather response")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("⚠️ Response: \(jsonString.prefix(500))")
                    }
                }
            }
        } catch {
            print("⚠️ Error fetching weather: \(error)")
            ErrorManager.shared.showError(error, title: "Weather Update Failed")
        }
        
        isLoadingWeather = false
    }
    
    // MARK: - Geocoding
    
    private func parseCoordinateString(_ location: String) -> WeatherCoordinates? {
        let pattern = "-?\\d+(?:\\.\\d+)?"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        let range = NSRange(location: 0, length: location.utf16.count)
        let matches = regex.matches(in: location, options: [], range: range)
        guard matches.count >= 2 else { return nil }
        let latString = (location as NSString).substring(with: matches[0].range)
        let lonString = (location as NSString).substring(with: matches[1].range)
        guard let latitude = Double(latString), let longitude = Double(lonString) else {
            return nil
        }
        return WeatherCoordinates(latitude: latitude, longitude: longitude)
    }
    
    private func geocodeLocation(_ locationName: String) async -> WeatherCoordinates? {
        // Use OpenStreetMap Nominatim API for geocoding (free, no API key required)
        let encodedLocation = locationName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://nominatim.openstreetmap.org/search?q=\(encodedLocation)&format=json&limit=1"
        
        guard let url = URL(string: urlString) else {
            print("⚠️ Invalid geocoding URL")
            return nil
        }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("HYKA Weather App", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                if let httpResponse = response as? HTTPURLResponse {
                    print("⚠️ Geocoding API error: Status \(httpResponse.statusCode)")
                } else {
                    print("⚠️ Geocoding API error: Invalid response")
                }
                return nil
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let firstResult = json.first,
               let latString = firstResult["lat"] as? String,
               let lonString = firstResult["lon"] as? String,
               let latitude = Double(latString),
               let longitude = Double(lonString) {
                
                print("✅ Geocoded \(locationName) to coordinates: \(latitude), \(longitude)")
                return WeatherCoordinates(latitude: latitude, longitude: longitude)
            } else {
                print("⚠️ Could not parse geocoding response")
                return nil
            }
        } catch {
            print("⚠️ Error geocoding location: \(error)")
            ErrorManager.shared.showError(error, title: "Location Lookup Failed")
            return nil
        }
    }
    
    // Helper function to convert Tomorrow.io weather codes to descriptions
    private func getWeatherCondition(from code: Int) -> String {
        // Tomorrow.io weather codes mapping
        switch code {
        case 1000: return "Clear"
        case 1100: return "Mostly Clear"
        case 1101: return "Partly Cloudy"
        case 1102: return "Mostly Cloudy"
        case 1001: return "Cloudy"
        case 2000: return "Fog"
        case 2100: return "Light Fog"
        case 4000: return "Drizzle"
        case 4001: return "Rain"
        case 4200: return "Light Rain"
        case 4201: return "Heavy Rain"
        case 5000: return "Snow"
        case 5001: return "Flurries"
        case 5100: return "Light Snow"
        case 5101: return "Heavy Snow"
        case 6000: return "Freezing Drizzle"
        case 6001: return "Freezing Rain"
        case 6200: return "Light Freezing Rain"
        case 6201: return "Heavy Freezing Rain"
        case 7000: return "Ice Pellets"
        case 7101: return "Heavy Ice Pellets"
        case 7102: return "Light Ice Pellets"
        case 8000: return "Thunderstorm"
        default: return "Unknown"
        }
    }
    
    // MARK: - Save Aid Stations
    
    private func saveAidStations() async {
        // Get user ID from session
        guard let userId = session.currentUser?.id else {
            print("⚠️ Cannot save aid stations: No user ID")
            return
        }
        
        do {
            var finalRacePlanId: UUID
            if let existingRacePlanId = racePlanId {
                finalRacePlanId = existingRacePlanId
            } else {
                print("ℹ️ No race plan found, creating a new one...")
                let raceDetails = RaceDetails(
                    name: "My Race Plan",
                    date: Date(),
                    startTime: Calendar.current.date(from: DateComponents(hour: 6, minute: 0)) ?? Date(),
                    distance: 100.0,
                    elevation: 0,
                    difficulty: "Medium"
                )
                let preferences = StrategyPreferences(
                    raceGoals: [.finish],
                    nutritionPreferences: [.mix]
                )
                finalRacePlanId = try await SupabaseService.saveRacePlan(
                    userId: userId,
                    raceDetails: raceDetails,
                    aidStations: aidStations,
                    preferences: preferences
                )
                racePlanId = finalRacePlanId
                print("✅ Created new race plan: \(finalRacePlanId.uuidString)")
            }
            
            var currentTrackPoints = trackPoints
            if currentTrackPoints.isEmpty {
                currentTrackPoints = try await SupabaseService.fetchRacePlanTrackPoints(racePlanId: finalRacePlanId)
                await MainActor.run { trackPoints = currentTrackPoints }
            }
            let orderedStations = aidStations.sorted { $0.distance < $1.distance }
            let metrics = buildSegmentMetrics(for: orderedStations, using: currentTrackPoints)
            try await SupabaseService.updateAidStations(
                racePlanId: finalRacePlanId,
                aidStations: orderedStations,
                segmentMetrics: metrics,
                paceSecondsPerKm: Double(defaultPaceSecondsPerKm)
            )
            
            await MainActor.run {
                aidStations = orderedStations
                aidStationMetrics = Dictionary(uniqueKeysWithValues: metrics.enumerated().map { ($0.offset, $0.element) })
                recalculateStrategy()
            }
            
            print("✅ Aid stations saved successfully")
        } catch {
            print("❌ Error saving aid stations: \(error)")
            if let postgrestError = error as? PostgrestError {
                print("   PostgrestError code: \(postgrestError.code ?? "nil")")
                print("   PostgrestError message: \(postgrestError.message)")
            }
            ErrorManager.shared.showError(error, title: "Failed to Save Aid Stations")
        }
    }
    
    // MARK: - Save Location
    
    private func saveLocationToRacePlan(racePlanId: UUID, location: String) async {
        // Note: This will require adding a location column to race_plans table
        // For now, we'll just store it in UserDefaults as a fallback
        let trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed, forKey: "race_plan_location_\(racePlanId.uuidString)")
        if let coordinates = await MainActor.run(body: { weatherCoordinates }) {
            persistWeatherCoordinates(coordinates, for: racePlanId)
        }
        print("✅ Location saved: \(location)")
    }
    
    // MARK: - Save Race Name and Date
    
    private func saveRaceNameAndDate() async {
        guard let racePlanId = racePlanId else {
            print("⚠️ Cannot save race name/date: No race plan ID")
            return
        }
        
        do {
            // Update title in Supabase
            try await SupabaseService.updateRacePlanTitle(racePlanId: racePlanId, title: editingRaceName)
            
            // Update metadata (including date)
            var updatedMetadata = raceMetadata ?? RacePlanMetadata(raceDate: nil, startTime: nil, elevationGain: nil, distance: nil, notes: nil)
            updatedMetadata.raceDate = editingRaceDate
            RacePlanMetadataStore.save(updatedMetadata, for: racePlanId)
            
            // Update local state
            await MainActor.run {
                raceMetadata = updatedMetadata
                if var updatedRace = selectedRace {
                    // Create a new RacePlanSummary with updated title
                    selectedRace = RacePlanSummary(
                        id: updatedRace.id,
                        title: editingRaceName,
                        createdAt: updatedRace.createdAt,
                        updatedAt: Date()
                    )
                }
            }
            
            // Refresh race plans list
            await loadRacePlans(forceRefresh: true)
            
            print("✅ Race name and date saved successfully")
        } catch {
            print("❌ Error saving race name/date: \(error)")
            ErrorManager.shared.showError(error, title: "Failed to Save Race Details")
        }
    }
    
    @MainActor
    private func recalculateStrategy() {
        guard let analytics = athleteAnalytics, aidStations.count > 1 else { return }
        let totalDistance = raceMetadata?.distance ?? aidStations.last?.distance ?? ((trackPoints.last?.distFromStart ?? 0) / 1000.0)
        guard totalDistance > 0 else { return }
        let temperature = parseTemperatureCelsius(from: weatherData) ?? 15.0
        let sectionPlans = buildSectionPlans(
            aidStations: aidStations,
            metrics: aidStationMetrics,
            analytics: analytics,
            totalDistanceKm: totalDistance,
            temperatureC: temperature
        )
        pacingSegments = sectionPlans.map { $0.pacingSegment }
        fuelingStations = buildFuelingStations(
            sectionPlans: sectionPlans,
            analytics: analytics,
            temperatureC: temperature
        )
    }
    
    private func persistWeatherCoordinates(_ coordinates: WeatherCoordinates, for racePlanId: UUID) {
        let key = weatherCoordinatesKey(for: racePlanId)
        do {
            let data = try JSONEncoder().encode(coordinates)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("⚠️ Failed to persist weather coordinates: \(error)")
        }
    }
    
    private func loadWeatherCoordinates(for racePlanId: UUID) -> WeatherCoordinates? {
        let key = weatherCoordinatesKey(for: racePlanId)
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(WeatherCoordinates.self, from: data)
        } catch {
            print("⚠️ Failed to load weather coordinates: \(error)")
            return nil
        }
    }
    
    private func clearWeatherCoordinates(for racePlanId: UUID) {
        UserDefaults.standard.removeObject(forKey: weatherCoordinatesKey(for: racePlanId))
    }
    
    private func weatherCoordinatesKey(for racePlanId: UUID) -> String {
        "race_plan_weather_coords_\(racePlanId.uuidString)"
    }
    
    private func makeFuelTypes(from dbTypes: [SupabaseFuelType]) -> [FuelType] {
        var seen = Set<String>()
        var results: [FuelType] = []
        for dbType in dbTypes {
            let key = "\(dbType.name.lowercased())|\(dbType.category.lowercased())"
            if seen.insert(key).inserted {
                results.append(
                    FuelType(
                        id: dbType.id,
                        name: dbType.name,
                        category: dbType.category,
                        carbs: dbType.carbs,
                        sodium: dbType.sodium,
                        isCustom: dbType.isCustom
                    )
                )
            }
        }
        return results
    }
    
    private func buildSegmentMetrics(for stations: [AidStation], using trackPoints: [TrackPoint]) -> [AidStationSegmentMetrics] {
        guard !stations.isEmpty else { return [] }
        guard !trackPoints.isEmpty else {
            return stations.enumerated().map { index, station in
                if index == 0 {
                    return AidStationSegmentMetrics(segmentDistanceM: 0, elevationGainM: 0, elevationLossM: 0, estimatedTimeSeconds: 0, averageHeartRate: nil)
                } else {
                    let previous = stations[index - 1]
                    let segmentDistanceM = max(0, (station.distance - previous.distance) * 1000)
                    let estimated = (segmentDistanceM / 1000.0) * Double(defaultPaceSecondsPerKm)
                    return AidStationSegmentMetrics(segmentDistanceM: segmentDistanceM, elevationGainM: 0, elevationLossM: 0, estimatedTimeSeconds: estimated, averageHeartRate: nil)
                }
            }
        }
        var metrics: [AidStationSegmentMetrics] = []
        for index in stations.indices {
            if index == 0 {
                metrics.append(AidStationSegmentMetrics(segmentDistanceM: 0, elevationGainM: 0, elevationLossM: 0, estimatedTimeSeconds: 0, averageHeartRate: nil))
            } else {
                let startDistanceM = stations[index - 1].distance * 1000.0
                let endDistanceM = stations[index].distance * 1000.0
                let startIndex = nearestTrackPointIndex(for: startDistanceM, in: trackPoints)
                let endIndex = nearestTrackPointIndex(for: endDistanceM, in: trackPoints)
                metrics.append(computeSegmentMetrics(trackPoints: trackPoints, startIndex: startIndex, endIndex: endIndex))
            }
        }
        return metrics
    }
    
    private func computeSegmentMetrics(trackPoints: [TrackPoint], startIndex: Int, endIndex: Int) -> AidStationSegmentMetrics {
        guard startIndex < endIndex, endIndex < trackPoints.count else {
            return AidStationSegmentMetrics(segmentDistanceM: 0, elevationGainM: 0, elevationLossM: 0, estimatedTimeSeconds: 0, averageHeartRate: nil)
        }
        let startPoint = trackPoints[startIndex]
        let endPoint = trackPoints[endIndex]
        let segmentDistanceM = max(0, endPoint.distFromStart - startPoint.distFromStart)
        var gain: Double = 0
        var loss: Double = 0
        var hrTotal: Double = 0
        var hrCount: Double = 0
        for idx in (startIndex + 1)...endIndex {
            let delta = trackPoints[idx].ele - trackPoints[idx - 1].ele
            if delta > 0 {
                gain += delta
            } else {
                loss += abs(delta)
            }
            if let hr = trackPoints[idx].hr {
                hrTotal += Double(hr)
                hrCount += 1
            }
        }
        let estimatedTime = (segmentDistanceM / 1000.0) * Double(defaultPaceSecondsPerKm)
        let averageHR = hrCount > 0 ? hrTotal / hrCount : nil
        return AidStationSegmentMetrics(segmentDistanceM: segmentDistanceM, elevationGainM: gain, elevationLossM: loss, estimatedTimeSeconds: estimatedTime, averageHeartRate: averageHR)
    }
    
    private func nearestTrackPointIndex(for distanceM: Double, in trackPoints: [TrackPoint]) -> Int {
        guard let last = trackPoints.last else { return 0 }
        if distanceM <= 0 { return 0 }
        if distanceM >= last.distFromStart { return trackPoints.count - 1 }
        var low = 0
        var high = trackPoints.count - 1
        while low <= high {
            let mid = (low + high) / 2
            if trackPoints[mid].distFromStart < distanceM {
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        let upperIndex = min(low, trackPoints.count - 1)
        let lowerIndex = max(upperIndex - 1, 0)
        let upperDiff = abs(trackPoints[upperIndex].distFromStart - distanceM)
        let lowerDiff = abs(trackPoints[lowerIndex].distFromStart - distanceM)
        return upperDiff < lowerDiff ? upperIndex : lowerIndex
    }
    
    private func reverseGeocodeCoordinates(_ coordinates: WeatherCoordinates) async -> String? {
        let urlString = "https://nominatim.openstreetmap.org/reverse?lat=\(coordinates.latitude)&lon=\(coordinates.longitude)&format=json&zoom=10&addressdetails=1"
        guard let url = URL(string: urlString) else {
            print("⚠️ Invalid reverse geocoding URL")
            return nil
        }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("HYKA Weather App", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                if let httpResponse = response as? HTTPURLResponse {
                    print("⚠️ Reverse geocoding error: Status \(httpResponse.statusCode)")
                }
                return nil
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let address = json["address"] as? [String: Any] {
                let localityKeys = ["city", "town", "village", "municipality", "hamlet", "locality"]
                var locality: String?
                for key in localityKeys {
                    if let value = address[key] as? String, !value.isEmpty {
                        locality = value
                        break
                    }
                }
                if locality == nil {
                    locality = address["county"] as? String ?? address["state"] as? String ?? json["name"] as? String
                }
                if let locality, let country = address["country"] as? String, !country.isEmpty {
                    return "\(locality), \(country)"
                }
            }
        } catch {
            print("⚠️ Reverse geocoding failed: \(error)")
        }
        return nil
    }
    
    private func formatWeatherLocation(base: String?, coordinates: WeatherCoordinates?) async -> (String, WeatherCoordinates?) {
        let fallbackLocation = "Dublin, Ireland"
        let trimmedBase = base?
            .components(separatedBy: "(").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        let normalizedBase = trimmedBase.isEmpty ? nil : trimmedBase
        let needsReverseLookup: Bool = {
            guard let normalizedBase else { return true }
            if normalizedBase.caseInsensitiveCompare("course midpoint") == .orderedSame {
                return true
            }
            return !normalizedBase.contains(",")
        }()
        
        if let coordinates {
            if !needsReverseLookup, let normalizedBase {
                return (normalizedBase, coordinates)
            }
            if let resolved = await reverseGeocodeCoordinates(coordinates) {
                return (resolved, coordinates)
            }
            if let normalizedBase {
                return (normalizedBase.contains(",") ? normalizedBase : fallbackLocation, coordinates)
            }
            return (fallbackLocation, coordinates)
        } else {
            if let normalizedBase, normalizedBase.contains(",") {
                return (normalizedBase, nil)
            } else {
                return (fallbackLocation, nil)
            }
        }
    }
    
    private func midpointCoordinate(from trackPoints: [TrackPoint]) -> WeatherCoordinates? {
        guard !trackPoints.isEmpty else { return nil }
        let totalDistance = trackPoints.last?.distFromStart ?? 0
        if totalDistance <= 0 {
            let midpointIndex = trackPoints.count / 2
            let point = trackPoints[midpointIndex]
            return WeatherCoordinates(latitude: point.lat, longitude: point.lon)
        }
        let targetDistance = totalDistance / 2
        let index = nearestTrackPointIndex(for: targetDistance, in: trackPoints)
        guard trackPoints.indices.contains(index) else { return nil }
        let point = trackPoints[index]
        return WeatherCoordinates(latitude: point.lat, longitude: point.lon)
    }
    
    @MainActor
    private func applyCachedDetail(_ detail: CachedRacePlanDetail) {
        raceMetadata = detail.metadata
        aidStations = detail.aidStations
        pacingSegments = detail.pacingSegments
        fuelingStations = detail.fuelingStations
        trackPoints = detail.trackPoints
        aidStationMetrics = detail.aidStationMetrics
        weatherCoordinates = detail.weatherCoordinates
        weatherLocation = detail.weatherLocation
    }
    
    private func parseTemperatureCelsius(from data: WeatherData?) -> Double? {
        guard let raw = data?.temperature else { return nil }
        let components = raw
            .components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        switch components.count {
        case 0:
            return nil
        case 1:
            return components[0]
        default:
            let sum = components.reduce(0, +)
            return sum / Double(components.count)
        }
    }
    
    private func buildSectionPlans(
        aidStations: [AidStation],
        metrics: [Int: AidStationSegmentMetrics],
        analytics: AthleteAnalytics,
        totalDistanceKm: Double,
        temperatureC: Double?
    ) -> [SectionPlan] {
        guard aidStations.count > 1 else { return [] }
        let temperature = temperatureC ?? 15.0
        
        let basePace = analytics.basePaceMinutesPerKilometer
        let maxHeartRate = analytics.maxHeartRate
        
        var cumulativeHours: Double = 0
        var plans: [SectionPlan] = []
        
        for index in 1..<aidStations.count {
            var fromStation = aidStations[index - 1]
            var toStation = aidStations[index]
            if fromStation.name.isEmpty {
                fromStation = AidStation(name: "Start", distance: fromStation.distance, services: fromStation.services)
            }
            if toStation.name.isEmpty {
                toStation = AidStation(name: "Station \(index)", distance: toStation.distance, services: toStation.services)
            }
            let segmentDistance = max(0.1, toStation.distance - fromStation.distance)
            let metric = metrics[index] ?? metrics[index - 1] ?? AidStationSegmentMetrics(
                segmentDistanceM: segmentDistance * 1000.0,
                elevationGainM: 0,
                elevationLossM: 0,
                estimatedTimeSeconds: 0,
                averageHeartRate: nil
            )
            
            let raceFraction = totalDistanceKm > 0 ? toStation.distance / totalDistanceKm : 0
            let hrPercent: Double
            if raceFraction <= 0.25 {
                hrPercent = 0.75
            } else if raceFraction <= 0.5 {
                hrPercent = 0.775
            } else {
                hrPercent = 0.80
            }
            
            // Heart rate string - show "Connexion needed" if no provider data
            let heartRateString: String
            if let maxHR = maxHeartRate {
                let targetHR = maxHR * hrPercent
                heartRateString = "\(Int(round(targetHR))) bpm"
                print("   💓 Segment \(index): HR = \(heartRateString) (maxHR: \(maxHR), percent: \(hrPercent))")
            } else {
                heartRateString = "Connexion needed"
                print("   ⚠️ Segment \(index): No maxHR available - showing 'Connexion needed'")
            }
            
            // Calculate adjusted pace - show "Connexion needed" if no provider data
            let estimatedPaceString: String
            let sectionHours: Double
            let durationString: String
            
            if let baseP = basePace {
                let heatMultiplier = 1 + 0.01 * max(0, temperature - 15.0)
                let fatigueMultiplier = 1 + analytics.fatigueRatePerHour * cumulativeHours
                // Hill penalty should be per km, not total for segment
                // 0.5 min per 100m of elevation gain, distributed across segment distance
                let hillPenaltyPerKm = segmentDistance > 0 ? 0.5 * (metric.elevationGainM / segmentDistance / 100.0) : 0
                let adjustedPace = max(3.0, baseP * heatMultiplier * fatigueMultiplier + hillPenaltyPerKm)
                let sectionMinutes = adjustedPace * segmentDistance
                sectionHours = sectionMinutes / 60.0
                cumulativeHours += sectionHours
                durationString = formatDuration(hours: sectionHours)
                estimatedPaceString = formatPace(minutesPerKm: adjustedPace)
            } else {
                // No provider data - use default calculation for duration only
                let defaultPaceMinutesPerKm = 10.0
                let sectionMinutes = defaultPaceMinutesPerKm * segmentDistance
                sectionHours = sectionMinutes / 60.0
                cumulativeHours += sectionHours
                durationString = formatDuration(hours: sectionHours)
                estimatedPaceString = "Connexion needed"
            }
            
            // Use segment's own elevation gain/loss (not cumulative)
            let segmentElevationGain = Int(metric.elevationGainM.rounded())
            let segmentElevationLoss = Int(metric.elevationLossM.rounded())
            
            let effortLevel = effortLevel(for: hrPercent)
            let effortBars = effortBars(for: hrPercent)
            let effortLabel = effortLabel(for: effortLevel)
            
            let segment = PacingSegment(
                from: fromStation.name,
                to: toStation.name,
                fromDistance: fromStation.distance,
                toDistance: toStation.distance,
                segmentDistance: segmentDistance,
                duration: durationString,
                effortLevel: effortLevel,
                effortBars: effortBars,
                heartRate: heartRateString,
                effortLabel: effortLabel,
                estimatedPace: estimatedPaceString,
                elevationGain: segmentElevationGain,
                elevationLoss: segmentElevationLoss
            )
            
            plans.append(SectionPlan(pacingSegment: segment, sectionHours: sectionHours))
        }
        
        return plans
    }
    
    private func buildFuelingStations(
        sectionPlans: [SectionPlan],
        analytics: AthleteAnalytics,
        temperatureC: Double?
    ) -> [FuelingStation] {
        guard !sectionPlans.isEmpty else { return [] }
        let temp = temperatureC ?? 15.0
        let totalHours = sectionPlans.reduce(0) { $0 + $1.sectionHours }
        
        // Glycogen stores: ~600 kcal total, depletes over race duration
        let glycogenTotalKcal = 600.0
        let glycogenPerHour = totalHours > 0 ? glycogenTotalKcal / totalHours : glycogenTotalKcal
        
        // Fat oxidation: ~5 kcal/hour (minimal during high-intensity)
        let fatKcalPerHour = 5.0
        
        // Total calories needed per hour (from workout data or default)
        // Minimum 500 kcal/h to ensure adequate fueling
        let caloriesPerHour = max(analytics.caloriesPerHour, 500.0)
        
        // Carbs needed = Total - Fat - Glycogen
        // Carbs provide 4 kcal per gram
        let carbKcalPerHour = max(0, caloriesPerHour - fatKcalPerHour - glycogenPerHour)
        let carbGramsPerHour = carbKcalPerHour / 4.0
        
        // Water and sodium needs based on temperature and intensity
        // Higher temp = more sweat = more water and sodium needed
        // Intensity affects sweat rate, but we use temperature as proxy
        let (waterPerHour, sodiumPerHour): (Double, Double) = {
            switch temp {
            case ..<15:
                // Cold: Lower sweat rate
                return (400, 500) // 400ml/h water, 500mg/h sodium
            case 15..<22:
                // Moderate: Moderate sweat rate
                return (650, 600) // 650ml/h water, 600mg/h sodium
            case 22..<28:
                // Warm: Higher sweat rate
                return (800, 650) // 800ml/h water, 650mg/h sodium
            default:
                // Hot: Very high sweat rate
                return (900, 700) // 900ml/h water, 700mg/h sodium
            }
        }()
        
        var cumulativeHours: Double = 0
        var stations: [FuelingStation] = []
        for plan in sectionPlans {
            cumulativeHours += plan.sectionHours
            let sectionHours = plan.sectionHours
            let carbGrams = Int(round(max(0, carbGramsPerHour * sectionHours)))
            let sodiumMg = Int(round(sodiumPerHour * sectionHours))
            let waterMl = Int(round(waterPerHour * sectionHours))
            
            let elapsedHours = cumulativeHours
            let elapsedHourInt = Int(elapsedHours)
            let elapsedMinutes = Int(round((elapsedHours - Double(elapsedHourInt)) * 60))
            let elapsedString = "\(elapsedHourInt)h \(elapsedMinutes)m elapsed"
            
            let arrivalHourInt = elapsedHourInt
            let arrivalMinuteInt = elapsedMinutes
            let arrivalTime = String(format: "%02d:%02d", arrivalHourInt, arrivalMinuteInt)
            
            let carbRecommendation = "Aim for ~\(carbGrams)g carbs over this section."
            let sodiumRecommendation = "Pair intake with ~\(sodiumMg)mg sodium."
            let hydrationNote = "Target about \(waterMl) ml this leg (~\(Int(round(waterPerHour))) ml/h)."
            
            guard !plan.pacingSegment.to.lowercased().contains("finish") else { continue }
            
            stations.append(FuelingStation(
                name: plan.pacingSegment.to,
                time: arrivalTime,
                elapsed: elapsedString,
                carbs: carbGrams,
                sodium: sodiumMg,
                water: waterMl,
                recommendations: [carbRecommendation, sodiumRecommendation],
                hydrationNote: hydrationNote
            ))
        }
        return stations
    }
    
    private func effortLevel(for hrPercent: Double) -> PacingSegment.EffortLevel {
        switch hrPercent {
        case ..<0.75:
            return .conservative
        case ..<0.78:
            return .build
        case ..<0.82:
            return .moderate
        default:
            return .hard
        }
    }
    
    private func effortLabel(for level: PacingSegment.EffortLevel) -> String {
        switch level {
        case .conservative: return "Conservative Start"
        case .build: return "Steady Build"
        case .moderate: return "Focused Effort"
        case .hard: return "Push to Finish"
        }
    }
    
    private func effortBars(for hrPercent: Double) -> [PacingSegment.EffortBar] {
        switch hrPercent {
        case ..<0.75:
            return Array(repeating: .green, count: 7) + Array(repeating: .grey, count: 3)
        case ..<0.78:
            return Array(repeating: .green, count: 6) + Array(repeating: .orange, count: 2) + Array(repeating: .grey, count: 2)
        case ..<0.82:
            return Array(repeating: .green, count: 5) + Array(repeating: .orange, count: 3) + Array(repeating: .grey, count: 2)
        default:
            return Array(repeating: .orange, count: 6) + Array(repeating: .grey, count: 4)
        }
    }
    
    private func formatDuration(hours: Double) -> String {
        let totalMinutes = Int(round(hours * 60))
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return "\(h)h \(m)m"
    }
    
    private func formatPace(minutesPerKm: Double) -> String {
        let totalSeconds = Int(round(minutesPerKm * 60))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }
    
    private func buildAthleteAnalytics(userId: UUID, workouts: [WorkoutSummary], healthMetric: HealthMetrics?) async -> AthleteAnalytics {
        // If no workouts from provider, return nil for basePace and maxHeartRate
        guard !workouts.isEmpty else {
            print("⚠️ buildAthleteAnalytics: No workouts found - using defaults")
            return AthleteAnalytics(
                averageHeartRate: nil,
                maxHeartRate: nil,
                basePaceMinutesPerKilometer: nil,
                fatigueRatePerHour: 0.03,
                caloriesPerHour: 600.0,
                weightKg: healthMetric?.weightKg.map { NSDecimalNumber(decimal: $0).doubleValue }
            )
        }
        
        print("📊 buildAthleteAnalytics: Processing \(workouts.count) workouts")
        
        let sortedWorkouts = workouts.sorted { ($0.distanceM ?? 0) > ($1.distanceM ?? 0) }
        let focusCount = max(1, Int(Double(sortedWorkouts.count) * 0.2))
        let focusWorkouts = Array(sortedWorkouts.prefix(focusCount))
        
        // Calculate average HR from workouts
        let averageHR = focusWorkouts.compactMap { workout -> Double? in
            guard let hr = workout.avgHR else { return nil }
            return Double(hr)
        }.averageValue()
        
        // Calculate max HR - use actual maxHR from workouts if available, otherwise estimate from averageHR
        let maxHR: Double? = {
            // First, try to get actual maxHR from workouts
            let actualMaxHRs = focusWorkouts.compactMap { workout -> Double? in
                workout.maxHR.map { Double($0) }
            }
            
            if let actualMax = actualMaxHRs.max() {
                // Use the highest maxHR from workouts
                return actualMax
            }
            
            // Fallback: Estimate maxHR from averageHR
            // Formula: maxHR ≈ averageHR / 0.75 (assuming average is 75% of max during training)
            // More accurate: maxHR ≈ averageHR / 0.70-0.80 depending on effort
            // Using 0.75 as middle ground for moderate effort training
            return averageHR.map { ($0 / 0.75) }
        }()
        
        // Only calculate basePace if we have valid workout data
        let basePace = focusWorkouts.compactMap { workout -> Double? in
            guard let distance = workout.distanceM, distance > 0,
                  let elapsed = workout.elapsedSeconds, elapsed > 0 else { return nil }
            let paceSecondsPerKm = Double(elapsed) / (distance / 1000.0)
            return paceSecondsPerKm / 60.0
        }.averageValue()
        
        let weightKg = healthMetric?.weightKg.map { NSDecimalNumber(decimal: $0).doubleValue }
        let referenceWeight = weightKg ?? 70.0
        
        // Calculate calories per hour from actual workout data
        let caloriesPerHour = focusWorkouts.compactMap { workout -> Double? in
            guard let elapsed = workout.elapsedSeconds, elapsed > 0 else { return nil }
            let hours = Double(elapsed) / 3600.0
            guard hours > 0 else { return nil }
            if let calories = workout.calories, calories > 0 {
                return Double(calories) / hours
            }
            guard let distance = workout.distanceM, distance > 0 else { return nil }
            let distanceKm = distance / 1000.0
            // Improved calorie estimation: accounts for elevation and intensity
            // Base: 1.036 kcal per km per kg (flat running)
            // Add 0.1 kcal per meter of elevation gain
            let elevationGain = 0.0 // TODO: Add elevation gain to WorkoutSummary if available
            let estimatedCalories = (distanceKm * referenceWeight * 1.036) + (elevationGain * referenceWeight * 0.1)
            return estimatedCalories / hours
        }.averageValue() ?? 600.0
        
        var fatigueRate = 0.03
        if let longestWorkout = sortedWorkouts.first,
           let fatigue = await calculateFatigueCoefficient(workout: longestWorkout) {
            fatigueRate = max(0.015, min(fatigue, 0.08))
        }
        
        let result = AthleteAnalytics(
            averageHeartRate: averageHR,
            maxHeartRate: maxHR,
            basePaceMinutesPerKilometer: basePace,
            fatigueRatePerHour: fatigueRate,
            caloriesPerHour: caloriesPerHour,
            weightKg: weightKg
        )
        
        print("✅ buildAthleteAnalytics: Final results:")
        print("   averageHR: \(averageHR?.description ?? "nil") bpm")
        print("   maxHR: \(maxHR?.description ?? "nil") bpm")
        print("   basePace: \(basePace?.description ?? "nil") min/km")
        print("   caloriesPerHour: \(caloriesPerHour) kcal/h")
        print("   fatigueRate: \(fatigueRate) per hour")
        
        return result
    }
    
    private func calculateFatigueCoefficient(workout: WorkoutSummary) async -> Double? {
        guard let samples = try? await SupabaseService.fetchSamples(workoutId: workout.id),
              !samples.isEmpty else {
            return nil
        }
        
        var paceByHour: [Int: [Double]] = [:]
        for sample in samples {
            guard let pace = sample.paceSecondsPerKm, pace > 0 else { continue }
            let hour = max(0, sample.timeOffsetSeconds / 3600)
            paceByHour[hour, default: []].append(Double(pace) / 60.0)
        }
        
        let orderedHours = paceByHour.keys.sorted()
        guard orderedHours.count >= 2,
              let baselinePaces = paceByHour[orderedHours.first!],
              let baseline = baselinePaces.averageValue(),
              baseline > 0 else { return nil }
        
        guard let lastPaces = paceByHour[orderedHours.last!],
              let last = lastPaces.averageValue() else { return nil }
        
        let hoursElapsed = Double(orderedHours.last! - orderedHours.first!)
        guard hoursElapsed > 0 else { return nil }
        
        let relativeChange = max(0, (last - baseline) / baseline)
        return relativeChange / hoursElapsed
    }
    
    private func deleteRacePlan(_ plan: RacePlanSummary) async {
        guard let userId = await resolveUserId() else { return }
        await MainActor.run { isDeletingRace = true }
        do {
            try await SupabaseService.deleteRacePlan(racePlanId: plan.id)
            await RacePlanListCache.shared.remove(planId: plan.id, for: userId)
            await RacePlanDetailCache.shared.remove(for: plan.id)
            await loadRacePlans(forceRefresh: true)
        } catch {
            print("❌ Error deleting race plan: \(error)")
            ErrorManager.shared.showError(error, title: "Failed to Delete Race")
        }
        await MainActor.run { isDeletingRace = false }
    }
    
    // MARK: - PDF Generation
    
    @MainActor
    private func syncWithDevice() async {
        guard let provider = connectedProvider?.lowercased() else {
            print("⚠️ No provider connected")
            ErrorManager.shared.showError(
                NSError(domain: "HYKA", code: 1, userInfo: [NSLocalizedDescriptionKey: "No device connected. Please connect a device first."]),
                title: "Sync Failed"
            )
            return
        }
        
        guard let userId = await resolveUserId() else {
            print("⚠️ No user ID available")
            ErrorManager.shared.showError(
                NSError(domain: "HYKA", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]),
                title: "Sync Failed"
            )
            return
        }
        
        isSyncingDevice = true
        
        do {
            print("🔄 Triggering historical backfill for \(provider)...")
            
            if provider == "garmin" {
                // Trigger Garmin backfill via Edge Function
                // Backfill will request historical data in 30-day chunks
                // Garmin will send webhooks as activities are processed
                try await triggerGarminBackfill(userId: userId)
                print("✅ Garmin backfill triggered - activities will sync via webhooks")
            } else {
                // For other providers (Polar, Coros, Suunto), use the old client-side approach
                print("🔄 Fetching activities for \(provider) (client-side)...")
                
                let connections = try await SupabaseService.fetchOAuthConnections(userId: userId)
                guard let connection = connections.first(where: { $0.provider.lowercased() == provider }) else {
                    throw NSError(domain: "HYKA", code: 1, userInfo: [NSLocalizedDescriptionKey: "No OAuth connection found for \(provider)"])
                }
                
                let service = WorkoutDataFetchingService()
                // Fetch last 90 days - use 'after' parameter with 90 days ago
                let afterDate = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
                
                let count = try await service.fetchAndStoreWorkouts(
                    userId: userId,
                    provider: provider,
                    accessToken: connection.accessToken,
                    tokenSecret: nil, // OAuth 2.0 providers don't use token secret
                    after: afterDate,
                    useIncrementalSync: false // Full historical sync
                )
                
                print("✅ Fetched \(count) activities for \(provider)")
                print("   Synced \(count) activities from \(provider.capitalized)")
            }
        } catch {
            print("❌ Error syncing with device: \(error)")
            await MainActor.run {
                ErrorManager.shared.showError(error, title: "Sync Failed")
            }
        }
        
        isSyncingDevice = false
    }
    
    /// Trigger Garmin historical backfill via Edge Function
    /// The Edge Function will:
    /// 1. Look up the connection and get connected_at
    /// 2. Calculate date ranges from connection date forward
    /// 3. Request backfill in 29-day chunks
    /// 
    /// We let the Edge Function handle all date calculations to avoid RLS issues
    private func triggerGarminBackfill(userId: UUID) async throws {
        let edgeFunctionURL = URL(string: Config.garminActivityBackfillURL)!
        let supabaseAnonKey = Config.supabaseAnonKey
        
        // Use Supabase client to query garmin_connections (bypasses RLS with authenticated user)
        // If that fails, let Edge Function handle it
        var connectionDate: Date?
        
        do {
            let response = try await Supa.client
                .from("garmin_connections")
                .select("connected_at")
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .single()
                .execute()
            
            if let data = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
               let connectedAtString = data["connected_at"] as? String {
                
                let timestampFormatter = ISO8601DateFormatter()
                timestampFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                if let date = timestampFormatter.date(from: connectedAtString) {
                    connectionDate = date
                    print("📅 Garmin connection date: \(date)")
                }
            }
        } catch {
            print("⚠️ Could not fetch connection date via Supabase client: \(error)")
            print("   Edge Function will handle date calculation")
        }
        
        // If we have connection date, calculate chunks client-side
        // Otherwise, let Edge Function handle it (it has service role access)
        if let connectedAt = connectionDate {
            // According to Garmin docs, backfill can retrieve historic data from before
            // "user's registration with the partner program"
            // So we'll request last 90 days from now (going backward), which may include
            // data from before connection date
            // Use 29-day chunks to avoid "exceeds 30 days" error (Garmin limit is 30 days)
            let now = Date()
            let calendar = Calendar.current
            
            // Start from 90 days ago, work forward in 29-day chunks to now
            // This will include data from before connection if Garmin allows it
            let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: now) ?? now
            var currentStart = ninetyDaysAgo
            var chunkNumber = 1
            var hasMoreChunks = true
            
            while hasMoreChunks && currentStart < now {
                // Calculate end date (29 days after start, or now if sooner)
                let endDate = min(calendar.date(byAdding: .day, value: 29, to: currentStart) ?? now, now)
                
                // If start and end are the same (or very close), we're done
                if endDate <= currentStart || endDate.timeIntervalSince(currentStart) < 86400 { // Less than 1 day
                    hasMoreChunks = false
                    break
                }
                
                let startTimeSeconds = Int(currentStart.timeIntervalSince1970)
                let endTimeSeconds = Int(endDate.timeIntervalSince1970)
                
                var request = URLRequest(url: edgeFunctionURL)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
                request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
                
                let requestBody: [String: Any] = [
                    "user_id": userId.uuidString,
                    "summary_start_time_seconds": startTimeSeconds,
                    "summary_end_time_seconds": endTimeSeconds
                ]
                
                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .short
                dateFormatter.timeStyle = .none
                
                print("🔄 Requesting backfill chunk \(chunkNumber): \(dateFormatter.string(from: currentStart)) to \(dateFormatter.string(from: endDate))")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "HYKA", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                }
                
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 409 {
                    // 200 = Success, 409 = Duplicate (already requested) - both are fine
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("✅ Backfill chunk \(chunkNumber): \(json["message"] as? String ?? "Requested")")
                    }
                } else {
                    let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                    print("⚠️ Backfill chunk \(chunkNumber) failed: HTTP \(httpResponse.statusCode) - \(errorText)")
                    // Continue with other chunks even if one fails
                }
                
                // Move to next chunk
                currentStart = calendar.date(byAdding: .day, value: 30, to: currentStart) ?? endDate
                chunkNumber += 1
                
                // Limit to max 10 chunks to avoid infinite loops
                if chunkNumber > 10 {
                    hasMoreChunks = false
                }
                
                // Small delay between requests to avoid rate limiting
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
            
            print("✅ All backfill requests submitted - Garmin will process and send webhooks")
        } else {
            // Fallback: Let Edge Function calculate dates (it has service role access)
            print("🔄 Requesting backfill - Edge Function will calculate date ranges")
            
            var request = URLRequest(url: edgeFunctionURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
            request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
            
            let requestBody: [String: Any] = [
                "user_id": userId.uuidString
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "HYKA", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }
            
            if httpResponse.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let message = json["message"] as? String ?? "Requested"
                    let success = json["success"] as? Bool ?? true
                    
                    if success {
                        print("✅ Backfill requested: \(message)")
                    } else {
                        // Date range too small - this is expected for very recent connections
                        print("ℹ️ \(message)")
                        if let daysSinceConnection = json["days_since_connection"] as? String {
                            print("   Connection is \(daysSinceConnection) days old")
                        }
                        // Don't throw error - this is expected behavior
                    }
                }
            } else if httpResponse.statusCode == 409 {
                // Duplicate request - this is fine
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("ℹ️ \(json["message"] as? String ?? "Duplicate backfill request")")
                }
            } else {
                let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("⚠️ Backfill request failed: HTTP \(httpResponse.statusCode) - \(errorText)")
                throw NSError(domain: "HYKA", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorText])
            }
        }
    }
    
    private func generateRaceStrategyPDF() async {
        guard let currentRace = selectedRace else { return }
        
        // Create a view that represents the race strategy card
        let strategyCardView = RaceStrategyCardPDFView(
            raceName: currentRace.title,
            raceDate: formattedMetadataDate(),
            distance: formattedRaceDistance(),
            elevationGain: formattedMetadataElevation(),
            estimatedTime: formattedEstimatedDuration(),
            notes: raceMetadata?.notes?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        )
        
        // Render the view to PDF using UIGraphicsPDFRenderer
        let pdfData = await renderViewToPDF(strategyCardView)
        
        guard let pdfData = pdfData else {
            ErrorManager.shared.showError(NSError(domain: "PDFGeneration", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate PDF"]), title: "PDF Generation Failed")
            return
        }
        
        // Save to temporary file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(currentRace.title.replacingOccurrences(of: " ", with: "_"))_Race_Strategy.pdf")
        
        do {
            try pdfData.write(to: tempURL)
            pdfURL = tempURL
            showShareSheet = true
        } catch {
            ErrorManager.shared.showError(error, title: "Failed to Save PDF")
        }
    }
    
    @MainActor
    private func renderViewToPDF<V: View>(_ view: V) -> Data? {
        let hostingController = UIHostingController(rootView: view)
        hostingController.view.backgroundColor = .white
        
        // A4 size in points (595 x 842 points at 72 DPI)
        let pageSize = CGSize(width: 595, height: 842)
        hostingController.view.frame = CGRect(origin: .zero, size: pageSize)
        
        // Add to a window to ensure proper layout
        let window = UIWindow(frame: CGRect(origin: .zero, size: pageSize))
        window.rootViewController = hostingController
        window.isHidden = false
        
        // Force layout and rendering
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        
        // Give the view a moment to render
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: format)
        
        let pdfData = renderer.pdfData { context in
            context.beginPage()
            
            // Render the view's layer to the PDF context
            hostingController.view.layer.render(in: context.cgContext)
        }
        
        // Clean up
        window.isHidden = true
        window.rootViewController = nil
        
        return pdfData
    }
}

// MARK: - Edit Race Modal

struct EditRaceModal: View {
    @Binding var raceName: String
    @Binding var raceDate: Date
    let onSave: () -> Void
    let onCancel: () -> Void
    @FocusState private var nameFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: HYKATheme.spacingXL) {
                VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
                    Text("Race Name")
                        .font(HYKATheme.label)
                        .foregroundColor(HYKATheme.Light.mutedForeground)
                    
                    TextField("Enter race name", text: $raceName)
                        .font(HYKATheme.body)
                        .foregroundColor(HYKATheme.Light.foreground)
                        .padding(HYKATheme.spacingM)
                        .background(HYKATheme.Light.card)
                        .cornerRadius(HYKATheme.cornerRadiusM)
                        .overlay(
                            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                                .stroke(HYKATheme.Light.border, lineWidth: 1)
                        )
                        .focused($nameFieldFocused)
                }
                
                VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
                    Text("Race Date")
                        .font(HYKATheme.label)
                        .foregroundColor(HYKATheme.Light.mutedForeground)
                    
                    DatePicker("", selection: $raceDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .padding(HYKATheme.spacingM)
                        .background(HYKATheme.Light.card)
                        .cornerRadius(HYKATheme.cornerRadiusM)
                        .overlay(
                            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                                .stroke(HYKATheme.Light.border, lineWidth: 1)
                        )
                }
                
                Spacer()
                
                HStack(spacing: HYKATheme.spacingM) {
                    Button(action: {
                        nameFieldFocused = false
                        onCancel()
                    }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(HYKATheme.Light.mutedForeground)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(HYKATheme.Light.background)
                            .cornerRadius(HYKATheme.cornerRadiusM)
                    }
                    
                    Button(action: {
                        if !raceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            nameFieldFocused = false
                            onSave()
                        }
                    }) {
                        Text("Save")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(raceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.hykaPurple)
                            .cornerRadius(HYKATheme.cornerRadiusM)
                    }
                    .disabled(raceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.bottom, HYKATheme.spacingL)
            }
            .padding(HYKATheme.spacingXXL)
            .background(HYKATheme.Light.card)
            .navigationTitle("Edit Race")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    nameFieldFocused = true
                }
            }
        }
        .background(HYKATheme.Light.card)
        .keyboardDoneToolbar()
    }
}

// MARK: - Location Picker Modal

struct LocationPickerModal: View {
    @Binding var location: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @State private var searchText: String = ""
    @State private var selectedLocation: String = ""
    @FocusState private var searchFieldFocused: Bool
    
    // Comprehensive list of locations: European countries, US states, and popular race locations
    private let popularLocations: [String] = {
        var locations: [String] = []
        
        // Popular Ultra Running Race Locations
        locations.append(contentsOf: [
            "Chamonix, France",
            "Chamonix-Mont-Blanc, France",
            "Courmayeur, Italy",
            "Zermatt, Switzerland",
            "Saint-Gervais-les-Bains, France",
            "Les Houches, France",
            "Verbier, Switzerland",
            "Annecy, France",
            "Geneva, Switzerland",
            "Lyon, France",
            "Grenoble, France",
            "Moab, Utah, USA",
            "Leadville, Colorado, USA",
            "Hardrock, Colorado, USA",
            "Western States, California, USA",
            "Squamish, British Columbia, Canada"
        ])
        
        // European Countries - Major Cities
        locations.append(contentsOf: [
            // France
            "Paris, France", "Lyon, France", "Marseille, France", "Toulouse, France", "Nice, France",
            "Nantes, France", "Strasbourg, France", "Montpellier, France", "Bordeaux, France", "Lille, France",
            "Rennes, France", "Reims, France", "Le Havre, France", "Saint-Étienne, France", "Toulon, France",
            "Grenoble, France", "Dijon, France", "Angers, France", "Nîmes, France", "Villeurbanne, France",
            // Italy
            "Rome, Italy", "Milan, Italy", "Naples, Italy", "Turin, Italy", "Palermo, Italy",
            "Genoa, Italy", "Bologna, Italy", "Florence, Italy", "Bari, Italy", "Catania, Italy",
            "Venice, Italy", "Verona, Italy", "Messina, Italy", "Padua, Italy", "Trieste, Italy",
            // Spain
            "Madrid, Spain", "Barcelona, Spain", "Valencia, Spain", "Seville, Spain", "Zaragoza, Spain",
            "Málaga, Spain", "Murcia, Spain", "Palma, Spain", "Las Palmas, Spain", "Bilbao, Spain",
            "Alicante, Spain", "Córdoba, Spain", "Valladolid, Spain", "Vigo, Spain", "Gijón, Spain",
            // Germany
            "Berlin, Germany", "Munich, Germany", "Hamburg, Germany", "Cologne, Germany", "Frankfurt, Germany",
            "Stuttgart, Germany", "Düsseldorf, Germany", "Dortmund, Germany", "Essen, Germany", "Leipzig, Germany",
            "Bremen, Germany", "Dresden, Germany", "Hannover, Germany", "Nuremberg, Germany", "Duisburg, Germany",
            // United Kingdom
            "London, United Kingdom", "Birmingham, United Kingdom", "Manchester, United Kingdom", "Glasgow, United Kingdom",
            "Liverpool, United Kingdom", "Leeds, United Kingdom", "Sheffield, United Kingdom", "Edinburgh, United Kingdom",
            "Bristol, United Kingdom", "Cardiff, United Kingdom", "Belfast, United Kingdom", "Newcastle, United Kingdom",
            // Switzerland
            "Zurich, Switzerland", "Geneva, Switzerland", "Basel, Switzerland", "Bern, Switzerland", "Lausanne, Switzerland",
            "Winterthur, Switzerland", "Lucerne, Switzerland", "St. Gallen, Switzerland", "Lugano, Switzerland", "Biel, Switzerland",
            // Austria
            "Vienna, Austria", "Graz, Austria", "Linz, Austria", "Salzburg, Austria", "Innsbruck, Austria",
            "Klagenfurt, Austria", "Villach, Austria", "Wels, Austria", "Sankt Pölten, Austria", "Dornbirn, Austria",
            // Netherlands
            "Amsterdam, Netherlands", "Rotterdam, Netherlands", "The Hague, Netherlands", "Utrecht, Netherlands", "Eindhoven, Netherlands",
            "Groningen, Netherlands", "Tilburg, Netherlands", "Almere, Netherlands", "Breda, Netherlands", "Nijmegen, Netherlands",
            // Belgium
            "Brussels, Belgium", "Antwerp, Belgium", "Ghent, Belgium", "Charleroi, Belgium", "Liège, Belgium",
            "Bruges, Belgium", "Namur, Belgium", "Leuven, Belgium", "Mons, Belgium", "Aalst, Belgium",
            // Portugal
            "Lisbon, Portugal", "Porto, Portugal", "Vila Nova de Gaia, Portugal", "Amadora, Portugal", "Braga, Portugal",
            "Funchal, Portugal", "Coimbra, Portugal", "Setúbal, Portugal", "Almada, Portugal", "Agualva-Cacém, Portugal",
            // Greece
            "Athens, Greece", "Thessaloniki, Greece", "Patras, Greece", "Piraeus, Greece", "Larissa, Greece",
            "Heraklion, Greece", "Peristeri, Greece", "Kallithea, Greece", "Acharnes, Greece", "Kalamaria, Greece",
            // Poland
            "Warsaw, Poland", "Kraków, Poland", "Łódź, Poland", "Wrocław, Poland", "Poznań, Poland",
            "Gdańsk, Poland", "Szczecin, Poland", "Bydgoszcz, Poland", "Lublin, Poland", "Katowice, Poland",
            // Czech Republic
            "Prague, Czech Republic", "Brno, Czech Republic", "Ostrava, Czech Republic", "Plzeň, Czech Republic", "Liberec, Czech Republic",
            "Olomouc, Czech Republic", "Ústí nad Labem, Czech Republic", "České Budějovice, Czech Republic", "Hradec Králové, Czech Republic", "Pardubice, Czech Republic",
            // Sweden
            "Stockholm, Sweden", "Gothenburg, Sweden", "Malmö, Sweden", "Uppsala, Sweden", "Västerås, Sweden",
            "Örebro, Sweden", "Linköping, Sweden", "Helsingborg, Sweden", "Jönköping, Sweden", "Norrköping, Sweden",
            // Norway
            "Oslo, Norway", "Bergen, Norway", "Trondheim, Norway", "Stavanger, Norway", "Bærum, Norway",
            "Kristiansand, Norway", "Fredrikstad, Norway", "Tromsø, Norway", "Sandnes, Norway", "Asker, Norway",
            // Denmark
            "Copenhagen, Denmark", "Aarhus, Denmark", "Odense, Denmark", "Aalborg, Denmark", "Esbjerg, Denmark",
            "Randers, Denmark", "Kolding, Denmark", "Horsens, Denmark", "Vejle, Denmark", "Roskilde, Denmark",
            // Finland
            "Helsinki, Finland", "Espoo, Finland", "Tampere, Finland", "Vantaa, Finland", "Oulu, Finland",
            "Turku, Finland", "Jyväskylä, Finland", "Lahti, Finland", "Kuopio, Finland", "Pori, Finland",
            // Ireland
            "Dublin, Ireland", "Cork, Ireland", "Limerick, Ireland", "Galway, Ireland", "Waterford, Ireland",
            "Drogheda, Ireland", "Dundalk, Ireland", "Swords, Ireland", "Bray, Ireland", "Navan, Ireland",
            // Other European Countries
            "Reykjavik, Iceland", "Luxembourg, Luxembourg", "Monaco, Monaco", "Andorra la Vella, Andorra",
            "San Marino, San Marino", "Vaduz, Liechtenstein", "Valletta, Malta", "Nicosia, Cyprus",
            "Bucharest, Romania", "Budapest, Hungary", "Sofia, Bulgaria", "Zagreb, Croatia",
            "Belgrade, Serbia", "Ljubljana, Slovenia", "Bratislava, Slovakia", "Tallinn, Estonia",
            "Riga, Latvia", "Vilnius, Lithuania", "Warsaw, Poland", "Kiev, Ukraine"
        ])
        
        // US States - Major Cities
        locations.append(contentsOf: [
            // Alabama
            "Birmingham, Alabama, USA", "Montgomery, Alabama, USA", "Mobile, Alabama, USA", "Huntsville, Alabama, USA",
            // Alaska
            "Anchorage, Alaska, USA", "Fairbanks, Alaska, USA", "Juneau, Alaska, USA",
            // Arizona
            "Phoenix, Arizona, USA", "Tucson, Arizona, USA", "Mesa, Arizona, USA", "Chandler, Arizona, USA", "Scottsdale, Arizona, USA",
            // Arkansas
            "Little Rock, Arkansas, USA", "Fayetteville, Arkansas, USA", "Fort Smith, Arkansas, USA",
            // California
            "Los Angeles, California, USA", "San Diego, California, USA", "San Jose, California, USA", "San Francisco, California, USA",
            "Fresno, California, USA", "Sacramento, California, USA", "Long Beach, California, USA", "Oakland, California, USA",
            "Bakersfield, California, USA", "Anaheim, California, USA", "Santa Ana, California, USA", "Riverside, California, USA",
            "Stockton, California, USA", "Irvine, California, USA", "Chula Vista, California, USA", "Fremont, California, USA",
            "San Bernardino, California, USA", "Modesto, California, USA", "Fontana, California, USA", "Oxnard, California, USA",
            // Colorado
            "Denver, Colorado, USA", "Colorado Springs, Colorado, USA", "Aurora, Colorado, USA", "Fort Collins, Colorado, USA",
            "Lakewood, Colorado, USA", "Thornton, Colorado, USA", "Arvada, Colorado, USA", "Westminster, Colorado, USA",
            // Connecticut
            "Bridgeport, Connecticut, USA", "New Haven, Connecticut, USA", "Hartford, Connecticut, USA", "Stamford, Connecticut, USA",
            // Delaware
            "Wilmington, Delaware, USA", "Dover, Delaware, USA",
            // Florida
            "Jacksonville, Florida, USA", "Miami, Florida, USA", "Tampa, Florida, USA", "Orlando, Florida, USA",
            "St. Petersburg, Florida, USA", "Hialeah, Florida, USA", "Tallahassee, Florida, USA", "Fort Lauderdale, Florida, USA",
            "Port St. Lucie, Florida, USA", "Cape Coral, Florida, USA", "Pembroke Pines, Florida, USA", "Hollywood, Florida, USA",
            // Georgia
            "Atlanta, Georgia, USA", "Augusta, Georgia, USA", "Columbus, Georgia, USA", "Savannah, Georgia, USA",
            "Athens, Georgia, USA", "Sandy Springs, Georgia, USA", "Roswell, Georgia, USA", "Macon, Georgia, USA",
            // Hawaii
            "Honolulu, Hawaii, USA", "Hilo, Hawaii, USA", "Kailua, Hawaii, USA",
            // Idaho
            "Boise, Idaho, USA", "Nampa, Idaho, USA", "Meridian, Idaho, USA",
            // Illinois
            "Chicago, Illinois, USA", "Aurora, Illinois, USA", "Naperville, Illinois, USA", "Joliet, Illinois, USA",
            "Rockford, Illinois, USA", "Elgin, Illinois, USA", "Peoria, Illinois, USA", "Champaign, Illinois, USA",
            // Indiana
            "Indianapolis, Indiana, USA", "Fort Wayne, Indiana, USA", "Evansville, Indiana, USA", "South Bend, Indiana, USA",
            // Iowa
            "Des Moines, Iowa, USA", "Cedar Rapids, Iowa, USA", "Davenport, Iowa, USA", "Sioux City, Iowa, USA",
            // Kansas
            "Wichita, Kansas, USA", "Overland Park, Kansas, USA", "Kansas City, Kansas, USA", "Olathe, Kansas, USA",
            // Kentucky
            "Louisville, Kentucky, USA", "Lexington, Kentucky, USA", "Bowling Green, Kentucky, USA", "Owensboro, Kentucky, USA",
            // Louisiana
            "New Orleans, Louisiana, USA", "Baton Rouge, Louisiana, USA", "Shreveport, Louisiana, USA", "Lafayette, Louisiana, USA",
            // Maine
            "Portland, Maine, USA", "Lewiston, Maine, USA", "Bangor, Maine, USA",
            // Maryland
            "Baltimore, Maryland, USA", "Frederick, Maryland, USA", "Rockville, Maryland, USA", "Gaithersburg, Maryland, USA",
            // Massachusetts
            "Boston, Massachusetts, USA", "Worcester, Massachusetts, USA", "Springfield, Massachusetts, USA", "Lowell, Massachusetts, USA",
            "Cambridge, Massachusetts, USA", "New Bedford, Massachusetts, USA", "Brockton, Massachusetts, USA", "Quincy, Massachusetts, USA",
            // Michigan
            "Detroit, Michigan, USA", "Grand Rapids, Michigan, USA", "Warren, Michigan, USA", "Sterling Heights, Michigan, USA",
            "Lansing, Michigan, USA", "Ann Arbor, Michigan, USA", "Flint, Michigan, USA", "Dearborn, Michigan, USA",
            // Minnesota
            "Minneapolis, Minnesota, USA", "St. Paul, Minnesota, USA", "Rochester, Minnesota, USA", "Duluth, Minnesota, USA",
            // Mississippi
            "Jackson, Mississippi, USA", "Gulfport, Mississippi, USA", "Southaven, Mississippi, USA", "Hattiesburg, Mississippi, USA",
            // Missouri
            "Kansas City, Missouri, USA", "St. Louis, Missouri, USA", "Springfield, Missouri, USA", "Columbia, Missouri, USA",
            // Montana
            "Billings, Montana, USA", "Missoula, Montana, USA", "Great Falls, Montana, USA", "Bozeman, Montana, USA",
            // Nebraska
            "Omaha, Nebraska, USA", "Lincoln, Nebraska, USA", "Bellevue, Nebraska, USA",
            // Nevada
            "Las Vegas, Nevada, USA", "Henderson, Nevada, USA", "Reno, Nevada, USA", "North Las Vegas, Nevada, USA",
            // New Hampshire
            "Manchester, New Hampshire, USA", "Nashua, New Hampshire, USA", "Concord, New Hampshire, USA",
            // New Jersey
            "Newark, New Jersey, USA", "Jersey City, New Jersey, USA", "Paterson, New Jersey, USA", "Elizabeth, New Jersey, USA",
            // New Mexico
            "Albuquerque, New Mexico, USA", "Las Cruces, New Mexico, USA", "Rio Rancho, New Mexico, USA", "Santa Fe, New Mexico, USA",
            // New York
            "New York, New York, USA", "Buffalo, New York, USA", "Rochester, New York, USA", "Yonkers, New York, USA",
            "Syracuse, New York, USA", "Albany, New York, USA", "New Rochelle, New York, USA", "Mount Vernon, New York, USA",
            // North Carolina
            "Charlotte, North Carolina, USA", "Raleigh, North Carolina, USA", "Greensboro, North Carolina, USA", "Durham, North Carolina, USA",
            "Winston-Salem, North Carolina, USA", "Fayetteville, North Carolina, USA", "Cary, North Carolina, USA", "Wilmington, North Carolina, USA",
            // North Dakota
            "Fargo, North Dakota, USA", "Bismarck, North Dakota, USA", "Grand Forks, North Dakota, USA",
            // Ohio
            "Columbus, Ohio, USA", "Cleveland, Ohio, USA", "Cincinnati, Ohio, USA", "Toledo, Ohio, USA",
            "Akron, Ohio, USA", "Dayton, Ohio, USA", "Parma, Ohio, USA", "Canton, Ohio, USA",
            // Oklahoma
            "Oklahoma City, Oklahoma, USA", "Tulsa, Oklahoma, USA", "Norman, Oklahoma, USA", "Broken Arrow, Oklahoma, USA",
            // Oregon
            "Portland, Oregon, USA", "Eugene, Oregon, USA", "Salem, Oregon, USA", "Gresham, Oregon, USA",
            // Pennsylvania
            "Philadelphia, Pennsylvania, USA", "Pittsburgh, Pennsylvania, USA", "Allentown, Pennsylvania, USA", "Erie, Pennsylvania, USA",
            "Reading, Pennsylvania, USA", "Scranton, Pennsylvania, USA", "Bethlehem, Pennsylvania, USA", "Lancaster, Pennsylvania, USA",
            // Rhode Island
            "Providence, Rhode Island, USA", "Warwick, Rhode Island, USA", "Cranston, Rhode Island, USA",
            // South Carolina
            "Charleston, South Carolina, USA", "Columbia, South Carolina, USA", "North Charleston, South Carolina, USA", "Mount Pleasant, South Carolina, USA",
            // South Dakota
            "Sioux Falls, South Dakota, USA", "Rapid City, South Dakota, USA", "Aberdeen, South Dakota, USA",
            // Tennessee
            "Nashville, Tennessee, USA", "Memphis, Tennessee, USA", "Knoxville, Tennessee, USA", "Chattanooga, Tennessee, USA",
            // Texas
            "Houston, Texas, USA", "San Antonio, Texas, USA", "Dallas, Texas, USA", "Austin, Texas, USA",
            "Fort Worth, Texas, USA", "El Paso, Texas, USA", "Arlington, Texas, USA", "Corpus Christi, Texas, USA",
            "Plano, Texas, USA", "Laredo, Texas, USA", "Lubbock, Texas, USA", "Garland, Texas, USA",
            "Irving, Texas, USA", "Amarillo, Texas, USA", "Grand Prairie, Texas, USA", "Brownsville, Texas, USA",
            // Utah
            "Salt Lake City, Utah, USA", "West Valley City, Utah, USA", "Provo, Utah, USA", "West Jordan, Utah, USA",
            // Vermont
            "Burlington, Vermont, USA", "Essex, Vermont, USA", "South Burlington, Vermont, USA",
            // Virginia
            "Virginia Beach, Virginia, USA", "Norfolk, Virginia, USA", "Chesapeake, Virginia, USA", "Richmond, Virginia, USA",
            "Newport News, Virginia, USA", "Alexandria, Virginia, USA", "Hampton, Virginia, USA", "Portsmouth, Virginia, USA",
            // Washington
            "Seattle, Washington, USA", "Spokane, Washington, USA", "Tacoma, Washington, USA", "Vancouver, Washington, USA",
            "Bellevue, Washington, USA", "Kent, Washington, USA", "Everett, Washington, USA", "Renton, Washington, USA",
            // West Virginia
            "Charleston, West Virginia, USA", "Huntington, West Virginia, USA", "Parkersburg, West Virginia, USA",
            // Wisconsin
            "Milwaukee, Wisconsin, USA", "Madison, Wisconsin, USA", "Green Bay, Wisconsin, USA", "Kenosha, Wisconsin, USA",
            // Wyoming
            "Cheyenne, Wyoming, USA", "Casper, Wyoming, USA", "Laramie, Wyoming, USA"
        ])
        
        // Remove duplicates and sort
        return Array(Set(locations)).sorted()
    }()
    
    private var filteredLocations: [String] {
        if searchText.isEmpty {
            return popularLocations
        } else {
            return popularLocations.filter { location in
                location.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18))
                        .foregroundColor(Color.hykaPurple)
                    
                    TextField("Search location...", text: $searchText)
                        .focused($searchFieldFocused)
                        .font(.system(size: 16))
                        .foregroundColor(HYKATheme.Light.foreground)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(HYKATheme.Light.mutedForeground)
                        }
                    }
                }
                .padding(16)
                .background(HYKATheme.Light.background)
                .cornerRadius(HYKATheme.cornerRadiusM)
                .overlay(
                    RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                        .stroke(Color.hykaPurple.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)
                
                List {
                    if !searchText.isEmpty {
                        Button(action: {
                            selectedLocation = searchText
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color.hykaPurple)
                                Text("Use custom: \"\(searchText)\"")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(HYKATheme.Light.foreground)
                                Spacer()
                                if selectedLocation == searchText {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(Color.hykaPurple)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                        }
                        .listRowBackground(selectedLocation == searchText ? Color.hykaPurple.opacity(0.15) : Color.white.opacity(0.5))
                        .listRowSeparator(.visible)
                        .listRowSeparatorTint(HYKATheme.Light.border)
                    }
                    
                    ForEach(filteredLocations, id: \.self) { loc in
                        Button(action: {
                            selectedLocation = loc
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color.hykaPurple)
                                Text(loc)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(HYKATheme.Light.foreground)
                                Spacer()
                                if selectedLocation == loc {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(Color.hykaPurple)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                        }
                        .listRowBackground(selectedLocation == loc ? Color.hykaPurple.opacity(0.15) : Color.white.opacity(0.5))
                        .listRowSeparator(.visible)
                        .listRowSeparatorTint(HYKATheme.Light.border)
                    }
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
                .background(HYKATheme.Light.card)
                
                HStack(spacing: HYKATheme.spacingM) {
                    Button(action: {
                        searchFieldFocused = false
                        onCancel()
                    }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(HYKATheme.Light.mutedForeground)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(HYKATheme.Light.background)
                            .cornerRadius(HYKATheme.cornerRadiusM)
                    }
                    
                    Button(action: {
                        if !selectedLocation.isEmpty {
                            location = selectedLocation
                            searchFieldFocused = false
                            onSave()
                        }
                    }) {
                        Text("Save")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedLocation.isEmpty ? Color.gray : Color.hykaPurple)
                            .cornerRadius(HYKATheme.cornerRadiusM)
                    }
                    .disabled(selectedLocation.isEmpty)
                }
                .padding()
                .background(HYKATheme.Light.card)
            }
            .dismissKeyboardOnTap()
            .background(HYKATheme.Light.card)
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack {
                        Text("Select Location")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(HYKATheme.Light.foreground)
                        if !searchText.isEmpty {
                            Text("\(filteredLocations.count) results")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(HYKATheme.Light.mutedForeground)
                        }
                    }
                }
            }
            .onAppear {
                selectedLocation = location
                searchText = location
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    searchFieldFocused = true
                }
            }
        }
        .background(HYKATheme.Light.card)
        .keyboardDoneToolbar()
    }
}

#Preview {
    RacePlanView()
        .environmentObject(SessionManager())
}

private enum RacePlanMetadataStore {
    private static func storageKey(for racePlanId: UUID) -> String {
        "race_plan_metadata_\(racePlanId.uuidString)"
    }
    
    static func save(_ metadata: RacePlanMetadata, for racePlanId: UUID) {
        let key = storageKey(for: racePlanId)
        do {
            let data = try JSONEncoder().encode(metadata)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("⚠️ Failed to persist race metadata: \(error)")
        }
    }
    
    static func load(for racePlanId: UUID) -> RacePlanMetadata? {
        let key = storageKey(for: racePlanId)
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(RacePlanMetadata.self, from: data)
        } catch {
            print("⚠️ Failed to load race metadata: \(error)")
            return nil
        }
    }
}

struct WeatherCoordinates: Codable, Equatable {
    let latitude: Double
    let longitude: Double
}

fileprivate struct CachedRacePlanDetail {
    let metadata: RacePlanMetadata
    let aidStations: [AidStation]
    let pacingSegments: [PacingSegment]
    let fuelingStations: [FuelingStation]
    let trackPoints: [TrackPoint]
    let aidStationMetrics: [Int: AidStationSegmentMetrics]
    let weatherLocation: String
    let weatherCoordinates: WeatherCoordinates?
    let lastUpdated: Date
}


// MARK: - Race Strategy Card PDF View

struct RaceStrategyCardPDFView: View {
    let raceName: String
    let raceDate: String
    let distance: String
    let elevationGain: String
    let estimatedTime: String
    let notes: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title
            Text(raceName)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.black)
                .padding(.bottom, 8)
            
            // Details Grid
            HStack(alignment: .top, spacing: 30) {
                // Left Column
                VStack(alignment: .leading, spacing: 16) {
                    DetailRow(icon: "calendar", label: "Race Date", value: raceDate)
                    DetailRow(icon: "mountain.2.fill", label: "Elevation Gain", value: elevationGain)
                }
                
                // Right Column
                VStack(alignment: .leading, spacing: 16) {
                    DetailRow(icon: "mappin.circle.fill", label: "Distance", value: distance)
                    DetailRow(icon: "clock.fill", label: "Est. Time", value: estimatedTime)
                }
            }
            .padding(.vertical, 8)
            
            // Notes
            if let notes = notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Race Notes")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.gray)
                    Text(notes)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.black)
                }
                .padding(.top, 8)
            }
        }
        .padding(40)
        .frame(width: 595, height: 842) // A4 size in points (72 DPI)
        .background(Color.white)
    }
}

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Color(red: 0.5, green: 0.2, blue: 0.8)) // Purple color
                .frame(width: 16, height: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.gray)
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}


actor RacePlanListCache {
    static let shared = RacePlanListCache()
    private var storage: [UUID: [RacePlanSummary]] = [:]
    func plans(for userId: UUID) -> [RacePlanSummary]? { storage[userId] }
    func save(plans: [RacePlanSummary], for userId: UUID) { storage[userId] = plans }
    func remove(planId: UUID, for userId: UUID) {
        guard var list = storage[userId] else { return }
        list.removeAll { $0.id == planId }
        storage[userId] = list
    }
    func clear(for userId: UUID) { storage[userId] = nil }
}

actor RacePlanDetailCache {
    static let shared = RacePlanDetailCache()
    private var storage: [UUID: CachedRacePlanDetail] = [:]
    fileprivate func detail(for racePlanId: UUID) -> CachedRacePlanDetail? { storage[racePlanId] }
    fileprivate func save(detail: CachedRacePlanDetail, for racePlanId: UUID) { storage[racePlanId] = detail }
    fileprivate func remove(for racePlanId: UUID) { storage[racePlanId] = nil }
}
