import SwiftUI
import UniformTypeIdentifiers
import Auth

struct UploadGPXView: View {
    let onNext: () -> Void
    let onSkip: () -> Void
    let onGPXImported: ((String, Data, Double) -> Void)? // fileName, fileData, distanceKm
    let onUploadStatusChange: ((Bool) -> Void)?
    let isContinueDisabled: Bool
    
    init(
        onNext: @escaping () -> Void,
        onSkip: @escaping () -> Void,
        onGPXImported: ((String, Data, Double) -> Void)? = nil,
        onUploadStatusChange: ((Bool) -> Void)? = nil,
        isContinueDisabled: Bool = false
    ) {
        self.onNext = onNext
        self.onSkip = onSkip
        self.onGPXImported = onGPXImported
        self.onUploadStatusChange = onUploadStatusChange
        self.isContinueDisabled = isContinueDisabled
    }
    
    @EnvironmentObject var session: SessionManager
    @State private var fileName: String? = nil
    @State private var fileSize: String? = nil
    @State private var showFilePicker = false
    @State private var isUploading = false
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: HYKATheme.spacingXXL) {
                    VStack(spacing: HYKATheme.spacingS) {
                        Text("Upload your race course")
                            .font(HYKATheme.h2)
                            .foregroundColor(HYKATheme.Light.foreground)
                            .multilineTextAlignment(.center)
                        
                        Text("Import your GPX file for route analysis")
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
                    // Drop zone
                    ZStack {
                        RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusL)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                            .foregroundColor(Color.hykaPurple.opacity(0.3))
                        
                        RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusL)
                            .fill(Color.hykaPurple.opacity(0.02))
                        
                        VStack(spacing: HYKATheme.spacingL) {
                            Image(systemName: "arrow.down.doc")
                                .font(.system(size: 41))
                                .foregroundColor(Color.hykaPurple)
                            
                            Button(action: {
                                showFilePicker = true
                            }) {
                                Text("Browse files")
                                    .font(HYKATheme.button)
                                    .foregroundColor(Color.hykaPurple)
                                    .underline()
                            }
                        }
                        .padding(HYKATheme.spacingXXL)
                    }
                    .frame(height: 200)
                    .padding(.horizontal, HYKATheme.spacingXXL)
                    
                    // File chip (only show if file is selected)
                    if let fileName = fileName, let fileSize = fileSize {
                        HStack(spacing: HYKATheme.spacingM) {
                            Image(systemName: "doc.fill")
                                .foregroundColor(Color.hykaPurple)
                                .font(.system(size: 17))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(fileName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(HYKATheme.Light.foreground)
                                Text(fileSize)
                                    .font(.system(size: 10))
                                    .foregroundColor(HYKATheme.Light.mutedForeground)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                self.fileName = nil
                                self.fileSize = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(HYKATheme.Light.mutedForeground)
                                    .font(.system(size: 17))
                            }
                        }
                        .padding(HYKATheme.spacingL)
                        .background(
                            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                                .fill(Color.hykaPurple.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                                .stroke(Color.hykaPurple, lineWidth: 1)
                        )
                        .padding(.horizontal, HYKATheme.spacingXXL)
                    }
                    
                    // Info alert
                    HYKAUIAlert(
                        title: "What's a GPX file?",
                        description: "A GPX file contains your race course route, elevation, and waypoints. You can export this from apps like Garmin Connect or Coros.",
                        variant: .default,
                        icon: "info.circle"
                    )
                    .padding(.horizontal, HYKATheme.spacingXXL)
                        }
                        .padding(.top, HYKATheme.spacingXXL)
                        
                        Spacer(minLength: HYKATheme.spacingXXL)
                        
                        // Buttons
                        VStack(spacing: HYKATheme.spacingM) {
                            HYKAButton(title: isUploading ? "Uploading…" : "Continue", style: .primary) {
                                guard !isUploading, !isContinueDisabled else { return }
                                onNext()
                            }
                            .disabled(isUploading || isContinueDisabled)
                            .opacity(isUploading || isContinueDisabled ? 0.7 : 1)
                            
                            if isUploading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color.hykaPurple))
                            }
                        }
                        .padding(.horizontal, HYKATheme.spacingXXL)
                        .padding(.bottom, HYKATheme.spacingXXL)
                    }
                }
            }
            .background(HYKATheme.backgroundColor)
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
    
    private func handleGPXFileSelection(url: URL) async {
        // Get the file name
        let selectedFileName = url.lastPathComponent
        fileName = selectedFileName
        
        // Get file size
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attributes[.size] as? Int64 {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB]
            formatter.countStyle = .file
            fileSize = formatter.string(fromByteCount: size)
        } else {
            fileSize = "Unknown size"
        }
        
        print("✅ GPX file selected: \(selectedFileName)")
        
        // Read file data and save to database
        do {
            await MainActor.run {
                isUploading = true
                onUploadStatusChange?(true)
            }
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
            
            // Parse GPX file locally to calculate distance (without saving to database)
            let parser = GPXParser()
            let gpxPoints = parser.parse(data: fileData)
            let trackPoints = SupabaseService.makeTrackPoints(from: gpxPoints)
            let totalDistanceMeters = trackPoints.last?.distFromStart ?? 0
            let totalDistanceKm = totalDistanceMeters / 1000.0
            
            print("✅ GPX file parsed locally. Distance: \(totalDistanceKm) km")
            await MainActor.run {
                // Pass GPX data to parent (will be saved at the end of onboarding)
                onGPXImported?(selectedFileName, fileData, totalDistanceKm)
                isUploading = false
                onUploadStatusChange?(false)
            }
        } catch {
            print("❌ Error saving GPX file: \(error)")
            ErrorManager.shared.showError(error, title: "Failed to Save GPX File")
            await MainActor.run {
                isUploading = false
                onUploadStatusChange?(false)
            }
        }
    }
}

#Preview {
    UploadGPXView(onNext: {}, onSkip: {})
}


