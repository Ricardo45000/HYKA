import SwiftUI
import UniformTypeIdentifiers
import Auth

struct RaceLiveActivityView: View {
    @EnvironmentObject var session: SessionManager
    @State private var uploadedGPXFileName: String?
    @State private var showFilePicker = false
    @State private var racePlanId: UUID?

    var body: some View {
        ZStack {
            HYKATheme.Light.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack {
                    Spacer()
                    // GPX Upload Section - Vertically centered
                    gpxUploadSection
                    Spacer()
                }
                .frame(minHeight: UIScreen.main.bounds.height - 100)
            }
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(edges: .horizontal)
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "gpx") ?? .xml, .xml, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        await handleGPXFileSelection(url: url)
                    }
                }
            case .failure(let error):
                print("⚠️ Error selecting file: \(error)")
                ErrorManager.shared.showError(error, title: "File Selection Failed")
            }
        }
    }
    
    // MARK: - GPX Upload Section
    
    private var gpxUploadSection: some View {
        VStack(spacing: 0) {
            // Title and Subtitle - Centered
            VStack(alignment: .center, spacing: HYKATheme.spacingM) {
                Text("Upload your race course")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(HYKATheme.Light.foreground)
                    .multilineTextAlignment(.center)
                
                Text("Upload a GPX file of your upcoming race to get personalized pacing and nutrition strategies")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(HYKATheme.Light.mutedForeground)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, HYKATheme.spacingXXL)
            .padding(.bottom, HYKATheme.spacingL)
            
            // File Upload Area - extends edge-to-edge
            Group {
                if let fileName = uploadedGPXFileName {
                    // Show uploaded file with option to replace
                    HStack {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color.hykaPurple)
                        
                        Text(fileName)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(HYKATheme.Light.foreground)
                        
                        Spacer()
                        
                        Button {
                            uploadedGPXFileName = nil
                            showFilePicker = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(HYKATheme.Light.mutedForeground)
                        }
                    }
                    .padding(HYKATheme.spacingL)
                    .padding(.horizontal, HYKATheme.spacingXXL)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(HYKATheme.Light.card)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(HYKATheme.Light.border),
                        alignment: .bottom
                    )
                } else {
                    // Upload area (before file is selected) - extends edge-to-edge with dashed border
                    ZStack {
                        // Background
                        HYKATheme.Light.card
                        
                        // Dashed border overlay
                        Rectangle()
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                            .foregroundColor(HYKATheme.Light.border)
                        
                        // Content
                        Button {
                            showFilePicker = true
                        } label: {
                            VStack(spacing: HYKATheme.spacingM) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(HYKATheme.Light.mutedForeground)
                                
                                Text("Drop your GPX file here")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(HYKATheme.Light.foreground)
                                
                                Text("or click to browse")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(HYKATheme.Light.mutedForeground)
                                
                                HStack {
                                    Image(systemName: "doc.badge.plus")
                                        .font(.system(size: 14))
                                    Text("Choose File")
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .foregroundColor(HYKATheme.Light.foreground)
                                .padding(.horizontal, HYKATheme.spacingL)
                                .padding(.vertical, HYKATheme.spacingS)
                                .background(HYKATheme.Light.background)
                                .cornerRadius(HYKATheme.cornerRadiusM)
                                .overlay(
                                    RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                                        .stroke(HYKATheme.Light.border, lineWidth: 1)
                                )
                            }
                            .frame(maxWidth: .infinity)
                            .padding(HYKATheme.spacingXXL)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 180) // Reduced by 10% (from 200)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, HYKATheme.spacingL)
            
            // Info Box
            VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                Text("What's a GPX file?")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(HYKATheme.Light.foreground)
                
                Text("It's a GPS data file that contains your race route. You can download it from your race organizer's website or create one using apps like Garmin Connect or Coros.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(HYKATheme.Light.foreground)
            }
            .padding(HYKATheme.spacingL)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.hykaPurple.opacity(0.1))
            .cornerRadius(HYKATheme.cornerRadiusM)
            .padding(.horizontal, HYKATheme.spacingXXL)
        }
    }
    
    // MARK: - GPX File Handling
    
    private func handleGPXFileSelection(url: URL) async {
        // Get the file name
        let fileName = url.lastPathComponent
        uploadedGPXFileName = fileName
        
        print("✅ GPX file selected: \(fileName)")
        
        // Read file data and save to database
        do {
            let securityEnabled = url.startAccessingSecurityScopedResource()
            defer {
                if securityEnabled {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            let coordinator = NSFileCoordinator()
            var readError: NSError?
            var fileData: Data?
            
            coordinator.coordinate(readingItemAt: url, options: [], error: &readError) { securedURL in
                fileData = try? Data(contentsOf: securedURL)
            }
            
            if let readError = readError {
                throw readError
            }
            
            guard let fileData else {
                throw NSError(domain: "GPXReadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to read GPX file"])
            }
            
            // Get user ID
            guard let userId = session.currentUser?.id ?? (session.isAuthenticated ? UUID(uuidString: UserDefaults.standard.string(forKey: "hyka.user.id") ?? "") : nil) else {
                print("⚠️ No user ID available for saving GPX file")
                ErrorManager.shared.showError(title: "Save Failed", message: "Please sign in to save GPX files")
                return
            }
            
            // Save GPX file to database (update existing race plan if available, otherwise create new)
            let savedRacePlanId = try await SupabaseService.saveGPXFile(
                userId: userId,
                racePlanId: racePlanId, // Use existing race plan if available
                fileName: fileName,
                fileData: fileData
            )
            
            racePlanId = savedRacePlanId
            print("✅ GPX file saved to database with race plan ID: \(savedRacePlanId)")
        } catch {
            print("❌ Error saving GPX file: \(error)")
            ErrorManager.shared.showError(error, title: "Failed to Save GPX File")
        }
    }
}
