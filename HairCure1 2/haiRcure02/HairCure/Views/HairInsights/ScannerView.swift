import SwiftUI
import AVFoundation
@preconcurrency import Vision
import PhotosUI

// MARK: - Scanner View Model
@Observable
@MainActor
class ScannerViewModel: NSObject {
    var hasCameraPermission = false
    var isScanning = false
    var recognizedText = ""
    var detectedIngredients: [String] = []
    
    var showManualInput = false
    var parsedProduct: Product? = nil
    
    var isAnalyzing = false
    var processedCount = 0
    var totalCount = 0
    
    private let captureSession = AVCaptureSession()
    private var videoDataOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.haircure.scanner.queue")
    private var isSessionConfigured = false
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    override init() {
        super.init()
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        self.previewLayer = layer
    }
    
    var isCameraAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
        #endif
    }
    
    func checkPermissions() async {
        guard isCameraAvailable else {
            hasCameraPermission = false
            return
        }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            hasCameraPermission = true
            await startSession()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            hasCameraPermission = granted
            if granted {
                await startSession()
            }
        default:
            hasCameraPermission = false
        }
    }
    
    func startSession() async {
        guard hasCameraPermission else { return }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.isSessionConfigured {
                self.configureSession()
            }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
                DispatchQueue.main.async {
                    self.isScanning = true
                }
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                DispatchQueue.main.async {
                    self.isScanning = false
                }
            }
        }
    }
    
    private func configureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .hd1920x1080
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("No back camera found")
            captureSession.commitConfiguration()
            return
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }
            
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.haircure.ocr.frames"))
            
            if captureSession.canAddOutput(videoDataOutput) {
                captureSession.addOutput(videoDataOutput)
            }
            
            isSessionConfigured = true
        } catch {
            print("Configure session input error: \(error)")
        }
        
        captureSession.commitConfiguration()
    }
    
    func processParsedText(_ text: String, activeScalp: ScalpCondition) async {
        // Split ingredients by commas, semicolons or periods
        let rawItems = text.components(separatedBy: CharacterSet(charactersIn: ",;.\n"))
        var cleanedItems: [String] = []
        for item in rawItems {
            let cleaned = item.trimmingCharacters(in: .whitespacesAndNewlines)
            // Filter out empty lines, generic labels, water (if we want, but let's keep it), or numeric weights
            if cleaned.count > 2 && !cleaned.contains("INGREDIENTS") && !cleaned.contains("Ingredients:") {
                cleanedItems.append(cleaned)
            }
        }
        
        guard !cleanedItems.isEmpty else { return }
        
        self.isAnalyzing = true
        self.processedCount = 0
        self.totalCount = cleanedItems.count
        
        var analyzed: [FlaggedIngredient] = []
        for item in cleanedItems {
            let result = await PubChemService.shared.analyzeIngredient(item, against: activeScalp)
            analyzed.append(result)
            self.processedCount += 1
        }
        
        let evaluation = RecommendationEngine.evaluateProduct(
            ingredients: cleanedItems,
            analyzedIngredients: analyzed,
            against: activeScalp
        )
        
        self.parsedProduct = Product(
            id: UUID(),
            name: "Scanned Product",
            brand: "Unknown Brand",
            ingredients: cleanedItems,
            compatibility: evaluation.rating,
            category: .shampoo, // Default category
            scannedAt: Date()
        )
        self.isAnalyzing = false
    }

    func analyzeImage(_ uiImage: UIImage, activeScalp: ScalpCondition) async {
        guard let cgImage = uiImage.cgImage else { return }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { [weak self] request, error in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                    continuation.resume()
                    return
                }
                
                var recognizedTextAccumulator = ""
                for observation in observations {
                    if let candidate = observation.topCandidates(1).first {
                        recognizedTextAccumulator += candidate.string + ", "
                    }
                }
                
                DispatchQueue.main.async {
                    self.recognizedText = recognizedTextAccumulator
                    Task {
                        await self.processParsedText(recognizedTextAccumulator, activeScalp: activeScalp)
                        continuation.resume()
                    }
                }
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                try? handler.perform([request])
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension ScannerViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Throttle frame processing to save battery / CPU
        guard Int.random(in: 0...12) == 0 else { return }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self else { return }
            guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else { return }
            
            var recognizedTextAccumulator = ""
            for observation in observations {
                if let candidate = observation.topCandidates(1).first {
                    recognizedTextAccumulator += candidate.string + ", "
                }
            }
            
            DispatchQueue.main.async {
                self.recognizedText = recognizedTextAccumulator
                self.updateDetectedIngredientsList()
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
    
    private func updateDetectedIngredientsList() {
        let text = recognizedText.lowercased()
        let items = text.components(separatedBy: CharacterSet(charactersIn: ",;.\n"))
        var detected: [String] = []
        for item in items {
            let cleaned = item.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.count > 3 && (
                cleaned.hasSuffix("sulfate") ||
                cleaned.hasSuffix("siloxane") ||
                cleaned.hasSuffix("cone") ||
                cleaned.hasSuffix("ol") ||
                cleaned.hasSuffix("paraben") ||
                cleaned.contains("oil") ||
                cleaned.contains("extract") ||
                cleaned.hasSuffix("acid")
            ) {
                detected.append(cleaned.capitalized)
            }
        }
        self.detectedIngredients = Array(Set(detected).prefix(4))
    }
}

// MARK: - Camera Preview SwiftUI Wrapper
struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer
    
    class PreviewUIView: UIView {
        private let previewLayer: AVCaptureVideoPreviewLayer
        
        init(previewLayer: AVCaptureVideoPreviewLayer) {
            self.previewLayer = previewLayer
            super.init(frame: .zero)
            self.layer.addSublayer(previewLayer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.frame = self.bounds
        }
    }
    
    func makeUIView(context: Context) -> PreviewUIView {
        return PreviewUIView(previewLayer: previewLayer)
    }
    
    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        // Resizing is handled automatically by layoutSubviews
    }
}

// MARK: - Scanner View UI
struct ScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppDataStore.self) private var store
    
    @State private var viewModel = ScannerViewModel()
    @State private var showLaser = false
    @State private var showDetailSheet = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    
    var activeScalp: ScalpCondition {
        store.latestScanReport?.scalpCondition ?? .normal
    }
    
    var body: some View {
        ZStack {
            if viewModel.hasCameraPermission && viewModel.isCameraAvailable {
                CameraPreviewView(previewLayer: viewModel.previewLayer!)
                    .ignoresSafeArea()
                
                // Visual scan guide frame
                GeometryReader { geometry in
                    let frameWidth = geometry.size.width * 0.8
                    let frameHeight = geometry.size.height * 0.35
                    let rect = CGRect(
                        x: (geometry.size.width - frameWidth) / 2,
                        y: (geometry.size.height - frameHeight) / 2.3,
                        width: frameWidth,
                        height: frameHeight
                    )
                    
                    ZStack {
                        // Background dimming outside of focus area
                        Color.black.opacity(0.55)
                            .mask(
                                Color.white
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .frame(width: rect.width, height: rect.height)
                                            .position(x: rect.midX, y: rect.midY)
                                            .blendMode(.destinationOut)
                                    )
                            )
                        
                        // Crop border
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                        
                        // Animated Scanning Line (Laser)
                        Rectangle()
                            .fill(LinearGradient(colors: [.clear, .hcBrown, .clear], startPoint: .top, endPoint: .bottom))
                            .frame(width: rect.width - 4, height: 4)
                            .position(x: rect.midX, y: showLaser ? rect.maxY - 4 : rect.minY + 4)
                            .animation(
                                .easeInOut(duration: 2.2).repeatForever(autoreverses: true),
                                value: showLaser
                            )
                        
                        // Real-time Parsing HUD
                        VStack(spacing: 8) {
                            Text("Position ingredients inside the frame")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                            
                            if !viewModel.detectedIngredients.isEmpty {
                                HStack {
                                    Image(systemName: "eyes")
                                    Text("Detected: \(viewModel.detectedIngredients.joined(separator: ", "))")
                                        .lineLimit(1)
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.hcBrown.opacity(0.85))
                                .cornerRadius(20)
                                .shadow(radius: 2)
                            }
                        }
                        .position(x: rect.midX, y: rect.minY - 32)
                    }
                }
                .ignoresSafeArea()
            } else {
                Color.hcCream.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: viewModel.isCameraAvailable ? "camera.badge.ellipsis" : "camera.metering.none")
                        .font(.system(size: 64))
                        .foregroundColor(.hcBrown.opacity(0.6))
                    
                    Text(viewModel.isCameraAvailable ? "Camera Access Needed" : "Camera Not Available")
                        .font(.title2.bold())
                        .foregroundColor(.black)
                    
                    Text(viewModel.isCameraAvailable ? 
                         "To scan ingredient lists, please grant camera permissions in System Settings or choose another method below." :
                         "Your device does not have a back camera (e.g. running on a simulator). Please scan by uploading an image from your gallery or typing manually.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    VStack(spacing: 12) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle.angled")
                                Text("Upload from Gallery")
                            }
                            .hcPrimaryButton()
                        }
                        .padding(.horizontal, 48)
                        
                        if viewModel.isCameraAvailable {
                            Button {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Text("Open Settings")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.hcBrown)
                            }
                        } else {
                            Button {
                                viewModel.showManualInput = true
                            } label: {
                                HStack {
                                    Image(systemName: "keyboard")
                                    Text("Type Manually")
                                }
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.hcBrown)
                            }
                        }
                    }
                }
            }
            
            // Top Controls overlay
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                // Bottom control overlay to scan
                if viewModel.hasCameraPermission && viewModel.isCameraAvailable {
                    Button {
                        guard !viewModel.recognizedText.isEmpty else { return }
                        Task {
                            await viewModel.processParsedText(viewModel.recognizedText, activeScalp: activeScalp)
                            if viewModel.parsedProduct != nil {
                                viewModel.stopSession()
                                showDetailSheet = true
                            }
                        }
                    } label: {
                        Text(viewModel.recognizedText.isEmpty ? "Scanning..." : "Evaluate Ingredients")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(viewModel.recognizedText.isEmpty ? Color.gray : Color.hcBrown)
                            .cornerRadius(30)
                            .shadow(radius: 4)
                    }
                    .disabled(viewModel.recognizedText.isEmpty)
                    .padding(.bottom, 36)
                }
            }
            
            // Loading Overlay when querying PubChem
            if viewModel.isAnalyzing {
                Color.black.opacity(0.65)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .hcBrown))
                        .scaleEffect(1.5)
                        .padding()
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(radius: 5)
                    
                    VStack(spacing: 8) {
                        Text("Querying PubChem Database...")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        
                        if viewModel.totalCount > 0 {
                            Text("Analyzing ingredient \(viewModel.processedCount) of \(viewModel.totalCount)")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await viewModel.analyzeImage(image, activeScalp: activeScalp)
                    if viewModel.parsedProduct != nil {
                        viewModel.stopSession()
                        showDetailSheet = true
                    }
                }
            }
        }
        .task {
            await viewModel.checkPermissions()
            showLaser = true
        }
        .onDisappear {
            viewModel.stopSession()
        }
        .sheet(isPresented: $viewModel.showManualInput) {
            ManualProductEntryView { product in
                viewModel.parsedProduct = product
                showDetailSheet = true
            }
        }
        .sheet(isPresented: $showDetailSheet) {
            if let product = viewModel.parsedProduct {
                ProductDetailView(product: product) {
                    store.addProduct(product)
                    showDetailSheet = false
                    dismiss()
                } onDiscard: {
                    showDetailSheet = false
                    Task { await viewModel.startSession() }
                }
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(28)
            }
        }
    }
}

// MARK: - Manual Product Entry View
struct ManualProductEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppDataStore.self) private var store
    
    @State private var name = ""
    @State private var brand = ""
    @State private var category = ProductCategory.shampoo
    @State private var ingredientsText = ""
    
    @State private var isAnalyzing = false
    @State private var processedCount = 0
    @State private var totalCount = 0
    
    var activeScalp: ScalpCondition {
        store.latestScanReport?.scalpCondition ?? .normal
    }
    
    let onComplete: (Product) -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.hcCream.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Product Details")
                            .font(.title2.bold())
                            .foregroundColor(.black)
                        
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Product Name")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                TextField("e.g. Scalp Relief Shampoo", text: $name)
                                    .hcInputField()
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Brand")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                TextField("e.g. Natural Care", text: $brand)
                                    .hcInputField()
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Category")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                Picker("Category", selection: $category) {
                                    ForEach(ProductCategory.allCases) { cat in
                                        Text(cat.displayName).tag(cat)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .padding(.vertical, 4)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Ingredients list")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                TextEditor(text: $ingredientsText)
                                    .frame(height: 120)
                                    .padding(12)
                                    .background(Color.white)
                                    .cornerRadius(14)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                                    )
                                    .overlay(
                                        Group {
                                            if ingredientsText.isEmpty {
                                                Text("Paste ingredients list separated by commas...")
                                                    .font(.system(size: 16, weight: .regular))
                                                    .foregroundColor(.gray.opacity(0.8))
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 16)
                                                    .allowsHitTesting(false)
                                            }
                                        },
                                        alignment: .topLeading
                                    )
                            }
                        }
                        
                        Button {
                            guard !name.isEmpty, !ingredientsText.isEmpty else { return }
                            
                            let rawItems = ingredientsText.components(separatedBy: CharacterSet(charactersIn: ",;.\n"))
                            let cleaned = rawItems.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                            
                            isAnalyzing = true
                            processedCount = 0
                            totalCount = cleaned.count
                            
                            Task {
                                var analyzed: [FlaggedIngredient] = []
                                for item in cleaned {
                                    let result = await PubChemService.shared.analyzeIngredient(item, against: activeScalp)
                                    analyzed.append(result)
                                    processedCount += 1
                                }
                                
                                let evaluation = RecommendationEngine.evaluateProduct(
                                    ingredients: cleaned,
                                    analyzedIngredients: analyzed,
                                    against: activeScalp
                                )
                                
                                let newProduct = Product(
                                    id: UUID(),
                                    name: name,
                                    brand: brand.isEmpty ? "Unknown Brand" : brand,
                                    ingredients: cleaned,
                                    compatibility: evaluation.rating,
                                    category: category,
                                    scannedAt: Date()
                                )
                                
                                isAnalyzing = false
                                onComplete(newProduct)
                                dismiss()
                            }
                        } label: {
                            if isAnalyzing {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    Text("Analyzing (\(processedCount)/\(totalCount))...")
                                }
                                .hcPrimaryButton()
                            } else {
                                Text("Analyze Product")
                                    .hcPrimaryButton()
                            }
                        }
                        .disabled(name.isEmpty || ingredientsText.isEmpty || isAnalyzing)
                        .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
