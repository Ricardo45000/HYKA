import SwiftUI
import Auth

struct RacePlanMetadata: Codable {
    var raceDate: Date?
    var startTime: Date?
    var elevationGain: Int?
    var distance: Double?
    var notes: String?
}

struct RaceCreationFlowView: View {
    enum Step: Int {
        case upload = 6
        case details = 7
        case aidStations = 8
        case preferences = 9
    }
    
    @EnvironmentObject private var session: SessionManager
    @Environment(\.dismiss) private var dismiss
    
    let onComplete: (UUID, RacePlanMetadata) -> Void
    
    @State private var currentStep: Step = .upload
    @State private var racePlanId: UUID?
    @State private var raceDetails: RaceDetails = .mock
    @State private var aidStations: [AidStation] = AidStation.mock
    @State private var preferences = StrategyPreferences()
    @State private var isSaving = false
    @State private var errorMessage: String = ""
    @State private var showErrorAlert = false
    @State private var showValidationAlert = false
    @State private var isUploadingGPX = false
    private let defaultPaceSecondsPerKm = 300
    
    var body: some View {
        NavigationView {
            ZStack {
                TabView(selection: Binding(
                    get: { currentStep.rawValue },
                    set: { value in
                        if let step = Step(rawValue: value) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                currentStep = step
                            }
                        }
                    }
                )) {
                    UploadGPXView(
                        onNext: handleUploadContinue,
                        onSkip: handleUploadContinue,
                        onGPXImported: { id, distance in
                            racePlanId = id
                            updateFinishDistance(distance)
                            isUploadingGPX = false
                        },
                        onUploadStatusChange: { isUploadingGPX = $0 },
                        isContinueDisabled: isUploadingGPX
                    )
                    .tag(Step.upload.rawValue)
                    
                    RaceDetailsView(
                        raceDetails: $raceDetails,
                        onNext: { advance(to: .aidStations) },
                        onBack: { advance(to: .upload) }
                    )
                    .tag(Step.details.rawValue)
                    
                    AidStationsView(
                        aidStations: $aidStations,
                        onNext: { advance(to: .preferences) },
                        onBack: { advance(to: .details) }
                    )
                    .tag(Step.aidStations.rawValue)
                    
                    StrategyPreferencesView(
                        preferences: $preferences,
                        onGenerate: finishCreation,
                        onBack: { advance(to: .aidStations) }
                    )
                    .tag(Step.preferences.rawValue)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
                
                if isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Saving your race…")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding()
                        .background(Color.hykaPurple)
                        .cornerRadius(HYKATheme.cornerRadiusM)
                        .foregroundColor(.white)
                }
            }
            .navigationBarHidden(true)
            .alert("Missing GPX File", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Upload a GPX file before continuing.")
            }
            .alert("Race Setup Failed", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func advance(to step: Step) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            currentStep = step
        }
    }
    
    private func handleUploadContinue() {
        guard !isUploadingGPX else { return }
        guard racePlanId != nil else {
            showValidationAlert = true
            return
        }
        advance(to: .details)
    }
    
    private func finishCreation() {
        guard let racePlanId else {
            showValidationAlert = true
            return
        }
        Task {
            do {
                guard let userId = await resolveUserId() else {
                    throw NSError(domain: "RaceCreationFlow", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }
                await MainActor.run { isSaving = true }
                try await SupabaseService.updateRacePlanTitle(racePlanId: racePlanId, title: raceDetails.name)
                let orderedStations = aidStations.sorted { $0.distance < $1.distance }
                guard orderedStations.count >= 2 else {
                    throw NSError(domain: "RaceCreationFlow", code: -2, userInfo: [NSLocalizedDescriptionKey: "Add at least a start and finish station"])
                }
                let trackPoints = try await SupabaseService.fetchRacePlanTrackPoints(racePlanId: racePlanId)
                let metrics = buildSegmentMetrics(for: orderedStations, using: trackPoints)
                try await SupabaseService.updateAidStations(
                    racePlanId: racePlanId,
                    aidStations: orderedStations,
                    segmentMetrics: metrics,
                    paceSecondsPerKm: Double(defaultPaceSecondsPerKm)
                )
                try await SupabaseService.ensureDefaultFuelTypes(userId: userId)
                let metadata = RacePlanMetadata(
                    raceDate: raceDetails.date,
                    startTime: raceDetails.startTime,
                    elevationGain: raceDetails.elevation,
                    distance: orderedStations.last?.distance,
                    notes: nil
                )
                await MainActor.run {
                    isSaving = false
                    onComplete(racePlanId, metadata)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
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
}
