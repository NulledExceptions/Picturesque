//
//  PicturesqueViewModel.swift
//  Picturesque Native
//

import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers

class PicturesqueViewModel: ObservableObject {
    @Published var inputImage: NSImage?
    @Published var outputImage: NSImage?
    @Published var selectedStyle: String = "Anime"
    @Published var promptExtra: String = ""
    @Published var strength: Double = 0.80
    @Published var guidanceScale: Double = 7.5
    @Published var steps: Double = 30
    @Published var seed: Int = -1
    @Published var maxResolution: Double = 768
    @Published var outputScale: Double = 1.0
    @Published var exportFormat: String = "PNG"
    @Published var jpegQuality: Double = 90
    @Published var isProcessing: Bool = false
    @Published var generationProgress: Double = 0.0
    @Published var currentStage: String = ""
    @Published var statusMessages: [String] = ["Idle. Upload an image to start."]
    
    private var pythonBridge: PythonBridge?
    private var inputImagePath: URL?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        pythonBridge = PythonBridge()
    }
    
    func initialize() {
        addStatus("Initializing Picturesque...")
        
        // Initialize Python environment in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.pythonBridge?.initialize { success, message in
                DispatchQueue.main.async {
                    if success {
                        self?.addStatus("✓ Ready! Python environment initialized.")
                    } else {
                        self?.addStatus("✗ Failed to initialize: \(message)")
                    }
                }
            }
        }
    }
    
    func selectImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url {
            loadImage(from: url)
        }
    }
    
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        if provider.hasItemConformingToTypeIdentifier("public.file-url") {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { [weak self] (urlData, error) in
                DispatchQueue.main.async {
                    if let urlData = urlData as? Data,
                       let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                        self?.loadImage(from: url)
                    }
                }
            }
            return true
        }
        
        return false
    }
    
    func loadImage(from url: URL) {
        if let image = NSImage(contentsOf: url) {
            inputImage = image
            inputImagePath = url
            addStatus("Loaded: \(url.lastPathComponent)")
            outputImage = nil // Clear previous output
        }
    }
    
    func generate() {
        guard let inputPath = inputImagePath else {
            addStatus("✗ No input image selected")
            return
        }

        isProcessing = true
        generationProgress = 0.0
        currentStage = "Preparing..."
        addStatus("Starting generation with \(selectedStyle) style...")

        // Simulate progress updates
        updateProgress(0.1, stage: "Loading model...")

        let params = GenerationParameters(
            inputPath: inputPath.path,
            style: selectedStyle.lowercased(),
            promptExtra: promptExtra,
            strength: strength,
            guidanceScale: guidanceScale,
            steps: Int(steps),
            seed: seed,
            maxResolution: Int(maxResolution),
            outputScale: outputScale,
            exportFormat: exportFormat.lowercased(),
            jpegQuality: Int(jpegQuality)
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.updateProgress(0.3, stage: "Generating image...")
        }

        pythonBridge?.generate(params: params) { [weak self] result in
            DispatchQueue.main.async {
                self?.isProcessing = false
                self?.generationProgress = 1.0
                self?.currentStage = ""

                switch result {
                case .success(let outputPath):
                    if let outputURL = URL(string: "file://" + outputPath),
                       let image = NSImage(contentsOf: outputURL) {
                        self?.outputImage = image
                        self?.addStatus("✓ Generation complete!")
                        self?.addStatus("Saved to: \(outputPath)")
                    } else {
                        self?.addStatus("✗ Failed to load output image")
                    }

                case .failure(let error):
                    print("[ViewModel] Generation error: \(error)")
                    let errorDesc = error.localizedDescription
                    if let nsError = error as NSError? {
                        let detailedMsg = "Error: \(errorDesc) (Domain: \(nsError.domain), Code: \(nsError.code))"
                        self?.addStatus("✗ Generation failed: \(detailedMsg)")
                        print("[ViewModel] Detailed error: \(detailedMsg)")
                        print("[ViewModel] Error userInfo: \(nsError.userInfo)")
                    } else {
                        self?.addStatus("✗ Generation failed: \(errorDesc)")
                    }
                }
            }
        }
    }

    private func updateProgress(_ progress: Double, stage: String) {
        DispatchQueue.main.async { [weak self] in
            self?.generationProgress = progress
            self?.currentStage = stage
            self?.addStatus(stage)
        }
    }
    
    func saveOutput() {
        guard let outputImage = outputImage else { return }

        // Generate unique filename based on input filename and timestamp
        let defaultFilename: String
        if let inputPath = inputImagePath {
            let inputFilename = inputPath.deletingPathExtension().lastPathComponent
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
            let timestamp = dateFormatter.string(from: Date())
            defaultFilename = "\(inputFilename)-\(timestamp).\(exportFormat.lowercased())"
        } else {
            defaultFilename = "picturesque.\(exportFormat.lowercased())"
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = exportFormat == "PNG" ? [.png] : [.jpeg]
        panel.nameFieldStringValue = defaultFilename

        if panel.runModal() == .OK, let url = panel.url {
            if saveImage(outputImage, to: url) {
                addStatus("✓ Saved to: \(url.path)")
            } else {
                addStatus("✗ Failed to save image")
            }
        }
    }
    
    func copyToClipboard() {
        guard let outputImage = outputImage else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([outputImage])
        addStatus("✓ Copied to clipboard")
    }
    
    private func saveImage(_ image: NSImage, to url: URL) -> Bool {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return false
        }
        
        let imageData: Data?
        if exportFormat == "PNG" {
            imageData = bitmapImage.representation(using: .png, properties: [:])
        } else {
            imageData = bitmapImage.representation(using: .jpeg, properties: [
                .compressionFactor: jpegQuality / 100.0
            ])
        }
        
        guard let data = imageData else { return false }
        
        do {
            try data.write(to: url)
            return true
        } catch {
            return false
        }
    }
    
    private func addStatus(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        statusMessages.append("[\(timestamp)] \(message)")
        
        // Keep only last 50 messages
        if statusMessages.count > 50 {
            statusMessages.removeFirst(statusMessages.count - 50)
        }
    }
}

struct GenerationParameters {
    let inputPath: String
    let style: String
    let promptExtra: String
    let strength: Double
    let guidanceScale: Double
    let steps: Int
    let seed: Int
    let maxResolution: Int
    let outputScale: Double
    let exportFormat: String
    let jpegQuality: Int
}
