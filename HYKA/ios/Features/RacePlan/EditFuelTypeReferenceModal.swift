import SwiftUI
import Auth

struct EditFuelTypeReferenceModal: View {
    @Binding var fuelTypes: [RacePlanView.FuelType]
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var session: SessionManager
    
    @State private var editingFuelTypes: [EditableFuelType] = []
    @State private var isSaving = false
    @State private var fuelName = ""
    @State private var selectedCategory: String = "Energy Gel"
    @State private var carbsPerServing = ""
    @State private var sodiumPerServing = ""
    @State private var editingFuel: EditableFuelType?
    @State private var showCategoryPicker = false
    
    // Mutable version of FuelType for editing
    struct EditableFuelType: Identifiable {
        var id: UUID
        var name: String
        var category: String
        var carbs: Int
        var sodium: Int
        var isCustom: Bool
    }
    
    let fuelCategories = [
        "Carb Drink Mix",
        "Energy Gel",
        "Energy Bar",
        "Chew Pack",
        "Fruit",
        "Salty Snack",
        "Dates",
        "Rice Cake",
        "Stroopwafel",
        "Trail Mix",
        "Sandwich",
        "Other"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                contentView
            }
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
            .sheet(isPresented: $showCategoryPicker) {
                CategoryPickerModal(
                    selectedCategory: $selectedCategory,
                    categories: fuelCategories,
                    isPresented: $showCategoryPicker
                )
            }
            .onAppear {
                setupFuelTypes()
            }
        }
    }
    
    private var contentView: some View {
        VStack(spacing: HYKATheme.spacingXXL) {
            headerSection
            fuelTypesListSection
            editFuelTypeSection
            saveChangesButton
            tipSection
            doneButton
        }
    }
    
    // MARK: - View Sections
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
            Text("Edit Fuel Type Reference")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(HYKATheme.Light.foreground)
            
            Text("Customize your fuel types and carb amounts to match your nutrition plan")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(HYKATheme.Light.mutedForeground)
        }
        .padding(.horizontal, HYKATheme.spacingXXL)
        .padding(.top, HYKATheme.spacingXXL)
    }
    
    private var fuelTypesListSection: some View {
        VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
            Text("Your Fuel Types")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(HYKATheme.Light.foreground)
                .padding(.horizontal, HYKATheme.spacingXXL)
            
            VStack(spacing: HYKATheme.spacingS) {
                ForEach(editingFuelTypes) { fuel in
                    fuelTypeRow(fuel: fuel)
                }
            }
            .padding(.horizontal, HYKATheme.spacingXXL)
        }
    }
    
    private func fuelTypeRow(fuel: EditableFuelType) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(fuel.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(HYKATheme.Light.foreground)
                
                HStack(spacing: 4) {
                    Text("\(fuel.carbs)g carbs")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(HYKATheme.Light.foreground)
                    
                    Text("\(fuel.sodium)mg")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.orange)
                    
                    Text("Na")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(HYKATheme.Light.foreground)
                }
            }
            
            Spacer()
            
            Button {
                editingFuel = fuel
                fuelName = fuel.name
                selectedCategory = fuel.category
                carbsPerServing = String(fuel.carbs)
                sodiumPerServing = String(fuel.sodium)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 16))
                    .foregroundColor(Color.hykaPurple)
                    .padding(.trailing, HYKATheme.spacingM)
            }
            
            Button {
                editingFuelTypes.removeAll { $0.id == fuel.id }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
            }
        }
        .padding(HYKATheme.spacingM)
        .background(Color.hykaPurple.opacity(0.1))
        .cornerRadius(HYKATheme.cornerRadiusM)
        .overlay(
            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                .stroke(Color.hykaPurple.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var editFuelTypeSection: some View {
        VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
            Text("Edit Fuel Type")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(HYKATheme.Light.foreground)
                .padding(.horizontal, HYKATheme.spacingXXL)
            
            VStack(spacing: HYKATheme.spacingL) {
                fuelNameField
                categoryField
                carbsField
                sodiumField
            }
            .padding(.horizontal, HYKATheme.spacingXXL)
        }
    }
    
    private var fuelNameField: some View {
        VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
            HYKAUILabel(text: "Fuel Name", isRequired: false)
            HYKAUIInput(
                placeholder: "e.g., Maurten Gel",
                text: $fuelName,
                keyboardType: .default,
                textContentType: .none
            )
        }
    }
    
    private var categoryField: some View {
        VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
            HYKAUILabel(text: "Fuel Type Category", isRequired: false)
            
            Button {
                showCategoryPicker.toggle()
            } label: {
                HStack {
                    Text(selectedCategory)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(HYKATheme.Light.foreground)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(HYKATheme.Light.mutedForeground)
                }
                .padding(HYKATheme.spacingM)
                .background(HYKATheme.Light.inputBackground)
                .cornerRadius(HYKATheme.cornerRadiusM)
                .overlay(
                    RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                        .stroke(HYKATheme.Light.border, lineWidth: 1)
                )
            }
        }
    }
    
    private var carbsField: some View {
        VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
            HYKAUILabel(text: "Carbs per Serving (g)", isRequired: false)
            HYKAUIInput(
                placeholder: "e.g., 25",
                text: $carbsPerServing,
                keyboardType: .numberPad,
                textContentType: .none
            )
        }
    }
    
    private var sodiumField: some View {
        VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
            HYKAUILabel(text: "Sodium per Serving (mg)", isRequired: false)
            HYKAUIInput(
                placeholder: "e.g., 40",
                text: $sodiumPerServing,
                keyboardType: .numberPad,
                textContentType: .none
            )
        }
    }
    
    private var saveChangesButton: some View {
        Button {
            saveFuelTypeChanges()
        } label: {
            HStack {
                Image(systemName: "pencil")
                    .font(.system(size: 16))
                Text("Save Changes")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.hykaPurple)
            .cornerRadius(HYKATheme.cornerRadiusM)
        }
        .disabled(!isFormValid)
        .opacity(isFormValid ? 1.0 : 0.5)
        .padding(.horizontal, HYKATheme.spacingXXL)
    }
    
    private var tipSection: some View {
        HStack(alignment: .top, spacing: HYKATheme.spacingS) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 16))
                .foregroundColor(.yellow)
            
            Text("Tip: Add your specific fuel products with custom names (e.g., \"Maurten Gel 100\"). The app uses the category to balance your nutrition and the carb values to calculate your fueling strategy for each race section.")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(HYKATheme.Light.mutedForeground)
        }
        .padding(HYKATheme.spacingM)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(HYKATheme.cornerRadiusM)
        .padding(.horizontal, HYKATheme.spacingXXL)
    }
    
    private var doneButton: some View {
        Button {
            Task {
                await saveFuelTypes()
            }
        } label: {
            if isSaving {
                ProgressView()
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.hykaPurple)
                    .cornerRadius(HYKATheme.cornerRadiusM)
            } else {
                Text("Done")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.hykaPurple)
                    .cornerRadius(HYKATheme.cornerRadiusM)
            }
        }
        .disabled(isSaving)
        .padding(.horizontal, HYKATheme.spacingXXL)
        .padding(.bottom, HYKATheme.spacingXXL)
    }
    
    // MARK: - Helper Properties
    
    private var isFormValid: Bool {
        !fuelName.isEmpty &&
        !carbsPerServing.isEmpty &&
        !sodiumPerServing.isEmpty &&
        Int(carbsPerServing) != nil &&
        Int(sodiumPerServing) != nil
    }
    
    // MARK: - Helper Methods
    
    private func saveFuelTypeChanges() {
        guard let carbs = Int(carbsPerServing),
              let sodium = Int(sodiumPerServing),
              !fuelName.isEmpty else {
            return
        }
        
        if let editing = editingFuel {
            // Update existing
            if let index = editingFuelTypes.firstIndex(where: { $0.id == editing.id }) {
                let updated = EditableFuelType(
                    id: editing.id,
                    name: fuelName,
                    category: selectedCategory,
                    carbs: carbs,
                    sodium: sodium,
                    isCustom: editing.isCustom
                )
                editingFuelTypes[index] = updated
            }
        } else {
            // Add new - mark as custom
            let customFuel = EditableFuelType(
                id: UUID(),
                name: fuelName,
                category: selectedCategory,
                carbs: carbs,
                sodium: sodium,
                isCustom: true
            )
            editingFuelTypes.append(customFuel)
        }
        
        fuelName = ""
        selectedCategory = "Energy Gel"
        carbsPerServing = ""
        sodiumPerServing = ""
        editingFuel = nil
    }
    
    private func setupFuelTypes() {
        // Convert FuelType to EditableFuelType
        editingFuelTypes = fuelTypes.map { fuel in
            EditableFuelType(
                id: fuel.id,
                name: fuel.name,
                category: fuel.category,
                carbs: fuel.carbs,
                sodium: fuel.sodium,
                isCustom: fuel.isCustom
            )
        }
    }
    
    // MARK: - Save to Supabase
    
    @MainActor
    private func saveFuelTypes() async {
        isSaving = true
        
        // Get user ID
        var userId: UUID?
        if let user = session.currentUser {
            userId = user.id
        } else if session.isAuthenticated {
            if let userIdString = UserDefaults.standard.string(forKey: "hyka.user.id"),
               let id = UUID(uuidString: userIdString) {
                userId = id
            }
        }
        
        guard let userId = userId else {
            print("⚠️ No user ID available for saving fuel types")
            isSaving = false
            return
        }
        
        do {
            let originalById = Dictionary(uniqueKeysWithValues: fuelTypes.map { ($0.id, $0) })
            let originalFuelTypeIds = Set(originalById.keys)
            let newFuelTypeIds = Set(editingFuelTypes.map { $0.id })
            
            let deletedIds = originalFuelTypeIds.subtracting(newFuelTypeIds)
            for deletedId in deletedIds {
                try await SupabaseService.deleteFuelType(fuelTypeId: deletedId)
            }
            
            for index in editingFuelTypes.indices {
                if !originalFuelTypeIds.contains(editingFuelTypes[index].id) {
                    let fuel = editingFuelTypes[index]
                    let newId = try await SupabaseService.addFuelType(
                        userId: userId,
                        name: fuel.name,
                        category: fuel.category,
                        carbs: fuel.carbs,
                        sodium: fuel.sodium,
                        isCustom: fuel.isCustom
                    )
                    editingFuelTypes[index].id = newId
                }
            }
            
            for editedFuel in editingFuelTypes {
                if let oldFuel = originalById[editedFuel.id] {
                    if oldFuel.name != editedFuel.name ||
                        oldFuel.category != editedFuel.category ||
                        oldFuel.carbs != editedFuel.carbs ||
                        oldFuel.sodium != editedFuel.sodium {
                        try await SupabaseService.updateFuelType(
                            fuelTypeId: editedFuel.id,
                            name: editedFuel.name,
                            category: editedFuel.category,
                            carbs: editedFuel.carbs,
                            sodium: editedFuel.sodium
                        )
                    }
                }
            }
            
            fuelTypes = editingFuelTypes.map { editable in
                RacePlanView.FuelType(
                    id: editable.id,
                    name: editable.name,
                    category: editable.category,
                    carbs: editable.carbs,
                    sodium: editable.sodium,
                    isCustom: editable.isCustom
                )
            }
            
            onSave()
        } catch {
            print("❌ Error saving fuel types: \(error)")
            ErrorManager.shared.showError(error, title: "Failed to Save Fuel Types")
        }
        
        isSaving = false
    }
}

struct CategoryPickerModal: View {
    @Binding var selectedCategory: String
    let categories: [String]
    @Binding var isPresented: Bool
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(categories, id: \.self) { category in
                    Button {
                        selectedCategory = category
                        isPresented = false
                    } label: {
                        HStack {
                            Text(category)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(HYKATheme.Light.foreground)
                            
                            Spacer()
                            
                            if selectedCategory == category {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.hykaPurple)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(Color.hykaPurple)
                }
            }
        }
    }
}

#Preview {
    EditFuelTypeReferenceModal(
        fuelTypes: .constant([
            RacePlanView.FuelType(id: UUID(), name: "Tailwind Endurance", category: "Carb Drink Mix", carbs: 50, sodium: 200, isCustom: false),
            RacePlanView.FuelType(id: UUID(), name: "Maurten Gel", category: "Energy Gel", carbs: 25, sodium: 40, isCustom: false)
        ]),
        onSave: {}
    )
    .environmentObject(SessionManager())
}

