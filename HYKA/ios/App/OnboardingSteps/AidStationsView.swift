import SwiftUI

struct AidStationsView: View {
    @Binding var aidStations: [AidStation]
    var raceDistance: Double? = nil
    let onNext: () -> Void
    let onBack: () -> Void
    
    @EnvironmentObject var session: SessionManager
    @State private var showAddStation = false
    @State private var stationName = ""
    @State private var stationDistance = ""
    @State private var selectedServices: Set<AidService.ServiceType> = []
    @State private var showContinueConfirmation = false
    @State private var showSignOutAlert = false
    @State private var isSigningOut = false
    @State private var showDistanceError = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name
        case distance
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom header with purple dot and Skip button
            HStack {
                HStack(spacing: HYKATheme.spacingM) {
                    Circle()
                        .fill(Color.hykaPurple)
                        .frame(width: 8, height: 8)
                    
                    Text("Aid Stations")
                        .font(HYKATheme.label)
                        .foregroundColor(HYKATheme.Light.foreground)
                }
                
                Spacer()
                
                Button(action: {
                    onNext()
                }) {
                    Text("Skip")
                        .font(HYKATheme.body)
                        .foregroundColor(HYKATheme.Light.mutedForeground)
                }
            }
            .padding(.horizontal, HYKATheme.spacingXXL)
            .padding(.vertical, HYKATheme.spacingL)
            .background(Color.white)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(HYKATheme.Light.border),
                alignment: .bottom
            )
            
            ScrollView {
                VStack(spacing: HYKATheme.spacingXXL) {
                    VStack(spacing: HYKATheme.spacingS) {
                        Text("Plan your support stops")
                            .font(HYKATheme.h2)
                            .foregroundColor(HYKATheme.Light.foreground)
                            .multilineTextAlignment(.center)
                        
                        Text("Add each aid station and the services you expect so we can tailor fueling.")
                            .font(HYKATheme.body)
                            .foregroundColor(HYKATheme.Light.mutedForeground)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, HYKATheme.spacingXXL)
                    .padding(.top, HYKATheme.spacingXXL)
                    .padding(.bottom, HYKATheme.spacingL)
                    
                    VStack(spacing: HYKATheme.spacingXXL) {
                        aidStationsList
                        
                        // Add Aid Station Section
                        if showAddStation {
                            VStack(alignment: .leading, spacing: HYKATheme.spacingL) {
                                Text("Add aid station")
                                    .font(HYKATheme.h4)
                                    .foregroundColor(HYKATheme.Light.foreground)
                                
                                VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                                    Text("Station Name")
                                        .font(HYKATheme.label)
                                        .foregroundColor(HYKATheme.Light.foreground)
                                    
                                    TextField("e.g., Mountain Peak Aid", text: $stationName)
                                        .focused($focusedField, equals: .name)
                                        .font(HYKATheme.input)
                                        .foregroundColor(.black) // Typed text in black
                                        .padding(HYKATheme.spacingM)
                                        .background(HYKATheme.Light.inputBackground)
                                        .cornerRadius(HYKATheme.cornerRadiusM)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                                                .stroke(HYKATheme.Light.border, lineWidth: 1)
                                        )
                                }
                                
                                VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                                    Text("Distance from Start (KM)")
                                        .font(HYKATheme.label)
                                        .foregroundColor(HYKATheme.Light.foreground)
                                    
                                    TextField("e.g., 30", text: $stationDistance)
                                        .focused($focusedField, equals: .distance)
                                        .font(HYKATheme.input)
                                        .foregroundColor(.black) // Typed text in black
                                        .keyboardType(.decimalPad)
                                        .padding(HYKATheme.spacingM)
                                        .background(HYKATheme.Light.inputBackground)
                                        .cornerRadius(HYKATheme.cornerRadiusM)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                                                .stroke(HYKATheme.Light.border, lineWidth: 1)
                                        )
                                }
                                
                                VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
                                    Text("Services Available")
                                        .font(HYKATheme.label)
                                        .foregroundColor(HYKATheme.Light.foreground)
                                    
                                    LazyVGrid(columns: [
                                        GridItem(.flexible()),
                                        GridItem(.flexible())
                                    ], spacing: HYKATheme.spacingM) {
                                        ForEach(AidService.ServiceType.allCases, id: \.self) { service in
                                            Button(action: {
                                                if selectedServices.contains(service) {
                                                    selectedServices.remove(service)
                                                } else {
                                                    selectedServices.insert(service)
                                                }
                                            }) {
                                                let isSelected = selectedServices.contains(service)
                                                VStack(spacing: HYKATheme.spacingS) {
                                                    Image(systemName: service.icon)
                                                        .font(.system(size: 26, weight: .semibold))
                                                        .foregroundColor(isSelected ? Color.hykaPurple : HYKATheme.Light.mutedForeground)
                                                    
                                                    Text(service.rawValue)
                                                        .font(HYKATheme.caption)
                                                        .foregroundColor(isSelected ? HYKATheme.Light.foreground : HYKATheme.Light.mutedForeground)
                                                }
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 90)
                                                .background(
                                                    RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                                                        .fill(isSelected ? Color.hykaPurple.opacity(0.12) : HYKATheme.Light.inputBackground)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                                                        .stroke(isSelected ? Color.hykaPurple : HYKATheme.Light.border, lineWidth: 1)
                                                )
                                                .shadow(color: isSelected ? Color.hykaPurple.opacity(0.12) : Color.clear, radius: 10, x: 0, y: 6)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                }
                                
                                Button(action: {
                                    addStation()
                                }) {
                                    HStack {
                                        Image(systemName: "plus")
                                        Text("Save aid station")
                                    }
                                    .font(HYKATheme.button)
                                    .foregroundColor(Color.hykaPurple)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(Color.clear)
                                    .cornerRadius(HYKATheme.cornerRadiusM)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                                            .stroke(Color.hykaPurple, lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.horizontal, HYKATheme.spacingXXL)
                        } else {
                            Button(action: {
                                withAnimation {
                                    showAddStation = true
                                }
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add Aid Station")
                                }
                                .font(HYKATheme.button)
                                .foregroundColor(Color.hykaPurple)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.hykaPurple.opacity(0.05))
                                .cornerRadius(HYKATheme.cornerRadiusM)
                            }
                            .padding(.horizontal, HYKATheme.spacingXXL)
                        }
                    }
                    
                    // Continue Button
                    VStack(spacing: HYKATheme.spacingM) {
                        HYKAButton(title: "Continue", style: .primary) {
                            if aidStations.count >= 2 {
                                onNext()
                            } else {
                                showContinueConfirmation = true
                            }
                        }
                        .disabled(aidStations.isEmpty)
                        
                        HYKAButton(title: "Back", style: .outline, action: onBack)
                    }
                    .padding(.horizontal, HYKATheme.spacingXXL)
                    .padding(.bottom, HYKATheme.spacingXXL)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                focusedField = nil
            }
            .background(HYKATheme.backgroundColor)
            .keyboardDoneToolbar()
        }
        .alert("Invalid Distance", isPresented: $showDistanceError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Aid station distance must be less than the total race distance.")
        }
        .alert("Ready to continue?", isPresented: $showContinueConfirmation) {
            Button("Go back and add more", role: .cancel) { }
            Button("Yes, continue") {
                onNext()
            }
        } message: {
            Text("Have you added all the aid stations from your race? Aid stations help us create a more accurate nutrition and pacing strategy for your race day.")
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
    
    private var aidStationsList: some View {
        VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
            Text("Your Aid Stations")
                .font(HYKATheme.h4)
                .foregroundColor(HYKATheme.Light.foreground)
            
            VStack(spacing: HYKATheme.spacingM) {
                ForEach(aidStations) { station in
                    HStack {
                        AidStationCardView(station: station)
                        
                        // Delete button
                        Button(action: {
                            if let index = aidStations.firstIndex(where: { $0.id == station.id }) {
                                aidStations.remove(at: index)
                            }
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                                .padding(8)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, HYKATheme.spacingXXL)
    }
    
    private func handleSignOut() async {
        isSigningOut = true
        await session.signOut()
        isSigningOut = false
    }
    
    private func addStation() {
        guard !stationName.isEmpty, let distance = Double(stationDistance) else { return }
        
        // Validation: Check if distance is greater than race distance
        if let maxDistance = raceDistance, distance > maxDistance {
            showDistanceError = true
            return
        }
        
        let services = AidService.ServiceType.allCases.map { serviceType in
            AidService(type: serviceType, isAvailable: selectedServices.contains(serviceType))
        }
        
        let newStation = AidStation(
            name: stationName,
            distance: distance,
            services: services
        )
        
        aidStations.append(newStation)
        
        // Sort by distance
        aidStations.sort { $0.distance < $1.distance }
        
        // Reset form
        stationName = ""
        stationDistance = ""
        selectedServices = []
        showAddStation = false
    }
}

private struct FlexibleBadgeRow<Content: View>: View {
    let spacing: CGFloat
    let lineSpacing: CGFloat
    let content: () -> Content
    
    var body: some View {
        VStack(spacing: lineSpacing) {
            content()
        }
    }
}

private struct AidStationCardView: View {
    let station: AidStation
    
    var body: some View {
        HStack(alignment: .top, spacing: HYKATheme.spacingM) {
            ZStack {
                Circle()
                    .fill(Color.hykaPurple.opacity(0.12))
                    .frame(width: 16, height: 16)
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(Color.hykaPurple)
            }
            
            VStack(alignment: .leading, spacing: HYKATheme.spacingXS) {
                HStack {
                    Text(station.name)
                        .font(HYKATheme.body)
                        .foregroundColor(HYKATheme.Light.foreground)
                    Spacer()
                    Text("\(Int(station.distance))K")
                        .font(HYKATheme.caption)
                        .foregroundColor(HYKATheme.Light.mutedForeground)
                }
                
                let activeServices = station.services.filter { $0.isAvailable }
                if !activeServices.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: HYKATheme.spacingS)], alignment: .leading, spacing: HYKATheme.spacingS) {
                        ForEach(activeServices, id: \.type.rawValue) { service in
                            ServiceBadgeView(type: service.type)
                        }
                    }
                }
            }
        }
        .padding(HYKATheme.spacingL)
        .background(
            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                .fill(HYKATheme.Light.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                .stroke(HYKATheme.Light.border, lineWidth: 1)
        )
    }
}

private struct ServiceBadgeView: View {
    let type: AidService.ServiceType
    
    var body: some View {
        let color = colorForType(type)
        return HStack(spacing: 6) {
            Image(systemName: type.icon)
                .font(.system(size: 12, weight: .semibold))
            Text(type.rawValue)
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundColor(color)
        .background(
            Capsule()
                .fill(color.opacity(0.18))
        )
        .overlay(
            Capsule()
                .stroke(color.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.15), radius: 4, x: 0, y: 2)
    }
    
    private func colorForType(_ type: AidService.ServiceType) -> Color {
        switch type {
        case .hydration: return Color.blue
        case .gels: return Color.hykaPurple
        case .food: return Color.green
        case .crew: return Color.orange
        }
    }
}

#Preview {
    AidStationsView(
        aidStations: .constant(AidStation.mock),
        onNext: {},
        onBack: {}
    )
}
