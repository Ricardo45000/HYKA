import SwiftUI

struct EditAidStationsModal: View {
    @Binding var aidStations: [AidStation]
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var editingStations: [EditableAidStation] = []
    @State private var stationName = ""
    @State private var stationDistance = ""
    @State private var selectedServices: Set<AidService.ServiceType> = []
    @State private var editingStation: EditableAidStation?
    @State private var strategyNotes = ""
    
    // Mutable version of AidStation for editing
    struct EditableAidStation: Identifiable {
        let id = UUID()
        var name: String
        var distance: Double
        var services: [AidService]
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: HYKATheme.spacingXXL) {
                    // Header
                    VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                        Text("Edit Aid Stations")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(HYKATheme.Light.foreground)
                        
                        Text("Customize your race strategy by adding or removing aid stations")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(HYKATheme.Light.mutedForeground)
                    }
                    .padding(.horizontal, HYKATheme.spacingXXL)
                    .padding(.top, HYKATheme.spacingXXL)
                    
                    // Aid Stations Section
                    VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
                        Text("Aid Stations")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(HYKATheme.Light.foreground)
                            .padding(.horizontal, HYKATheme.spacingXXL)
                        
                        VStack(spacing: HYKATheme.spacingS) {
                            ForEach(editingStations.sorted(by: { $0.distance < $1.distance })) { station in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(station.name)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(HYKATheme.Light.foreground)
                                        
                                        Text("\(String(format: "%.0f", station.distance))K")
                                            .font(.system(size: 13, weight: .regular))
                                            .foregroundColor(HYKATheme.Light.mutedForeground)
                                    }
                                    
                                    Spacer()
                                    
                                    Button {
                                        editingStation = station
                                        stationName = station.name
                                        stationDistance = String(format: "%.0f", station.distance)
                                        selectedServices = Set(station.services.filter { $0.isAvailable }.map { $0.type })
                                    } label: {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 16))
                                            .foregroundColor(Color.hykaPurple)
                                            .padding(.trailing, HYKATheme.spacingM)
                                    }
                                    
                                    Button {
                                        editingStations.removeAll { $0.id == station.id }
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 16))
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(HYKATheme.spacingM)
                                .background(HYKATheme.Light.card)
                                .cornerRadius(HYKATheme.cornerRadiusM)
                            }
                        }
                        .padding(.horizontal, HYKATheme.spacingXXL)
                    }
                    
                    // Add New Aid Station Section
                    VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
                        Text("Add New Aid Station")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(HYKATheme.Light.foreground)
                            .padding(.horizontal, HYKATheme.spacingXXL)
                        
                        VStack(spacing: HYKATheme.spacingL) {
                            // Station Name
                            VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                                HYKAUILabel(text: "Station Name", isRequired: false)
                                HYKAUIInput(
                                    placeholder: "e.g., Mountain Peak",
                                    text: $stationName,
                                    keyboardType: .default,
                                    textContentType: .none
                                )
                            }
                            
                            // Distance
                            VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                                HYKAUILabel(text: "Distance (KM)", isRequired: false)
                                HYKAUIInput(
                                    placeholder: "e.g., 30",
                                    text: $stationDistance,
                                    keyboardType: .decimalPad,
                                    textContentType: .none
                                )
                            }
                        }
                        .padding(.horizontal, HYKATheme.spacingXXL)
                    }
                    
                    // Services Available Section
                    VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
                        Text("Services Available")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(HYKATheme.Light.foreground)
                            .padding(.horizontal, HYKATheme.spacingXXL)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: HYKATheme.spacingM) {
                            ForEach(AidService.ServiceType.allCases, id: \.self) { serviceType in
                                Button {
                                    if selectedServices.contains(serviceType) {
                                        selectedServices.remove(serviceType)
                                    } else {
                                        selectedServices.insert(serviceType)
                                    }
                                } label: {
                                    VStack(spacing: HYKATheme.spacingS) {
                                        Image(systemName: serviceType.icon)
                                            .font(.system(size: 20))
                                            .foregroundColor(selectedServices.contains(serviceType) ? Color.hykaPurple : HYKATheme.Light.mutedForeground)
                                        
                                        Text(serviceType.rawValue)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(selectedServices.contains(serviceType) ? Color.hykaPurple : HYKATheme.Light.foreground)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 100)
                                    .background(.white)
                                    .cornerRadius(HYKATheme.cornerRadiusM)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                                            .stroke(selectedServices.contains(serviceType) ? Color.hykaPurple : HYKATheme.Light.border, lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, HYKATheme.spacingXXL)
                    }
                    
                    // Add Aid Station Button
                    Button {
                        if let distance = Double(stationDistance) {
                            let services = AidService.ServiceType.allCases.map { type in
                                AidService(type: type, isAvailable: selectedServices.contains(type))
                            }
                            let newStation = EditableAidStation(
                                name: stationName.isEmpty ? "Station" : stationName,
                                distance: distance,
                                services: services
                            )
                            
                            if let editing = editingStation {
                                // Update existing station
                                if let index = editingStations.firstIndex(where: { $0.id == editing.id }) {
                                    editingStations[index] = newStation
                                }
                            } else {
                                // Add new station
                                editingStations.append(newStation)
                            }
                            
                            // Reset form
                            stationName = ""
                            stationDistance = ""
                            selectedServices = []
                            editingStation = nil
                        }
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                                .font(.system(size: 16))
                            Text(editingStation != nil ? "Update Aid Station" : "Add Aid Station")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.hykaPurple)
                        .cornerRadius(HYKATheme.cornerRadiusM)
                    }
                    .disabled(stationDistance.isEmpty || Double(stationDistance) == nil)
                    .opacity((stationDistance.isEmpty || Double(stationDistance) == nil) ? 0.5 : 1.0)
                    .padding(.horizontal, HYKATheme.spacingXXL)
                    
                    // Strategy Notes Section
                    VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
                        Text("Strategy Notes")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(HYKATheme.Light.foreground)
                            .padding(.horizontal, HYKATheme.spacingXXL)
                        
                        VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                            Text("Additional Notes")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(HYKATheme.Light.foreground)
                                .padding(.horizontal, HYKATheme.spacingXXL)
                            
                            ZStack(alignment: .topLeading) {
                                if strategyNotes.isEmpty {
                                    Text("Add any additional notes or reminders for your race strategy...")
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundColor(HYKATheme.Light.mutedForeground)
                                        .padding(.horizontal, HYKATheme.spacingM + 4)
                                        .padding(.vertical, HYKATheme.spacingM + 8)
                                        .allowsHitTesting(false)
                                }
                                
                                TextEditor(text: $strategyNotes)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.black)
                                    .scrollContentBackground(.hidden)
                                    .frame(height: 100)
                                    .padding(HYKATheme.spacingM)
                                    .background(Color.clear)
                                    .cornerRadius(HYKATheme.cornerRadiusM)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                                            .stroke(HYKATheme.Light.border, lineWidth: 1)
                                    )
                            }
                            .padding(.horizontal, HYKATheme.spacingXXL)
                        }
                    }
                    
                    // Save Changes Button
                    Button {
                        // Convert EditableAidStation back to AidStation
                        aidStations = editingStations.map { editable in
                            AidStation(name: editable.name, distance: editable.distance, services: editable.services)
                        }
                        onSave()
                    } label: {
                        Text("Save Changes")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.hykaPurple)
                            .cornerRadius(HYKATheme.cornerRadiusM)
                    }
                    .padding(.horizontal, HYKATheme.spacingXXL)
                    .padding(.bottom, HYKATheme.spacingXXL)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .background(HYKATheme.Light.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16))
                            .foregroundColor(HYKATheme.Light.foreground)
                    }
                }
            }
        }
        .onAppear {
            // Convert AidStation to EditableAidStation
            editingStations = aidStations.map { station in
                EditableAidStation(name: station.name, distance: station.distance, services: station.services)
            }
        }
    }
}

#Preview {
    EditAidStationsModal(
        aidStations: .constant([
            AidStation(name: "Start", distance: 0, services: []),
            AidStation(name: "Finish", distance: 100, services: [])
        ]),
        onSave: {}
    )
}

