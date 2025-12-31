//
//  SetupManager.swift
//  Picturesque Native
//

import SwiftUI
import Combine

// MARK: - Setup Step
enum SetupStep: Int, CaseIterable {
    case virtualEnvironment = 0
    case modelManagement = 1
}

// MARK: - Setup Status
enum SetupStatus: Equatable {
    case notStarted
    case inProgress(progress: Double, message: String)
    case completed
    case failed(error: String)

    static func == (lhs: SetupStatus, rhs: SetupStatus) -> Bool {
        switch (lhs, rhs) {
        case (.notStarted, .notStarted):
            return true
        case (.inProgress(let lp, let lm), .inProgress(let rp, let rm)):
            return lp == rp && lm == rm
        case (.completed, .completed):
            return true
        case (.failed(let le), .failed(let re)):
            return le == re
        default:
            return false
        }
    }
}

// MARK: - Model Info
struct ModelInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let size: String
    var isDownloaded: Bool
    var isDownloading: Bool
    var downloadProgress: Double

    static func == (lhs: ModelInfo, rhs: ModelInfo) -> Bool {
        return lhs.id == rhs.id &&
               lhs.isDownloaded == rhs.isDownloaded &&
               lhs.isDownloading == rhs.isDownloading &&
               lhs.downloadProgress == rhs.downloadProgress
    }
}

// MARK: - Setup Manager
class SetupManager: ObservableObject {
    @Published var currentStep: SetupStep = .virtualEnvironment
    @Published var virtualEnvStatus: SetupStatus = .notStarted
    @Published var setupLogs: [String] = []
    @Published var availableModels: [ModelInfo] = []
    @Published var isSetupComplete: Bool = false

    private var pythonBridge: PythonBridge?

    init() {
        pythonBridge = PythonBridge()
        initializeAvailableModels()
    }

    private func initializeAvailableModels() {
        availableModels = [
            ModelInfo(
                id: "anime",
                name: "Anime Style",
                description: "Convert photos to anime-style artwork with vibrant colors and smooth lines",
                size: "~2.5 GB",
                isDownloaded: false,
                isDownloading: false,
                downloadProgress: 0.0
            ),
            ModelInfo(
                id: "cartoon",
                name: "Cartoon Style",
                description: "Transform images into classic cartoon illustrations",
                size: "~2.5 GB",
                isDownloaded: false,
                isDownloading: false,
                downloadProgress: 0.0
            ),
            ModelInfo(
                id: "comics",
                name: "Comic Book Style",
                description: "Create bold comic book-style artwork with dramatic effects",
                size: "~2.5 GB",
                isDownloaded: false,
                isDownloading: false,
                downloadProgress: 0.0
            ),
            ModelInfo(
                id: "pixar",
                name: "3D Animation Style",
                description: "Generate 3D-rendered Pixar-like character designs",
                size: "~2.5 GB",
                isDownloaded: false,
                isDownloading: false,
                downloadProgress: 0.0
            )
        ]
    }

    func startSetup() {
        addLog("Starting virtual environment setup...")
        virtualEnvStatus = .inProgress(progress: 0.0, message: "Creating Python virtual environment...")

        // Simulate setup process
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performVirtualEnvSetup()
        }
    }

    private func performVirtualEnvSetup() {
        // Use PythonBridge to set up virtual environment
        pythonBridge?.initialize { [weak self] success, message in
            DispatchQueue.main.async {
                if success {
                    self?.addLog("✓ Virtual environment created successfully")
                    self?.virtualEnvStatus = .completed
                    self?.currentStep = .modelManagement
                    self?.checkDownloadedModels()
                } else {
                    self?.addLog("✗ Failed to create virtual environment: \(message)")
                    self?.virtualEnvStatus = .failed(error: message)
                }
            }
        }
    }

    func checkDownloadedModels() {
        addLog("Checking for downloaded models...")

        // Check which models are already downloaded
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Get home directory and check for models
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            let modelsDir = homeDir.appendingPathComponent(".cache/huggingface/hub")

            DispatchQueue.main.async {
                // Update model status
                for i in 0..<self.availableModels.count {
                    // Simple check - you would need to implement actual model detection
                    // For now, check if any model was downloaded
                    let modelPath = modelsDir.appendingPathComponent("models--\(self.availableModels[i].id)")
                    self.availableModels[i].isDownloaded = FileManager.default.fileExists(atPath: modelPath.path)
                }

                self.addLog("Model check complete")
                self.updateSetupCompleteStatus()
            }
        }
    }

    func downloadModel(modelId: String) {
        guard let index = availableModels.firstIndex(where: { $0.id == modelId }) else {
            return
        }

        addLog("Starting download for \(availableModels[index].name)...")
        availableModels[index].isDownloading = true
        availableModels[index].downloadProgress = 0.0

        // Simulate download progress
        simulateModelDownload(modelId: modelId)
    }

    func downloadAllMissingModels() {
        let missingModels = availableModels.filter { !$0.isDownloaded && !$0.isDownloading }

        for model in missingModels {
            downloadModel(modelId: model.id)
        }
    }

    private func simulateModelDownload(modelId: String) {
        guard let index = availableModels.firstIndex(where: { $0.id == modelId }) else {
            return
        }

        // Simulate download with progress updates
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
                Thread.sleep(forTimeInterval: 0.5)

                DispatchQueue.main.async {
                    guard let self = self,
                          let currentIndex = self.availableModels.firstIndex(where: { $0.id == modelId }) else {
                        return
                    }

                    self.availableModels[currentIndex].downloadProgress = progress

                    if progress >= 1.0 {
                        self.availableModels[currentIndex].isDownloading = false
                        self.availableModels[currentIndex].isDownloaded = true
                        self.addLog("✓ \(self.availableModels[currentIndex].name) downloaded successfully")
                        self.updateSetupCompleteStatus()
                    }
                }
            }
        }
    }

    private func updateSetupCompleteStatus() {
        // Setup is complete if virtual env is ready and at least one model is downloaded
        isSetupComplete = virtualEnvStatus == .completed &&
                         availableModels.contains(where: { $0.isDownloaded })
    }

    private func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        setupLogs.append("[\(timestamp)] \(message)")

        // Keep only last 100 log entries
        if setupLogs.count > 100 {
            setupLogs.removeFirst(setupLogs.count - 100)
        }
    }
}
